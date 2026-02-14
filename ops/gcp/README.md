# GCP Backend Deployment (Cloud Run + Cloud SQL)

This deploys the API as two Cloud Run services from the same image:

- `efb-api` (public HTTP API, `SERVICE_ROLE=api`)
- `efb-worker` (internal worker, `SERVICE_ROLE=worker`)

In development/non-production, scheduler + pollers still run in-process by design.

## Plan Summary (What This Branch Sets Up)

1. Provision core GCP platform services:
   - Cloud Run, Cloud Build, Artifact Registry, Secret Manager, Cloud SQL, Logging/Monitoring/Trace, IAM.
2. Create runtime infrastructure:
   - Artifact Registry repo for container images.
   - Dedicated Cloud Run service account with least-privilege roles.
3. Store all sensitive config in Secret Manager:
   - DB credentials, JWT secret, OAuth IDs, Leidos credentials, Xweather credentials, optional OpenAI/Firebase secrets.
4. Deploy one app image to two Cloud Run services:
   - `efb-api`: public HTTP API (`SERVICE_ROLE=api`), autoscaling.
   - `efb-worker`: internal singleton worker (`SERVICE_ROLE=worker`), CPU always allocated.
5. Connect both services to Cloud SQL Postgres via the Cloud SQL connector.
6. Keep development behavior unchanged:
   - non-production still runs API + scheduler/pollers together in-process.
7. Use structured JSON logs for Cloud Logging and add operational alerts next.

Execution order:
1. Install `gcloud`.
2. Copy/fill env file: `cp ops/gcp/gcp.env.example ops/gcp/gcp.env`.
3. Run bootstrap: `bash ops/gcp/bootstrap-project.sh`.
4. Add secret versions in Secret Manager.
5. Deploy services: `bash ops/gcp/deploy-cloud-run.sh`.

## 1. Install Google Cloud SDK

On macOS:

```bash
brew install --cask google-cloud-sdk
gcloud init
```

## 2. Prepare deployment env file

```bash
cp ops/gcp/gcp.env.example ops/gcp/gcp.env
```

Fill `ops/gcp/gcp.env` with your project, region, Cloud SQL instance, and secret names.

## 3. Bootstrap project resources

```bash
bash ops/gcp/bootstrap-project.sh
```

This script:

- enables required APIs
- creates Artifact Registry repo
- creates Cloud Run runtime service account (if missing)
- grants IAM roles for Cloud Run runtime
- creates secret shells in Secret Manager (no values yet)

## 4. Add secret versions

For each secret created, add values:

```bash
printf '%s' 'efb' | gcloud secrets versions add EFB_DB_USER --data-file=-
printf '%s' 'super-secret-password' | gcloud secrets versions add EFB_DB_PASS --data-file=-
printf '%s' 'efb' | gcloud secrets versions add EFB_DB_NAME --data-file=-
printf '%s' 'your-jwt-secret' | gcloud secrets versions add EFB_JWT_SECRET --data-file=-
```

Repeat for Google/Apple/Leidos/Xweather/etc as needed.

## 5. Deploy both Cloud Run services

```bash
bash ops/gcp/deploy-cloud-run.sh
```

This script:

- builds container image via Cloud Build
- deploys API service (`SERVICE_ROLE=api`)
- deploys worker service (`SERVICE_ROLE=worker`, singleton, no CPU throttling)
- wires Cloud SQL connector and Secret Manager env injection

## 6. Verify deployment

1. Open API URL and check `/api/health`.
2. Check worker logs for `poller_worker_started`.
3. Confirm poller rows (`s_data_sources`) advance in DB.

## Recommended next hardening

1. Put `/api/admin` behind admin auth and network restrictions.
2. Add `/api/ready` endpoint that fails when DB is unreachable.
3. Add Cloud Monitoring alerts:
   - API 5xx rate
   - p95 latency
   - worker poller consecutive failures
   - health/readiness failures

## GitHub Actions Deploy (OIDC, no key file)

Workflow file: `.github/workflows/deploy-gcp.yml`

This branch is set up to deploy from `main` (and manual dispatch) using
Workload Identity Federation.

Add GitHub repository secrets:

- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`

Add GitHub repository variables:

- `GCP_PROJECT_ID` (example: `mobile-efb`)
- `GCP_REGION` (example: `us-central1`)
- `GCP_CLOUDSQL_INSTANCE` (example: `mobile-efb:us-central1:efb-pg`)
- `CORS_ORIGINS`
- `GCS_BUCKET`
- `GCS_ATIS_BUCKET`

The workflow writes `ops/gcp/gcp.env` during CI and runs:

```bash
bash ops/gcp/deploy-cloud-run.sh
```
