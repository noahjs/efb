# GCP Deployment

This deploys the NestJS backend as two Cloud Run services from a single Docker image:

| Service | Role | Access | Scaling | Memory | CPU |
|---------|------|--------|---------|--------|-----|
| `efb-api` | `SERVICE_ROLE=api` | Public | 0–10 instances | 1 GiB | Throttled when idle |
| `efb-worker` | `SERVICE_ROLE=worker` | Internal only | 1–1 (singleton) | 2 GiB | Always allocated |

In development, scheduler + pollers run in-process (no separate worker needed).

## Architecture Overview

```
                  ┌─────────────────────────────────────┐
                  │          GitHub Actions CI           │
                  │  (OIDC → Workload Identity Fed.)     │
                  └────────────┬────────────────────────┘
                               │ push to main
                               ▼
                  ┌─────────────────────────────────────┐
                  │         Cloud Build                  │
                  │  api/Dockerfile (multi-stage)        │
                  │  → Artifact Registry                 │
                  └────────────┬────────────────────────┘
                               │ same image
                ┌──────────────┴──────────────┐
                ▼                             ▼
   ┌────────────────────┐       ┌────────────────────────┐
   │  efb-api (public)  │       │  efb-worker (internal)  │
   │  SERVICE_ROLE=api  │       │  SERVICE_ROLE=worker    │
   │                    │       │                          │
   │  HTTP API only     │       │  pg-boss job queue       │
   │  Pollers disabled  │       │  15 background pollers   │
   │  Autoscales 0–10   │       │  Admin job runner        │
   └────────┬───────────┘       │  Always-on singleton     │
            │                   └────────────┬─────────────┘
            │                                │
            └───────────┬────────────────────┘
                        ▼
          ┌──────────────────────────┐
          │  Cloud SQL (PostgreSQL)  │
          │  Unix socket connector   │
          │  + Secret Manager creds  │
          └──────────────────────────┘
```

### How SERVICE_ROLE works

The runtime role logic lives in `api/src/config/runtime-role.ts`:

- **Development** (`NODE_ENV != production`): pollers always run in-process regardless of `SERVICE_ROLE`
- **Production + `SERVICE_ROLE=api`**: only serves HTTP requests, pg-boss is disabled
- **Production + `SERVICE_ROLE=worker`**: starts pg-boss, runs all background pollers and admin job queue

### Background pollers (worker only)

The scheduler checks every 60 seconds for pollers that are due, then enqueues pg-boss jobs:

| Poller | Source | Interval |
|--------|--------|----------|
| METAR | AWC (by state) | 5 min |
| Advisory (AIRMETs/SIGMETs/CWAs) | AWC | 5 min |
| PIREP | AWC | 5 min |
| Weather Alert | NWS | 5 min |
| Storm Cell | Xweather | 3 min |
| Lightning Threat | Xweather | 3 min |
| Notification Dispatch | Internal | 2 min |
| TFR | FAA WFS + metadata | 15 min |
| NOTAM | FAA (top airports) | 30 min |
| Wind Grid | Open-Meteo (1,620 CONUS pts) | 1 hour |
| Winds Aloft | AWC text | 1 hour |
| HRRR Pipeline | NOAA S3 (GRIB2) | 1 hour |
| TAF | AWC CONUS | 2 hours |
| Fuel Price | AirNav | 7 days |
| FBO | AirNav | 30 days |

### Docker image

Multi-stage build (`api/Dockerfile`):

1. **Build stage**: compiles TypeScript → `dist/`
2. **Production stage**: `node:22-bookworm-slim` + system deps (`python3`, `libeccodes0`, `unzip`) + HRRR Python venv (`xarray`, `cfgrib`)

Build context is the repo root (not `api/`) so `hrrr-processor/` is available. The image serves both the API and worker roles.

---

## Initial Setup

### Prerequisites

```bash
brew install --cask google-cloud-sdk
gcloud init
```

### 1. Configure deployment variables

```bash
cp ops/gcp/gcp.env.example ops/gcp/gcp.env
# Edit gcp.env with your project ID, region, Cloud SQL instance, etc.
```

