# EFB - Electronic Flight Bag

A flight planning and situational awareness application for US-based general aviation pilots (Part 91). Built with a NestJS backend API and a Flutter cross-platform mobile app.

## Features

- **Airport Directory** — Search, browse, and view detailed airport information sourced from FAA NASR 28-day subscription data. Includes runways, frequencies, procedures, and nearby airports.
- **Weather** — Live METAR, TAF, winds aloft, NOTAMs, and NWS forecasts with automatic caching.
- **Flight Planning** — Create flights with route building, cruise performance calculations (3-phase climb/cruise/descent or single-phase), fuel planning, and weight & balance.
- **Takeoff & Landing Performance (TOLD)** — POH-based takeoff and landing distance calculations with trilinear interpolation across altitude, temperature, and weight. Wind, slope, and surface corrections. Shareable TOLD cards.
- **Aircraft Management** — Aircraft profiles with performance data, fuel tanks, equipment, and weight limits.
- **Aeronautical Maps** — VFR sectional chart tiles with airport overlays, METARs, and airspace boundaries.
- **Weather Imagery** — GFA, prog charts, convective outlooks, icing forecasts, winds aloft charts, PIREPs, and TFRs.
- **Flight Filing** — ICAO flight plan generation and filing via Leidos.
- **Logbook** — Digital logbook with experience tracking and endorsements.
- **Scratchpads** — Freeform notes for in-flight use.

## Prerequisites

- **Node.js** >= 18
- **Docker** (for PostgreSQL)
- **Flutter** >= 3.10
- An iOS Simulator, Android Emulator, or physical device

## Getting Started

### 1. Start the database

```bash
docker compose up -d
```

This starts PostgreSQL on port 5433 (user: `efb`, password: `efb`, database: `efb`).

### 2. Set up the backend

```bash
cd api
npm install
npm run seed               # Import FAA airport data (downloads ~200MB NASR file)
npm run start:dev          # Start dev server on localhost:3001
```

The database schema is auto-created on first run via TypeORM synchronize.

Optional seed commands:

```bash
npm run seed:navaids       # VORs, NDBs, and fixes
npm run seed:procedures    # Instrument approach/departure procedures
npm run seed:routes        # Preferred IFR routes
npm run seed:airspaces     # Airspace boundaries
npm run seed:registry      # FAA aircraft registry
npm run seed:aircraft      # Sample aircraft profiles
```

### 3. Set up the mobile app

```bash
cd mobile
flutter pub get
flutter run
```

The app connects to the backend at `http://localhost:3001/api` by default.

### 4. Running on a device or simulator

See [docs/deployment.md](docs/deployment.md) for detailed setup instructions for iOS Simulator, Android Emulator, and physical devices.

## Project Structure

```
efb/
  .env.example               # Environment variable reference
  docker-compose.yml         # PostgreSQL + API containers
  api/                       # NestJS backend (TypeScript)
    Dockerfile               # Multi-stage production build
    src/
      config/              # Centralized constants & configuration
      airports/            # Airport directory (search, nearby, bounds)
      aircraft/            # Aircraft profiles & performance data
      airspaces/           # Airspace boundaries
      calculate/           # Flight planning calculation engine
      filing/              # Flight plan filing (Leidos integration)
      flights/             # Flight CRUD & route management
      imagery/             # Weather imagery proxy
      logbook/             # Logbook entries & endorsements
      navaids/             # VORs, NDBs, fixes, waypoint resolution
      procedures/          # Instrument procedures (SIDs, STARs, approaches)
      registry/            # FAA aircraft registry
      routes/              # Preferred IFR routes
      seed/                # Database seed scripts (FAA data import)
      tiles/               # VFR sectional chart tile server
      users/               # User profiles & preferences
      weather/             # METAR, TAF, winds aloft, NOTAMs
  mobile/                  # Flutter app (Dart)
    lib/
      core/                # Theme, router, shared widgets
      features/            # Feature modules (maps, airports, flights, etc.)
      models/              # Data models
      services/            # API client, calculators, state providers
  docs/                    # Product specs & module design docs
```

## Development

### Backend commands

```bash
cd api
npm run start:dev          # Dev server with hot-reload
npm run build              # Compile TypeScript
npm test                   # Run Jest tests
npm run test:watch         # Jest in watch mode
npm run test:cov           # Jest with coverage
npm run lint               # ESLint with auto-fix
npm run format             # Prettier formatting
```

### Mobile commands

```bash
cd mobile
flutter run                # Run on connected device/simulator
flutter test               # Run all tests
flutter analyze            # Dart static analysis
flutter build ios          # Build for iOS
flutter build apk          # Build for Android
```

### Environment variables

Copy `.env.example` to `.env` and edit as needed:

```bash
cp .env.example .env
```

The backend uses these environment variables (all optional, shown with defaults):

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3001` | API server port |
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5433` | PostgreSQL port |
| `DB_USER` | `efb` | PostgreSQL user |
| `DB_PASS` | `efb` | PostgreSQL password |
| `DB_NAME` | `efb` | PostgreSQL database |
| `FILING_USE_MOCK` | `true` | Use mock flight filing (`false` for real Leidos API) |
| `LEIDOS_VENDOR_USER` | *(empty)* | Leidos vendor username |
| `LEIDOS_VENDOR_PASS` | *(empty)* | Leidos vendor password |
| `LEIDOS_BASE_URL` | `https://lmfsweb.afss.com/Website/rest` | Leidos API base URL |

### Running with Docker

To run both the database and API in containers:

```bash
docker compose up -d
```

This builds the API image and starts it alongside PostgreSQL. The API is available at `http://localhost:3001`.

To run only the database (and run the API locally for development):

```bash
docker compose up -d db
cd api && npm run start:dev
```

## Architecture

### Backend

NestJS modular monolith with TypeORM and PostgreSQL. Key design decisions:

- **Auto-synchronize** is enabled — schema changes are applied automatically on startup (dev only).
- **In-memory caching** for weather data (METAR: 5 min, TAF: 5 min, winds aloft: 60 min, NOTAMs: 30 min).
- **Flight calculation engine** supports two modes: single-phase (TAS-based) and three-phase (climb/cruise/descent with performance profile data).
- All API endpoints are prefixed with `/api`.

### Frontend

Flutter app using:

- **Riverpod** for state management
- **GoRouter** for navigation (bottom-nav shell route pattern)
- **Dio** for HTTP communication with the backend
- Dark theme optimized for cockpit use

## Data Sources

- **FAA NASR** — Airport, runway, navaid, and fix data ([nfdc.faa.gov](https://nfdc.faa.gov))
- **Aviation Weather Center** — METAR, TAF, winds aloft ([aviationweather.gov](https://aviationweather.gov))
- **FAA NOTAMs** — Notice to Air Missions ([notams.aim.faa.gov](https://notams.aim.faa.gov))
- **FAA TFRs** — Temporary Flight Restrictions ([tfr.faa.gov](https://tfr.faa.gov))
- **NWS** — Point forecasts ([api.weather.gov](https://api.weather.gov))
- **FAA d-TPP** — Terminal procedures ([aeronav.faa.gov](https://aeronav.faa.gov))

## TODO

- GeoRef PDFs
  - Not loading on map page
  - Need to show GPS when viewing PDF plate
- Add layers from weather to the Maps view
- Add a button to send a Flight to the Map
- Settings on Map page
- Nav/waypoints on Map page
- Turbulence in Imagery (see readme)
- Make a list of all of our data sources and the recency for Admin page

## License

UNLICENSED - Private project.
