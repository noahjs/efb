#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
API_DIR="${REPO_ROOT}/api"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/gcp.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Copy ${SCRIPT_DIR}/gcp.env.example to ${SCRIPT_DIR}/gcp.env and fill values."
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

required=(
  PROJECT_ID
  REGION
  AR_REPO
  IMAGE_NAME
  IMAGE_TAG
  API_SERVICE_NAME
  WORKER_SERVICE_NAME
  CLOUDSQL_INSTANCE
  RUN_SERVICE_ACCOUNT
  SECRET_DB_USER
  SECRET_DB_PASS
  SECRET_DB_NAME
  SECRET_JWT_SECRET
)

for v in "${required[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "Missing required variable: ${v}"
    exit 1
  fi
done

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is not installed. Install Google Cloud SDK first."
  exit 1
fi

gcloud config set project "${PROJECT_ID}" >/dev/null

IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building image: ${IMAGE_URI}"
gcloud builds submit "${API_DIR}" --tag "${IMAGE_URI}"

build_secret_flags() {
  local secret_flags=""
  secret_flags+=",DB_USER=${SECRET_DB_USER}:latest"
  secret_flags+=",DB_PASS=${SECRET_DB_PASS}:latest"
  secret_flags+=",DB_NAME=${SECRET_DB_NAME}:latest"
  secret_flags+=",JWT_SECRET=${SECRET_JWT_SECRET}:latest"
  [[ -n "${SECRET_GOOGLE_CLIENT_ID:-}" ]] && secret_flags+=",GOOGLE_CLIENT_ID=${SECRET_GOOGLE_CLIENT_ID}:latest"
  [[ -n "${SECRET_APPLE_BUNDLE_ID:-}" ]] && secret_flags+=",APPLE_BUNDLE_ID=${SECRET_APPLE_BUNDLE_ID}:latest"
  [[ -n "${SECRET_LEIDOS_VENDOR_USER:-}" ]] && secret_flags+=",LEIDOS_VENDOR_USER=${SECRET_LEIDOS_VENDOR_USER}:latest"
  [[ -n "${SECRET_LEIDOS_VENDOR_PASS:-}" ]] && secret_flags+=",LEIDOS_VENDOR_PASS=${SECRET_LEIDOS_VENDOR_PASS}:latest"
  [[ -n "${SECRET_XWEATHER_CLIENT_ID:-}" ]] && secret_flags+=",XWEATHER_CLIENT_ID=${SECRET_XWEATHER_CLIENT_ID}:latest"
  [[ -n "${SECRET_XWEATHER_CLIENT_SECRET:-}" ]] && secret_flags+=",XWEATHER_CLIENT_SECRET=${SECRET_XWEATHER_CLIENT_SECRET}:latest"
  [[ -n "${SECRET_OPENAI_API_KEY:-}" ]] && secret_flags+=",OPENAI_API_KEY=${SECRET_OPENAI_API_KEY}:latest"
  echo "${secret_flags#,}"
}

SECRETS="$(build_secret_flags)"

COMMON_ENV="NODE_ENV=production,DB_HOST=/cloudsql/${CLOUDSQL_INSTANCE},DB_PORT=5432,CORS_ORIGINS=${CORS_ORIGINS:-},FILING_USE_MOCK=${FILING_USE_MOCK:-false},LEIDOS_BASE_URL=${LEIDOS_BASE_URL:-https://lmfsweb.afss.com/Website/rest},GCS_BUCKET=${GCS_BUCKET:-mobile-efb-prod},GCS_ATIS_BUCKET=${GCS_ATIS_BUCKET:-efb-atis-prod}"

echo "Deploying API service: ${API_SERVICE_NAME}"
gcloud run deploy "${API_SERVICE_NAME}" \
  --image "${IMAGE_URI}" \
  --region "${REGION}" \
  --platform managed \
  --service-account "${RUN_SERVICE_ACCOUNT}" \
  --allow-unauthenticated \
  --ingress all \
  --port 3001 \
  --min-instances "${API_MIN_INSTANCES:-0}" \
  --max-instances "${API_MAX_INSTANCES:-10}" \
  --set-env-vars "${COMMON_ENV},SERVICE_ROLE=api" \
  --set-secrets "${SECRETS}" \
  --add-cloudsql-instances "${CLOUDSQL_INSTANCE}"

WORKER_ENV="${COMMON_ENV},SERVICE_ROLE=worker"
WORKER_SECRETS="${SECRETS}"

if [[ -n "${SECRET_FIREBASE_SERVICE_ACCOUNT_JSON:-}" ]]; then
  WORKER_SECRETS+=",FIREBASE_SERVICE_ACCOUNT_JSON=${SECRET_FIREBASE_SERVICE_ACCOUNT_JSON}:latest"
  WORKER_ENV+=",FIREBASE_SERVICE_ACCOUNT_KEY_PATH=/secrets/firebase-service-account.json"
fi

echo "Deploying worker service: ${WORKER_SERVICE_NAME}"
gcloud run deploy "${WORKER_SERVICE_NAME}" \
  --image "${IMAGE_URI}" \
  --region "${REGION}" \
  --platform managed \
  --service-account "${RUN_SERVICE_ACCOUNT}" \
  --no-allow-unauthenticated \
  --ingress internal \
  --port 3001 \
  --min-instances "${WORKER_MIN_INSTANCES:-1}" \
  --max-instances "${WORKER_MAX_INSTANCES:-1}" \
  --no-cpu-throttling \
  --set-env-vars "${WORKER_ENV}" \
  --set-secrets "${WORKER_SECRETS}" \
  --add-cloudsql-instances "${CLOUDSQL_INSTANCE}"

if [[ -n "${SECRET_FIREBASE_SERVICE_ACCOUNT_JSON:-}" ]]; then
  echo "Mounting Firebase JSON secret file on worker..."
  gcloud run services update "${WORKER_SERVICE_NAME}" \
    --region "${REGION}" \
    --update-secrets "/secrets/firebase-service-account.json=${SECRET_FIREBASE_SERVICE_ACCOUNT_JSON}:latest"
fi

cat <<EOF

Deployment complete.
API service:    ${API_SERVICE_NAME}
Worker service: ${WORKER_SERVICE_NAME}
Image:          ${IMAGE_URI}

Post-deploy checks:
1) Hit /api/health on API service.
2) Check worker logs for "poller_worker_started".
3) Verify data sources update in admin view (once admin auth is locked down).
EOF
