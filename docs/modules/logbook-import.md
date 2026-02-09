# Logbook Import & Migration
## EFB Product Specification

[← Back to Logbook Module](./logbook.md) | [← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

This document details the plan for importing logbook data from ForeFlight and Garmin Pilot into our application. These are the two most common EFB apps used by Part 91 GA pilots, so supporting migration from both covers the vast majority of potential users switching to our platform.

---

## 1. Overview

| Source | Export Format | Export Location | Complexity |
|--------|-------------|-----------------|------------|
| ForeFlight | CSV (two-table structure) | `plan.foreflight.com` > Logbook > Export | Medium |
| Garmin Pilot | CSV (flat single-table) | `fly.garmin.com` > Logbook > Setup > Export to Spreadsheet | Medium |

Both platforms export decimal hours for durations (e.g., `1.5` = 1h 30m). Neither platform exports track logs, instructor signatures, photos, or endorsements in CSV format.

---

## 2. ForeFlight CSV Format

### 2.1 File Structure

ForeFlight exports a **single CSV file containing two distinct tables**, separated by label rows and blank rows:

```
ForeFlight Logbook Import        ← file label
                                 ← blank row
Aircraft Table                   ← section label
Text,Text,Numeric,...            ← data type declaration row
AircraftID,TypeCode,Year,...     ← column header row
N12345,C172,1975,...             ← data rows
...
                                 ← blank row
Flights Table                    ← section label
Date,Text,Text,...               ← data type declaration row
Date,AircraftID,From,...         ← column header row
2026-01-15,N12345,KAPA,...       ← data rows
...
```

**Important**: This is NOT a simple flat CSV. A naive parser will fail — the file must be split by detecting the `Aircraft Table` and `Flights Table` label rows.

### 2.2 Aircraft Table Columns

| Column | Type | Example | Notes |
|--------|------|---------|-------|
| `AircraftID` | Text | `N977CA` | Include country prefix (e.g., `N` for US) |
| `TypeCode` | Text | `TBM9` | ICAO type designator |
| `Year` | Numeric | `2019` | Year of manufacture |
| `Make` | Text | `Daher` | Manufacturer |
| `Model` | Text | `TBM 930` | Model name |
| `Category` | Text | `Airplane` | Airplane, Rotorcraft, Glider, Lighter Than Air, Powered Lift, Powered Parachute, Weight-Shift-Control, Simulator |
| `Class` | Text | `ASEL` | ASEL, AMEL, ASES, AMES, RH, RG, Glider, etc. |
| `GearType` | Text | `Retractable Tricycle` | Tricycle, Fixed Tailwheel, Retractable Tailwheel, Retractable Tricycle, Floats, Skids |
| `EngineType` | Text | `Turboprop` | Diesel, Electric, Non-Powered, Piston, Radial, Turbofan, Turbojet, Turboprop, Turboshaft |
| `Complex` | Boolean | `TRUE` | |
| `HighPerformance` | Boolean | `TRUE` | |
| `Pressurized` | Boolean | `TRUE` | |

Some exports also include `EquipmentType` and `TAA` (Technically Advanced Aircraft).

### 2.3 Flights Table Columns

#### General

| Column | Type | Format | Notes |
|--------|------|--------|-------|
| `Date` | Date | `YYYY-MM-DD` | ISO 8601 |
| `AircraftID` | Text | `N977CA` | Must match Aircraft Table |
| `From` | Text | `KBJC` | ICAO airport identifier |
| `To` | Text | `KAPA` | ICAO airport identifier |
| `Route` | Text | `CYS GLL` | Intermediate waypoints |

#### Times (Clock — HH:MM 24-hour Zulu)

| Column | Type | Notes |
|--------|------|-------|
| `TimeOut` | hhmm | Out of gate/parking |
| `TimeOff` | hhmm | Wheels-up |
| `TimeOn` | hhmm | Wheels-down |
| `TimeIn` | hhmm | In at gate/parking |
| `OnDuty` | hhmm | Duty start |
| `OffDuty` | hhmm | Duty end |

#### Times (Duration — Decimal Hours)

| Column | Type | Notes |
|--------|------|-------|
| `TotalTime` | Decimal | e.g., `1.5` |
| `PIC` | Decimal | Pilot in Command |
| `SIC` | Decimal | Second in Command |
| `Night` | Decimal | |
| `Solo` | Decimal | |
| `CrossCountry` | Decimal | |
| `ActualInstrument` | Decimal | |
| `SimulatedInstrument` | Decimal | Hood time |
| `DualGiven` | Decimal | Instruction given |
| `DualReceived` | Decimal | Instruction received |
| `SimulatedFlight` | Decimal | Sim/training device |
| `GroundTraining` | Decimal | |
| `Distance` | Decimal | Nautical miles |

#### Hobbs & Tach

| Column | Type |
|--------|------|
| `HobbsStart` | Decimal |
| `HobbsEnd` | Decimal |
| `TachStart` | Decimal |
| `TachEnd` | Decimal |

#### Takeoffs & Landings (Integer Counts)

| Column | Type |
|--------|------|
| `DayTakeoffs` | Numeric |
| `DayLandingsFullStop` | Numeric |
| `NightTakeoffs` | Numeric |
| `NightLandingsFullStop` | Numeric |
| `AllLandings` | Numeric |

#### Instrument

| Column | Type | Notes |
|--------|------|-------|
| `Holds` | Numeric | Number of holding patterns |
| `Approach1` through `Approach6` | Packed Detail | See approach encoding below |

#### Approach Encoding (Approach1–Approach6)

Each approach column uses a **semicolon-delimited packed format** within a single CSV cell:

```
count;type;runway;airport;comments;circle
```

Examples:
- `1;ILS;12L;KVGT;Broke out at 350 AGL`
- `2;RNAV (GPS);36;KTME;comments;circle`

Supported approach types: ASR/SRA, GCA, GLS, ILS, ILS CAT II, ILS CAT III, LDA, LOC, LOC BC, MLS, NDB, PAR, RNAV (GPS), RNAV (RNP), SDF, TACAN, VOR

**Max 6 approaches per flight entry.**

#### People & Remarks

| Column | Type | Notes |
|--------|------|-------|
| `InstructorName` | Text | |
| `InstructorComments` | Text | |
| `Person1` through `Person6` | Text | Crew/passengers |
| `FlightReview` | Boolean | BFR completed |
| `Checkride` | Boolean | |
| `IPC` | Boolean | Instrument Proficiency Check |
| `PilotComments` | Text | Remarks |

#### Custom Fields

Custom fields appear after the standard columns with bracket notation:
- `[Hours]FieldName` — e.g., `[Hours]Aerobatics`
- `[Numeric]FieldName`
- `[Text]FieldName`
- `[Counter]FieldName` — e.g., `[Counter]Tows`
- `[Date]FieldName`
- `[DateTime]FieldName`
- `[Toggle]FieldName`

### 2.4 ForeFlight Quirks & Gotchas

1. **Two-table single-file structure** — must detect and split by section labels
2. **Date format is ISO** — `YYYY-MM-DD`, not US locale
3. **Clock times vs duration times** — `HH:MM` for TimeOut/Off/On/In; decimal hours for all durations
4. **Approach cells are semicolon-delimited** inside a comma-delimited CSV — cells will be quote-wrapped
5. **Re-importing creates duplicates** — ForeFlight has no built-in deduplication
6. **Column order matters** for ForeFlight's own import — we should parse by header name, not position
7. **CSV excludes**: signatures, endorsements, photos, track logs
8. **Airport identifiers use ICAO** (4-letter, e.g., `KAPA`)
9. **Custom field bracket notation is case-sensitive**
10. **All times are Zulu**

### 2.5 How Users Export from ForeFlight

**Via Web:**
1. Log into `plan.foreflight.com`
2. Click **Logbook** in the left menu
3. Click the **Export** tab
4. Select **CSV** format
5. Click **Export** to download

**Via Auto-Export:**
1. Logbook > Settings > Automatic Export
2. Toggle Export to Email
3. Receives CSV via email every 30 days (or tap Export Now)

---

## 3. Garmin Pilot CSV Format

### 3.1 File Structure

Garmin Pilot exports a **flat single-table CSV** with a standard header row followed by data rows. Simpler to parse than ForeFlight.

### 3.2 Known Column Structure

Garmin does not publish an official CSV schema. Based on reverse-engineering from community sources:

```
Date, Aircraft ID, Aircraft Type, [~29 time/operations fields], From, To, Route, ...
```

**Confirmed columns:**
- Column 1: `Date`
- Column 2: `Aircraft ID`
- Column 3: `Aircraft Type`
- Columns 4–32: Time and operations fields (see below)
- Column ~33: `From` (departure airport)
- Column ~34: `To` (arrival airport)
- Column ~35: `Route`

**Likely time/operations fields** (exact header names unconfirmed — best verified by exporting a test entry):
- Total Duration / Total Time
- PIC, SIC, Solo, Cross Country, Night
- Actual Instrument, Simulated Instrument
- Dual Received, Ground Training
- Day Takeoffs, Night Takeoffs, Day Landings, Night Landings
- Number of Approaches, Approach details
- Hobbs Start/End, Tach Start/End
- Remarks/Comments

Custom fields are **appended as extra columns at the end**.

### 3.3 Garmin Pilot Quirks & Gotchas

1. **Date format is US locale** — `M/D/YYYY` or `MM/DD/YYYY` (NOT ISO)
2. **Durations are decimal hours** (same as ForeFlight)
3. **Airport identifiers may use FAA 3-letter codes** (e.g., `APA` not `KAPA`) — needs normalization
4. **Approach data is less structured** — combined field like `ILS-KAPA` rather than ForeFlight's packed format
5. **No embedded Aircraft Table** — only `Aircraft ID` + `Aircraft Type` per row, so aircraft profiles will be minimal stubs
6. **Column count varies by user** — custom fields change the total; always parse by header name
7. **CSV excludes**: signatures (only in JSON export), photos, track logs
8. **No official schema docs** — the definitive way to confirm exact headers is to export from `fly.garmin.com`

### 3.4 How Users Export from Garmin Pilot

1. Sign in to `fly.garmin.com`
2. Select the **Logbook** tab
3. Click **Setup**
4. Click **Export to Spreadsheet**
5. CSV file downloads

Garmin also supports:
- **JSON export** from the mobile app (includes base-64 encoded CFI signatures — backup/restore format)
- **FAA 8710 Report** for checkride applications (formatted summary, not raw data)

---

## 4. Field Mapping: Source → Our Data Model

| Our Field | ForeFlight Column | Garmin Column (approx.) |
|-----------|-------------------|------------------------|
| `date` | `Date` (YYYY-MM-DD) | `Date` (M/D/YYYY) |
| `aircraftId` | `AircraftID` | `Aircraft ID` |
| `aircraftType` | `TypeCode` (from Aircraft Table) | `Aircraft Type` |
| `departureAirport` | `From` (ICAO) | `From` (likely FAA) |
| `arrivalAirport` | `To` (ICAO) | `To` (likely FAA) |
| `route` | `Route` | `Route` |
| `totalTime` | `TotalTime` | Total Duration |
| `pic` | `PIC` | PIC |
| `sic` | `SIC` | SIC |
| `night` | `Night` | Night |
| `solo` | `Solo` | Solo |
| `crossCountry` | `CrossCountry` | Cross Country |
| `actualInstrument` | `ActualInstrument` | Actual Instrument |
| `simulatedInstrument` | `SimulatedInstrument` | Simulated Instrument |
| `dualGiven` | `DualGiven` | — |
| `dualReceived` | `DualReceived` | Dual Received |
| `simulatedFlight` | `SimulatedFlight` | Ground Training |
| `groundTraining` | `GroundTraining` | — |
| `hobbsStart` | `HobbsStart` | Hobbs Start |
| `hobbsEnd` | `HobbsEnd` | Hobbs End |
| `tachStart` | `TachStart` | Tach Start |
| `tachEnd` | `TachEnd` | Tach End |
| `timeOut` | `TimeOut` (HH:MM) | — |
| `timeOff` | `TimeOff` (HH:MM) | — |
| `timeOn` | `TimeOn` (HH:MM) | — |
| `timeIn` | `TimeIn` (HH:MM) | — |
| `dayTakeoffs` | `DayTakeoffs` | Day Takeoffs |
| `nightTakeoffs` | `NightTakeoffs` | Night Takeoffs |
| `dayLandingsFullStop` | `DayLandingsFullStop` | Day Landings |
| `nightLandingsFullStop` | `NightLandingsFullStop` | Night Landings |
| `allLandings` | `AllLandings` | — |
| `holds` | `Holds` | — |
| `approaches[]` | `Approach1`–`Approach6` (packed) | Approach field (combined) |
| `distance` | `Distance` | — |
| `comments` | `PilotComments` | Remarks |
| `instructorName` | `InstructorName` | — |
| `instructorComments` | `InstructorComments` | — |
| `crewPassengers[]` | `Person1`–`Person6` | — |
| `flightReview` | `FlightReview` | — |
| `checkride` | `Checkride` | — |
| `ipc` | `IPC` | — |
| `customFields` | `[Type]Name` columns | Extra columns |

---

## 5. Implementation Plan

### Phase 1: Backend — Parser & Import API

1. **`POST /api/logbook/import`** — accepts CSV file upload + `source` param (`foreflight` | `garmin`)
2. **`ForeFlightParser`** — splits file by section labels, parses Aircraft Table and Flights Table separately, decodes semicolon-packed approaches
3. **`GarminPilotParser`** — parses flat CSV, handles US-locale dates, parses combined approach fields
4. Both parsers normalize into a common `LogbookEntry` interface
5. **Validation layer** — required fields, numeric ranges, date parsing, structured error/warning report per row
6. **Duplicate detection** — match on `(date, aircraftId, from, to, totalTime)` tuple
7. **Dry-run mode** — `?preview=true` returns parsed + validated entries without persisting

### Phase 2: Backend — Aircraft Auto-Creation

1. ForeFlight: auto-create aircraft profiles from the embedded Aircraft Table (type, category, class, gear, engine)
2. Garmin: create stub aircraft entries from `Aircraft ID` + `Aircraft Type` per flight row (deduplicated)
3. Skip creation if aircraft already exists in our system (match by tail number)

### Phase 3: Mobile — Import UX

1. Import entry point: Logbook tab header action or More > Import Logbook
2. Source picker: ForeFlight or Garmin Pilot (with step-by-step export instructions for each)
3. File picker to select CSV from device / Files app
4. **Preview screen** showing:
   - Total entries found
   - Warnings/errors per row (yellow/red)
   - Duplicate detection results
   - Summary totals for sanity checking (total time, entries, date range)
5. Confirm import button
6. Post-import summary: "Imported 563 entries, 1,055.8 total hours"

### Phase 4: Airport Identifier Normalization

- ForeFlight uses ICAO identifiers (`KAPA`) — strip leading `K` for US airports to match our FAA primary key, or look up by `icao_identifier`
- Garmin may use FAA identifiers (`APA`) — direct match to our `identifier` PK
- For non-US or ambiguous identifiers, attempt lookup in our airport database by both fields

### Phase 5: Edge Cases & Polish

- **Custom fields**: store in a JSON `customFields` column to preserve data even without dedicated UI
- **Large imports**: stream-parse for 500+ entry files to control memory
- **Timezone clarity**: document that ForeFlight times are Zulu; display accordingly
- **Partial imports**: allow user to retry failed rows without re-importing successful ones
- **Export support**: once our data model is solid, export to ForeFlight CSV format for round-trip compatibility

---

## 6. What Cannot Be Migrated

| Data | Reason |
|------|--------|
| GPS track logs | Not included in CSV exports from either platform |
| Instructor signatures | ForeFlight excludes from CSV; Garmin only in JSON backup |
| Photos | Not included in any export format |
| Endorsements | Not in CSV exports |
| Currency settings | Calculated from entries — our app recalculates automatically |

---

## 7. Future Considerations

- **MyFlightbook import**: MyFlightbook is a popular free logbook with its own CSV format. Adding a third parser would broaden migration coverage.
- **LogTen Pro import**: Another popular Mac/iOS logbook app with CSV export capability.
- **Bi-directional sync**: ForeFlight supports CSV import with the same format as export — we could eventually allow exporting back to ForeFlight format.
- **Garmin JSON import**: Richer data (including signatures) is available in Garmin's JSON backup format. A JSON parser could recover more data than CSV.

---

## Implementation Status

**Not Started** — This module has no implementation yet. The logbook entry data model is built and supports all the fields needed for import (time tracking, landings, approaches, holds, remarks), but no CSV parsing, file upload, or import UI has been implemented.
