#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  RUN_SERVICE_ACCOUNT
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

echo "Using project: ${PROJECT_ID}, region: ${REGION}"
gcloud config set project "${PROJECT_ID}" >/dev/null

echo "Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  sqladmin.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  cloudtrace.googleapis.com \
  iam.googleapis.com

echo "Creating Artifact Registry repo (if missing)..."
if ! gcloud artifacts repositories describe "${AR_REPO}" --location "${REGION}" >/dev/null 2>&1; then
  gcloud artifacts repositories create "${AR_REPO}" \
    --repository-format=docker \
    --location="${REGION}" \
    --description="EFB API images"
fi

SA_NAME="${RUN_SERVICE_ACCOUNT%@*}"
if ! gcloud iam service-accounts describe "${RUN_SERVICE_ACCOUNT}" >/dev/null 2>&1; then
  echo "Creating Cloud Run service account: ${RUN_SERVICE_ACCOUNT}"
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="EFB Cloud Run Runtime"
fi

echo "Granting IAM roles to Cloud Run service account..."
for role in \
  roles/artifactregistry.reader \
  roles/secretmanager.secretAccessor \
  roles/cloudsql.client \
  roles/logging.logWriter \
  roles/monitoring.metricWriter \
  roles/cloudtrace.agent
do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${RUN_SERVICE_ACCOUNT}" \
    --role="${role}" \
    --quiet >/dev/null
done

echo "Ensuring required secrets exist..."
secrets=(
  "${SECRET_DB_USER:-}"
  "${SECRET_DB_PASS:-}"
  "${SECRET_DB_NAME:-}"
  "${SECRET_JWT_SECRET:-}"
  "${SECRET_GOOGLE_CLIENT_ID:-}"
  "${SECRET_APPLE_BUNDLE_ID:-}"
  "${SECRET_LEIDOS_VENDOR_USER:-}"
  "${SECRET_LEIDOS_VENDOR_PASS:-}"
  "${SECRET_XWEATHER_CLIENT_ID:-}"
  "${SECRET_XWEATHER_CLIENT_SECRET:-}"
  "${SECRET_OPENAI_API_KEY:-}"
  "${SECRET_FIREBASE_SERVICE_ACCOUNT_JSON:-}"
)

for secret in "${secrets[@]}"; do
  [[ -z "${secret}" ]] && continue
  if ! gcloud secrets describe "${secret}" >/dev/null 2>&1; then
    gcloud secrets create "${secret}" --replication-policy="automatic"
    echo "Created secret shell: ${secret}"
  fi
done

cat <<EOF

Bootstrap complete.
Next:
1) Add secret values (versions), for example:
   printf '%s' 'your-db-user' | gcloud secrets versions add ${SECRET_DB_USER} --data-file=-
2) Verify Cloud SQL instance exists and set CLOUDSQL_INSTANCE in gcp.env.
3) Run deploy script:
   bash ops/gcp/deploy-cloud-run.sh
EOF