`gcp.env` is gitignored. In CI, the GitHub Actions workflow writes it dynamically from repository variables.

### 2. Bootstrap GCP infrastructure

```bash
bash ops/gcp/bootstrap-project.sh
```

This is idempotent and safe to re-run. It:

- Enables required APIs (Cloud Run, Cloud Build, Artifact Registry, Secret Manager, Cloud SQL, Logging, Monitoring, Trace, IAM)
- Creates an Artifact Registry Docker repo
- Creates a Cloud Run service account (`efb-runner@PROJECT.iam`) with least-privilege roles
- Grants Cloud Build push permissions to Artifact Registry
- Creates empty Secret Manager secrets (values added next)

### 3. Add secret values

```bash
printf '%s' 'efb' | gcloud secrets versions add EFB_DB_USER --data-file=-
printf '%s' 'super-secret-password' | gcloud secrets versions add EFB_DB_PASS --data-file=-
printf '%s' 'efb' | gcloud secrets versions add EFB_DB_NAME --data-file=-
printf '%s' 'your-jwt-secret' | gcloud secrets versions add EFB_JWT_SECRET --data-file=-
# Repeat for Xweather, OpenAI, ScrapingBee, etc. as needed
```

### 4. Create Cloud SQL instance

Create a PostgreSQL instance manually via console or gcloud CLI. Note the connection name (format: `PROJECT:REGION:INSTANCE`) and set it as `CLOUDSQL_INSTANCE` in `gcp.env`.

### 5. Deploy

```bash
bash ops/gcp/deploy-cloud-run.sh
```

---

## CI/CD (GitHub Actions)

**Workflow file:** `.github/workflows/deploy-gcp.yml`

Deploys on push to `main` when relevant paths change (`api/`, `hrrr-processor/`, `ops/gcp/`, `.dockerignore`). Also supports manual `workflow_dispatch`.

Authentication uses **Workload Identity Federation** (OIDC) — no service account key files stored in GitHub.

### Required GitHub configuration

**Secrets** (Settings → Secrets → Actions):

| Secret | Description |
|--------|-------------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider resource name |
| `GCP_SERVICE_ACCOUNT` | Service account for CI (`efb-deployer@PROJECT.iam`) |

**Variables** (Settings → Variables → Actions):

| Variable | Example |
|----------|---------|
| `GCP_PROJECT_ID` | `mobile-efb` |
| `GCP_REGION` | `us-central1` |
| `GCP_CLOUDSQL_INSTANCE` | `mobile-efb:us-central1:efb-pg` |
| `CORS_ORIGINS` | `https://app.efb.com` |
| `GCS_BUCKET` | `mobile-efb-prod` |
| `GCS_ATIS_BUCKET` | `efb-atis-prod` |

The workflow dynamically writes `ops/gcp/gcp.env` from these variables, then runs `deploy-cloud-run.sh`.

---

## Manual Deployment

```bash
bash ops/gcp/deploy-cloud-run.sh
```

The script:

1. Reads `ops/gcp/gcp.env` for configuration
2. Submits a Cloud Build job (async, polls every 5s until complete)
3. Deploys `efb-api` — public, autoscaling, `SERVICE_ROLE=api`
4. Deploys `efb-worker` — internal, singleton, CPU always allocated, `SERVICE_ROLE=worker`
5. Mounts Firebase JSON as a file on the worker (if configured)

---

## Verifying a Deployment

1. **Health check**: `curl https://efb-api-XXXXXXXX.run.app/api/health`
2. **Worker logs**: `gcloud run logs read efb-worker --region=us-central1`
3. **Confirm pollers**: look for `poller_worker_started` and `poller_job_enqueued` events in worker logs
4. **Data sources**: check `s_data_sources` table for advancing `last_polled_at` timestamps

---

## Environment & Secrets

### Cloud Run environment variables (both services)

