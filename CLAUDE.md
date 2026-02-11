# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EFB (Electronic Flight Bag) is a flight planning and situational awareness application for US-based general aviation pilots (Part 91). It consists of a NestJS backend API and a Flutter cross-platform mobile app.

## Repository Structure

- `api/` — NestJS backend (TypeScript, PostgreSQL via TypeORM, port 3001)
- `mobile/` — Flutter frontend (Dart, Riverpod state management, GoRouter navigation)
- `docs/` — Product development documents (product spec, module designs). Always consult these before implementing new features or making architectural decisions.

## Common Commands

### Backend (api/)

```bash
cd api
npm run start:dev          # Dev server with hot-reload (localhost:3001)
npm run build              # Compile TypeScript
npm run lint               # ESLint with auto-fix
npm run format             # Prettier formatting
npm test                   # Jest unit tests
npm run test:watch         # Jest in watch mode
npm run test:cov           # Jest with coverage
npm run test:e2e           # End-to-end tests
```

#### Database Seeds

All seed scripts run from the `api/` directory. Run them in the order listed for a fresh setup.

```bash
# 1. Airports, runways, frequencies (FAA NASR 28-day data)
npm run seed

# 2. Navaids (VOR, VORTAC, NDB) and fixes/waypoints
npx ts-node -r tsconfig-paths/register src/seed/seed-navaids.ts

# 3. Airspaces, airways, and ARTCC boundaries
npx ts-node -r tsconfig-paths/register src/seed/seed-airspaces.ts

# 4. IFR preferred routes, TEC routes, NARs
npx ts-node -r tsconfig-paths/register src/seed/seed-routes.ts

# 5. Terminal procedures (d-TPP metadata, ~17k records)
npx ts-node -r tsconfig-paths/register src/seed/seed-procedures.ts

# 6. CIFP coded instrument flight procedures (ARINC 424)
npx ts-node -r tsconfig-paths/register src/seed/seed-cifp.ts

# 7. FAA aircraft registry (N-number lookup)
npx ts-node -r tsconfig-paths/register src/seed/seed-registry.ts

# 8. Non-airport weather stations (AWC METAR sources not in airports DB)
npx ts-node -r tsconfig-paths/register src/seed/seed-weather-stations.ts

# 9. Demo user for development
npx ts-node -r tsconfig-paths/register src/seed/seed-users.ts

# 10. Sample aircraft (TBM 960 with profiles, fuel tanks, equipment)
npm run seed:aircraft
```

### Frontend (mobile/)

```bash
cd mobile

# First-time setup: copy .env.example and fill in your API keys
cp .env.example .env

flutter run --dart-define-from-file=.env                # Run on connected device/simulator
flutter build apk --dart-define-from-file=.env          # Build Android APK
flutter build ios --dart-define-from-file=.env           # Build iOS
flutter test               # Run all tests
flutter test test/path_test.dart  # Run single test file
flutter analyze            # Dart static analysis
```

## Architecture

### Backend

NestJS modular monolith with four main modules:

- **AirportsModule** — Airport directory with search, nearby, bounds queries. Entities: Airport → Runway → RunwayEnd, Frequency. Data sourced from FAA NASR 28-day subscription.
- **WeatherModule** — Proxies METAR/TAF from Aviation Weather Center (`aviationweather.gov/api/data`) with 5-minute in-memory cache.
- **TilesModule** — Serves VFR sectional chart tiles from filesystem (`data/charts/tiles/`). Handles TMS↔XYZ coordinate conversion.
- **AdminModule** — Dashboard and job management for seeding airports and processing chart tiles.

Database is PostgreSQL (port 5433, user/pass/db: efb) with TypeORM (auto-synchronize enabled in dev). Run `docker compose up -d` to start the database. All API endpoints are prefixed with `/api`.

**Data pipeline status:** Weather, PIREP, TFR, and advisory data is currently live-proxied from third-party APIs with in-memory caching. Before launch, these need to move to server-side background polling into PostgreSQL. See [Third-Party API Audit](docs/modules/third-party-api-audit.md) for the full plan and [US Data Sources](docs/modules/us-data-sources.md) for implementation status.

### Frontend

Flutter app using Riverpod for state management and GoRouter for navigation with a bottom-nav shell route pattern.

Feature directories under `lib/features/`: maps, airports, flights, aircraft, more. Each feature contains its own screens and widgets.

`lib/services/api_client.dart` wraps Dio for all backend communication (base URL from `AppConfig.apiBaseUrl`, 10s timeout). API keys and URLs are configured via `--dart-define-from-file=.env` (see `lib/core/config/app_config.dart`).

The app uses a dark theme optimized for cockpit use.

## Code Style

- Backend: single quotes, trailing commas (Prettier). ESLint for TypeScript.
- Frontend: Flutter recommended lints (`flutter_lints`).