| Variable | Value | Notes |
|----------|-------|-------|
| `NODE_ENV` | `production` | |
| `SERVICE_ROLE` | `api` or `worker` | Controls poller activation |
| `EFB_DATA_DIR` | `/tmp/efb-data` | Ephemeral Cloud Run storage |
| `DB_HOST` | `/cloudsql/PROJECT:REGION:INSTANCE` | Unix socket (no VPC needed) |
| `DB_PORT` | `5432` | |
| `CORS_ORIGINS` | (configured) | Comma-separated origins |
| `FILING_USE_MOCK` | `false` | |
| `LEIDOS_BASE_URL` | `https://lmfsweb.afss.com/Website/rest` | |
| `GCS_BUCKET` | (configured) | Document uploads |
| `GCS_ATIS_BUCKET` | (configured) | ATIS audio recordings |

### Secrets (injected from Secret Manager)

| Env var in container | Secret Manager name | Required |
|---------------------|---------------------|----------|
| `DB_USER` | `EFB_DB_USER` | Yes |
| `DB_PASS` | `EFB_DB_PASS` | Yes |
| `DB_NAME` | `EFB_DB_NAME` | Yes |
| `JWT_SECRET` | `EFB_JWT_SECRET` | Yes |
| `SCRAPINGBEE_API_KEY` | `EFB_SCRAPINGBEE_API_KEY` | Optional |
| `GOOGLE_CLIENT_ID` | `EFB_GOOGLE_CLIENT_ID` | Optional |
| `APPLE_BUNDLE_ID` | `EFB_APPLE_BUNDLE_ID` | Optional |
| `LEIDOS_VENDOR_USER` | `EFB_LEIDOS_VENDOR_USER` | Optional |
| `LEIDOS_VENDOR_PASS` | `EFB_LEIDOS_VENDOR_PASS` | Optional |
| `XWEATHER_CLIENT_ID` | `EFB_XWEATHER_CLIENT_ID` | Optional |
| `XWEATHER_CLIENT_SECRET` | `EFB_XWEATHER_CLIENT_SECRET` | Optional |
| `OPENAI_API_KEY` | `EFB_OPENAI_API_KEY` | Optional |

The worker additionally mounts `EFB_FIREBASE_SERVICE_ACCOUNT_JSON` as a file at `/secrets/firebase-service-account.json` (if configured).

### IAM roles (Cloud Run service account)

| Role | Purpose |
|------|---------|
| `artifactregistry.reader` | Pull container images |
| `secretmanager.secretAccessor` | Read secrets |
| `cloudsql.client` | Connect to Cloud SQL via unix socket |
| `logging.logWriter` | Write structured logs |
| `logging.viewer` | Query logs from admin dashboard |
| `monitoring.metricWriter` | Write metrics |
| `cloudtrace.agent` | Write traces |

---

## Local Development

```bash
# Start PostgreSQL (port 5433)
docker compose up -d db

# Start API with hot-reload (pollers run in-process)
cd api && npm run start:dev
```

Or run everything containerized:

```bash
docker compose up
```

The `docker-compose.yml` defines:
- **db**: PostgreSQL 17 on port 5433 (user/pass/db: `efb`)
- **api**: builds from `api/Dockerfile`, connects to `db` on port 5432

---

## File Reference

```
ops/gcp/
├── README.md                  # This file
├── bootstrap-project.sh       # One-time GCP infrastructure setup
├── deploy-cloud-run.sh        # Build + deploy both Cloud Run services
├── cloudbuild.yaml            # Cloud Build config (Docker build)
├── gcp.env.example            # Template for deployment config
└── gcp.env                    # Actual config (gitignored)

Repo root:
├── .github/workflows/deploy-gcp.yml   # CI/CD pipeline
├── api/Dockerfile                      # Multi-stage Docker build
├── docker-compose.yml                  # Local dev (PostgreSQL + API)
└── .dockerignore                       # Build context exclusions
```

---

## Recommended Hardening

- [ ] Put `/api/admin` behind authentication and network restrictions
- [ ] Add `/api/ready` endpoint that fails when DB is unreachable (separate from `/api/health`)
- [ ] Add Cloud Monitoring alerts: API 5xx rate, p95 latency, worker poller consecutive failures
- [ ] Disable TypeORM `synchronize` in production and use migration scripts
