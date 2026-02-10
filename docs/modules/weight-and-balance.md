# Weight & Balance Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Weight & Balance module ensures aircraft are loaded within approved limits before each flight. It uses aircraft type certificate data and allows pilots to quickly evaluate the effects of passenger and cargo loading on center of gravity (CG) position and gross weight. The module is tightly integrated with Aircraft Profiles (empty weight, fuel tanks) and Flight Planning (fuel burn, trip fuel).

---

## 1. Core Features

| Feature | Details | Complexity |
|---------|---------|------------|
| W&B Profiles | Create and manage W&B profiles per aircraft. Each profile defines stations (loading positions), CG envelope boundaries, and reference datum. Multiple profiles per aircraft (e.g., "4-Seat Standard", "6-Seat Full Fuel"). | Medium |
| Station Definitions | Configurable loading stations with name, longitudinal arm (distance from datum), optional lateral arm (distance from centerline), weight limits, and category (seat, baggage, fuel, other). Pre-configured for common aircraft. | Medium |
| Loading Interface | Scrollable form for entering weight at each station. Seats allow optional occupant name. Fuel stations pre-fill from aircraft fuel tank configuration. Real-time weight/CG updates as values change. | Medium |
| Envelope Visualization | Graphical CG envelope chart(s) — longitudinal (Weight vs. CG) for all aircraft, plus lateral (Weight vs. Lateral CG) when enabled. Shows current loading point plotted against approved limits. Displays takeoff, zero-fuel, and landing conditions simultaneously. | High |
| Weight Summary Bar | Persistent summary showing BEW, ZFW, TOW, and LDW with actual values and limits. Color-coded status (green = within limits, red = exceeded). | Low |
| Limit Alerts | Visual alerts (red banner, red weight values) when weight or CG exceeds approved envelope at any condition (zero-fuel, takeoff, landing). | Low |
| Pre-loaded Templates | Pre-built W&B templates for common GA aircraft models with type certificate envelope data and standard station configurations. Future enhancement — initial release requires manual profile setup from POH/RFM. | High |
| Lateral CG (Helicopters) | Optional lateral (left-right) CG computation with separate lateral envelope chart. Enabled by default for helicopter category aircraft. Accounts for asymmetric seating, side-mounted cargo, and lateral fuel tank positions. | Medium |
| Fuel Burn CG Shift | Calculate CG position at landing weight by subtracting trip fuel from takeoff condition. Shows CG travel path on envelope chart as fuel burns. | Medium |
| Scenario Comparison | Save and compare multiple loading scenarios for the same aircraft. Duplicate and modify scenarios. | Medium |
| Flight Integration | Link a W&B scenario to a flight plan. Auto-populate fuel from flight fuel calculations. | Medium |
| PDF/Share | Generate a printable W&B summary sheet (weights, CG, envelope chart) for pilot records. | Low |

---

## 2. Concepts & Terminology

### 2.1 Weight & Balance Fundamentals

| Term | Definition |
|------|-----------|
| **Datum** | An imaginary vertical plane from which all horizontal distances (arms) are measured. Defined in the aircraft POH/TCDS. Often the firewall or nose of the aircraft. |
| **Station** | A defined loading position in the aircraft (seat row, baggage compartment, fuel tank). Each station has a fixed **longitudinal arm** (distance from datum) and optionally a **lateral arm** (distance from centerline). |
| **Arm (Longitudinal)** | Horizontal distance (in inches or centimeters) from the datum to the CG of a station, measured along the fore-aft axis. Positive values are aft of datum. |
| **Arm (Lateral)** | Horizontal distance from the aircraft centerline to the CG of a station, measured left/right. Positive values are right of centerline, negative values are left. Used for helicopters and asymmetrically loaded aircraft. |
| **Moment** | Weight × Arm. Computed separately for longitudinal and lateral axes. Used to compute the aggregate CG position. |
| **CG (Center of Gravity)** | The point at which the aircraft would balance. Longitudinal CG = Total Longitudinal Moment ÷ Total Weight. Lateral CG = Total Lateral Moment ÷ Total Weight. Both must remain within their respective approved envelopes. |
| **Longitudinal CG** | Fore-aft CG position. Computed for all aircraft. Plotted on the Weight vs. CG (longitudinal) envelope chart. |
| **Lateral CG** | Left-right CG position relative to centerline. Computed only when lateral CG is enabled (default for helicopters). Plotted on a separate Weight vs. Lateral CG envelope chart. Critical for helicopters where asymmetric loading (e.g., single-pilot, side-mounted fuel) significantly affects controllability. |
| **BEW (Basic Empty Weight)** | Aircraft weight including structure, powerplant, fixed equipment, unusable fuel, and full operating fluids (oil, hydraulic). From aircraft weighing report. |
| **ZFW (Zero Fuel Weight)** | BEW + payload (people + cargo), before fuel is added. Some aircraft have a Max ZFW (MZFW) limit. |
| **Ramp Weight** | ZFW + total fuel. Includes fuel used for taxi/run-up. |
| **TOW (Takeoff Weight)** | Ramp weight minus taxi fuel. Must not exceed MTOW. |
| **LDW (Landing Weight)** | TOW minus trip fuel burned en route. Must not exceed MLW. |
| **Envelope (Longitudinal)** | A polygon on a Weight vs. Longitudinal CG chart defining the approved fore-aft operating range. All aircraft have this. |
| **Envelope (Lateral)** | A polygon on a Weight vs. Lateral CG chart defining the approved left-right operating range. Helicopters and some multi-engine aircraft have this. |

### 2.2 Weight Conditions Computed

The module computes four weight/CG conditions and checks each against the envelope(s):

1. **Zero Fuel** — BEW + all payload, no fuel → check against MZFW envelope (if applicable)
2. **Ramp** — Zero fuel + all fuel loaded → check against max ramp weight
3. **Takeoff** — Ramp weight minus taxi fuel (default 1 gal) → check against MTOW envelope
4. **Landing** — Takeoff weight minus trip fuel → check against MLW envelope

Each condition computes a longitudinal CG (always) and a lateral CG (when `lateral_cg_enabled`). Both must be within their respective envelopes for the condition to pass.

---

## 3. Data Model

### 3.1 Entity: `WBProfile`

A W&B profile defines the loading configuration for a specific aircraft. Each aircraft may have multiple profiles (e.g., different seating configurations, aftermarket modifications).

| Field | Type | Description |
|-------|------|-------------|
| `id` | int (PK) | Auto-generated |
| `aircraft_id` | int (FK → Aircraft) | Parent aircraft |
| `name` | varchar | Profile name (e.g., "4-Seat Standard", "6-Seat Club") |
| `is_default` | boolean | Default profile for this aircraft |
| `datum_description` | varchar, nullable | Human-readable datum reference (e.g., "Forward face of firewall") |
| `lateral_cg_enabled` | boolean, default: false | Whether lateral CG is computed for this profile. Auto-set to `true` when aircraft category is `helicopter`. User can toggle manually. |
| `empty_weight` | float | Basic Empty Weight (lbs). Overrides aircraft-level `empty_weight` for this profile. |
| `empty_weight_arm` | float | Longitudinal arm of BEW CG (inches from datum) |
| `empty_weight_moment` | float | BEW longitudinal moment. Derived: `empty_weight × empty_weight_arm`. Some weighing reports provide moment directly — if entered, arm is back-calculated and vice versa. |
| `empty_weight_lateral_arm` | float, nullable | Lateral arm of BEW CG (inches from centerline). Required when `lateral_cg_enabled` is true. Positive = right, negative = left. |
| `empty_weight_lateral_moment` | float, nullable | BEW lateral moment. Derived: `empty_weight × empty_weight_lateral_arm`. |
| `max_ramp_weight` | float, nullable | Maximum ramp/taxi weight (lbs). Null if same as MTOW. |
| `max_takeoff_weight` | float | Maximum takeoff weight (lbs) |
| `max_landing_weight` | float | Maximum landing weight (lbs) |
| `max_zero_fuel_weight` | float, nullable | Maximum zero fuel weight (lbs). Null if not applicable. |
| `taxi_fuel_gallons` | float, default: 1.0 | Fuel consumed during taxi/run-up (subtracted from ramp to get TOW) |
| `notes` | text, nullable | Free-text notes (e.g., "Per weighing report dated 2024-03-15") |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

**Relations:**
- Has many `WBStation` (ordered by `sort_order`)
- Has many `WBEnvelope` (one per envelope type + axis combination, e.g., normal/longitudinal and normal/lateral)
- Has many `WBScenario`

### 3.2 Entity: `WBStation`

A loading station within a W&B profile. Represents a physical location in the aircraft where weight can be added.

| Field | Type | Description |
|-------|------|-------------|
| `id` | int (PK) | Auto-generated |
| `wb_profile_id` | int (FK → WBProfile) | Parent profile |
| `name` | varchar | Display name (e.g., "Pilot", "Front Passenger", "Rear Left", "Aft Baggage", "Main Fuel") |
| `category` | enum | `seat`, `baggage`, `fuel`, `other` |
| `arm` | float | Longitudinal station arm (inches from datum) |
| `lateral_arm` | float, nullable | Lateral station arm (inches from centerline). Positive = right, negative = left. Only used when profile has `lateral_cg_enabled`. Null for centerline-mounted stations. |
| `max_weight` | float, nullable | Maximum allowable weight at this station (lbs). Null if unlimited. |
| `default_weight` | float, nullable | Pre-filled default weight (e.g., standard pilot weight of 170 lbs) |
| `fuel_tank_id` | int (FK → FuelTank), nullable | Link to aircraft FuelTank entity for fuel stations. Auto-populates capacity and allows syncing fuel level. |
| `sort_order` | int | Display ordering (0-indexed) |
| `group_name` | varchar, nullable | Visual grouping label (e.g., "Flight Deck", "Intermediate Row", "Baggage") |

**Notes:**
- Fuel stations link to existing `FuelTank` entities on the aircraft. When a fuel station is loaded, its max weight is derived from `FuelTank.capacity_gallons × fuel_weight_per_gallon`.
- Seat stations allow an optional occupant name in the loading scenario (for pilot reference only, not persisted on the station definition).

### 3.3 Entity: `WBEnvelope`

Defines one CG envelope boundary as an ordered series of coordinate points forming a closed polygon.

| Field | Type | Description |
|-------|------|-------------|
| `id` | int (PK) | Auto-generated |
| `wb_profile_id` | int (FK → WBProfile) | Parent profile |
| `envelope_type` | enum | `normal`, `utility`, `aerobatic` — the approved flight category |
| `axis` | enum, default: `longitudinal` | `longitudinal` or `lateral` — which CG axis this envelope constrains |
| `points` | jsonb | Array of `{ weight: number, cg: number }` coordinate pairs defining the polygon boundary, ordered clockwise. For longitudinal envelopes, `cg` is the fore-aft arm. For lateral envelopes, `cg` is the left-right offset from centerline. |

**Notes:**
- Most GA fixed-wing aircraft have a single `normal` longitudinal envelope. Some (e.g., Cessna 172) have both `normal` and `utility` longitudinal envelopes with different CG limits.
- Helicopters typically have both a longitudinal envelope and a lateral envelope. The lateral envelope is usually symmetric about centerline (e.g., AS350: ±3.1 inches).
- The polygon is used for point-in-polygon testing to determine if a weight/CG pair is within limits. Each axis is checked independently.
- Envelope coordinates come from the aircraft POH/TCDS Appendix.
- Unique constraint on (`wb_profile_id`, `envelope_type`, `axis`) — a profile cannot have two envelopes for the same type and axis.

### 3.4 Entity: `WBScenario`

A saved loading configuration — the actual weights entered at each station for a specific flight or planning session.

| Field | Type | Description |
|-------|------|-------------|
| `id` | int (PK) | Auto-generated |
| `wb_profile_id` | int (FK → WBProfile) | Profile used |
| `flight_id` | int (FK → Flight), nullable | Linked flight plan (optional) |
| `name` | varchar | Scenario name (e.g., "Weekend trip - 2 pax", "Solo training") |
| `station_loads` | jsonb | Array of `{ station_id: number, weight: number, occupant_name?: string }` |
| `trip_fuel_gallons` | float, nullable | Fuel burned en route (from flight plan or manual entry) |
| `computed_zfw` | float | Calculated zero fuel weight |
| `computed_zfw_cg` | float | Calculated ZFW longitudinal CG arm |
| `computed_zfw_lateral_cg` | float, nullable | Calculated ZFW lateral CG (only when lateral CG enabled) |
| `computed_ramp_weight` | float | Calculated ramp weight (ZFW + fuel) |
| `computed_ramp_cg` | float | Calculated ramp longitudinal CG arm |
| `computed_ramp_lateral_cg` | float, nullable | Calculated ramp lateral CG |
| `computed_tow` | float | Calculated takeoff weight |
| `computed_tow_cg` | float | Calculated takeoff longitudinal CG arm |
| `computed_tow_lateral_cg` | float, nullable | Calculated takeoff lateral CG |
| `computed_ldw` | float | Calculated landing weight |
| `computed_ldw_cg` | float | Calculated landing longitudinal CG arm |
| `computed_ldw_lateral_cg` | float, nullable | Calculated landing lateral CG |
| `is_within_envelope` | boolean | Whether all conditions are within approved limits (both longitudinal and lateral if applicable) |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

---

## 4. CG Calculation Algorithm

### 4.1 Core Computation

```
For each weight condition:
  total_weight = sum of all contributing weights

  Longitudinal (always):
    total_long_moment = sum of (weight × arm) for each item
    long_cg = total_long_moment / total_weight

  Lateral (when lateral_cg_enabled):
    total_lat_moment = sum of (weight × lateral_arm) for each item
    lat_cg = total_lat_moment / total_weight
```

### 4.2 Step-by-Step (Longitudinal)

```
1. Start with BEW:
   long_moment_bew = empty_weight × empty_weight_arm

2. Add payload stations (seats + baggage):
   For each non-fuel station with weight > 0:
     long_moment += station_weight × station_arm

   ZFW = empty_weight + sum(payload weights)
   ZFW_CG = (long_moment_bew + sum(payload long_moments)) / ZFW

3. Add fuel stations:
   For each fuel station with weight > 0:
     long_moment += fuel_weight × station_arm

   Ramp Weight = ZFW + sum(fuel weights)
   Ramp CG = total_long_moment / Ramp Weight

4. Subtract taxi fuel:
   taxi_fuel_weight = taxi_fuel_gallons × fuel_weight_per_gallon
   Subtract from fuel tank(s) proportionally or from first tank

   TOW = Ramp Weight - taxi_fuel_weight
   TOW_CG = (ramp_long_moment - taxi_fuel_long_moment) / TOW

5. Subtract trip fuel:
   trip_fuel_weight = trip_fuel_gallons × fuel_weight_per_gallon
   Subtract from fuel tank(s)

   LDW = TOW - trip_fuel_weight
   LDW_CG = (tow_long_moment - trip_fuel_long_moment) / LDW
```

### 4.3 Step-by-Step (Lateral — when enabled)

Lateral CG is computed in parallel with the same weight values but using `lateral_arm` instead of `arm`.

```
1. Start with BEW:
   lat_moment_bew = empty_weight × empty_weight_lateral_arm

2. Add payload stations:
   For each non-fuel station with weight > 0:
     lateral_arm = station_lateral_arm ?? 0  (null treated as centerline)
     lat_moment += station_weight × lateral_arm

   ZFW_LAT_CG = (lat_moment_bew + sum(payload lat_moments)) / ZFW

3. Add fuel stations:
   For each fuel station with weight > 0:
     lateral_arm = station_lateral_arm ?? 0
     lat_moment += fuel_weight × lateral_arm

   Ramp LAT_CG = total_lat_moment / Ramp Weight

4–5. Subtract taxi/trip fuel (same approach as longitudinal):
   TOW_LAT_CG = (ramp_lat_moment - taxi_fuel_lat_moment) / TOW
   LDW_LAT_CG = (tow_lat_moment - trip_fuel_lat_moment) / LDW
```

**Lateral CG significance for helicopters:**
- Helicopters are especially sensitive to lateral CG because the rotor system has limited lateral cyclic authority.
- Common lateral CG drivers: single-pilot operations (empty right seat), side-mounted external cargo, asymmetric fuel burn, door-off operations.
- Typical lateral CG limits are narrow (e.g., AS350: ±3.1 in, R44: ±2.4 in).

### 4.4 Envelope Check

For each condition (ZFW, TOW, LDW), perform point-in-polygon tests:

**Longitudinal (always):**
```
point = (long_cg, weight)
polygon = longitudinal_envelope.points[]
Result: INSIDE or OUTSIDE
```

**Lateral (when lateral_cg_enabled):**
```
point = (lat_cg, weight)
polygon = lateral_envelope.points[]
Result: INSIDE or OUTSIDE
```

Use a standard ray-casting algorithm for point-in-polygon. Additionally check:
- Weight ≤ applicable max weight limit (MZFW, MTOW, MLW)
- Longitudinal CG within forward and aft limits at the computed weight
- Lateral CG within left and right limits at the computed weight (when enabled)

A condition is within limits only if **both** longitudinal and lateral (when applicable) envelopes pass.

---

## 5. UI Design

### 5.1 Screen: W&B Home (`/weight-balance`)

The primary W&B screen accessed from the bottom navigation bar.

**Layout (top to bottom):**

1. **Aircraft/Profile Selector** — Dropdown showing `{tail_number} - {profile_name}`. Edit button to modify profile. Button to create new scenario.

2. **Alert Banner** — Red banner shown when any limit is exceeded (e.g., "Takeoff weight exceeds MTOW by 120 lbs", "CG aft of limit at landing weight", "Lateral CG 1.2 in right of limit at takeoff weight").

3. **Weight Summary Bar** — Horizontal row of four weight conditions:
   | BEW | ZFW | TOW | LDW |
   |-----|-----|-----|-----|
   | 2,450 lbs | 2,890 / 3,100 lbs | 3,290 / 3,400 lbs | 3,050 / 3,400 lbs |

   Format: `actual / limit`. Actual shown in red if exceeds limit. Dash (`-`) if not yet calculable.

4. **CG Envelope Chart(s)** — Interactive chart(s):

   **Longitudinal Envelope (always shown):**
   - X-axis: Longitudinal CG (inches)
   - Y-axis: Weight (lbs)
   - Envelope boundary polygon (red outline)
   - Reference lines for Structural MTOW, MLW, MZFW
   - Plotted points for ZFW, TOW, LDW conditions (color-coded)
   - Optional: line connecting ZFW → TOW → LDW showing CG travel path
   - Pinch to zoom, tap point for details

   **Lateral Envelope (shown when `lateral_cg_enabled`):**
   - Displayed below or as a swipeable second chart alongside the longitudinal chart
   - X-axis: Lateral CG (inches from centerline, with 0 at center)
   - Y-axis: Weight (lbs)
   - Envelope boundary polygon (typically symmetric about centerline)
   - Same plotted condition points (ZFW, TOW, LDW)
   - Header: "LATERAL CG" to distinguish from the longitudinal chart

5. **Stations List** — Grouped by category with section headers:
   - **SEATS (LBS)** — Each station shows: Name, Group + Arm(s), Weight (editable), Occupant name (optional). When lateral CG is enabled, both arms are shown. Example (fixed-wing):
     ```
     Pilot                           170
     Flight Deck (178.5 in)         Noah

     Front Passenger                 195
     Flight Deck (178.5 in)          Bob
     ```
     Example (helicopter with lateral CG):
     ```
     Pilot                           170
     Front (107.0 in, L 9.5 in)    Noah

     Front Passenger                 195
     Front (107.0 in, R 9.5 in)     Bob

     Left Rear                        45
     Rear (148.0 in, L 10.2 in)   Ollie
     ```

   - **BAGGAGE (LBS)** — Same layout without occupant name:
     ```
     Forward Baggage                   30
     Baggage (248.0 in)

     Aft Baggage                        0
     Baggage (284.0 in)
     ```

   - **FUEL (LBS or GAL)** — Fuel stations with toggle between lbs/gallons. When lateral CG is enabled, lateral arm shown:
     ```
     Left Main                     30 gal
     Wing (195.0 in)            201.0 lbs

     Right Main                   30 gal
     Wing (195.0 in)            201.0 lbs
     ```
     Example (helicopter with lateral CG):
     ```
     Main Tank                     65 gal
     Fuel (130.0 in, L 5.0 in) 438.8 lbs
     ```

6. **Summary Button** — Opens a detailed W&B summary view suitable for printing/sharing.

### 5.2 Screen: W&B Profile Editor

Accessed via "Edit" button on the W&B home screen. Allows configuration of the W&B profile.

**Sections:**

1. **Profile Info** — Name, notes, datum description, lateral CG toggle (on/off)
2. **Aircraft Weights** — BEW, BEW Longitudinal Arm, BEW Lateral Arm (when lateral enabled), MTOW, MLW, MZFW, Max Ramp Weight, Taxi Fuel
3. **Stations** — Add/edit/remove/reorder stations. Each station: name, category, longitudinal arm, lateral arm (when lateral enabled), max weight, group name, default weight, fuel tank link
4. **Envelopes** — Add/edit envelope points for longitudinal envelope(s). When lateral CG enabled, a second tab/section for lateral envelope points. Tabular entry or import from template. Visual preview of the polygon as points are entered.

### 5.3 Screen: W&B Summary (Print View)

A clean, formatted summary for pilot records:

- Aircraft tail number and profile name
- Date and scenario name
- Table of all stations with weight, longitudinal arm, moment (and lateral arm/moment when enabled)
- Subtotals for BEW, ZFW, Ramp, TOW, LDW with longitudinal CG (and lateral CG when enabled)
- Longitudinal CG envelope chart with all conditions plotted
- Lateral CG envelope chart with all conditions plotted (when enabled)
- Pass/fail status for each condition (both axes)
- Share/export as PDF

### 5.4 Screen: Scenario Manager

- List of saved scenarios for the selected aircraft
- Duplicate, rename, delete scenarios
- Compare two scenarios side-by-side (split view with both envelope charts)

---

## 6. Example Profiles

The two examples below show what a fully configured W&B profile looks like for each aircraft category — a fixed-wing turboprop (longitudinal CG only) and a helicopter (longitudinal + lateral CG). These illustrate the data a user enters when setting up a new profile from their aircraft's POH and weighing report.

### 6.1 Fixed-Wing Example: TBM 960 (TBM9)

Single-engine turboprop, 6-seat pressurized cabin. Longitudinal CG only. Complex envelope with MZFW limit.

**Profile:**

| Field | Value |
|-------|-------|
| Name | 6-Seat Standard |
| Datum | Forward face of firewall |
| Lateral CG Enabled | No |
| BEW | 4,745 lbs *(from aircraft weighing report)* |
| BEW Arm | *(from weighing report — typically ~188 in)* |
| Max Ramp Weight | 7,430 lbs |
| MTOW | 7,394 lbs |
| MLW | 7,110 lbs |
| MZFW | 6,252 lbs |
| Taxi Fuel | 2 gal |

**Stations:**

| # | Name | Category | Group | Arm (in) | Max Weight (lbs) | Default Weight |
|---|------|----------|-------|----------|-----------------|----------------|
| 0 | Pilot | seat | Flight Deck | 178.5 | — | 170 |
| 1 | Copilot | seat | Flight Deck | 178.5 | — | — |
| 2 | Left Seat | seat | Intermediate Row | 224.8 | — | — |
| 3 | Right Seat | seat | Intermediate Row | 224.8 | — | — |
| 4 | Left Seat | seat | Aft Row | *(from POH — ~258 in)* | — | — |
| 5 | Right Seat | seat | Aft Row | *(from POH — ~258 in)* | — | — |
| 6 | Forward Baggage | baggage | Baggage | *(from POH)* | *(from POH)* | — |
| 7 | Aft Baggage | baggage | Baggage | *(from POH)* | 220 | — |
| 8 | Main Fuel | fuel | Fuel | *(from POH — ~195 in)* | — | — |

*Fuel station links to the aircraft's FuelTank entity. Max weight derived from tank capacity (291 gal) × 6.75 lbs/gal.*

**Longitudinal Envelope (normal category):**

Points define the polygon boundary from the POH CG envelope chart. Example structure:

```json
[
  { "weight": 4000, "cg": 182.0 },
  { "weight": 4000, "cg": 194.0 },
  { "weight": 7394, "cg": 194.0 },
  { "weight": 7394, "cg": 187.0 },
  ...
]
```

*Exact coordinates transcribed from the POH Appendix — the envelope is not a simple rectangle; it typically narrows at higher weights with a more restrictive forward CG limit.*

---

### 6.2 Helicopter Example: Airbus AS350 B3e / H125 (AS50)

Single-engine turbine helicopter, 1+5 seating. Both longitudinal and lateral CG required.

**Profile:**

| Field | Value |
|-------|-------|
| Name | Standard 5-Pax |
| Datum | *(from RFM — reference plane forward of aircraft nose)* |
| Lateral CG Enabled | **Yes** *(auto-set, aircraft category = helicopter)* |
| BEW | *(from weighing report — typically ~2,976 lbs)* |
| BEW Longitudinal Arm | *(from weighing report)* |
| BEW Lateral Arm | *(from weighing report — ideally near 0)* |
| Max Ramp Weight | 5,512 lbs |
| MTOW | 5,512 lbs |
| MLW | 5,512 lbs |
| MZFW | — |
| Taxi Fuel | 1 gal |

**Stations:**

| # | Name | Category | Group | Arm (in) | Lateral Arm (in) | Max Wt (lbs) | Default Wt |
|---|------|----------|-------|----------|-------------------|-------------|------------|
| 0 | Pilot | seat | Front Row | *(RFM)* | *(RFM, R +X in)* | — | 170 |
| 1 | Front Passenger | seat | Front Row | *(RFM)* | *(RFM, L -X in)* | — | — |
| 2 | Rear Left | seat | Rear Bench | *(RFM)* | *(RFM, L -X in)* | — | — |
| 3 | Rear Center | seat | Rear Bench | *(RFM)* | 0 | — | — |
| 4 | Rear Right | seat | Rear Bench | *(RFM)* | *(RFM, R +X in)* | — | — |
| 5 | Baggage Compartment | baggage | Baggage | *(RFM)* | 0 | 265 | — |
| 6 | Main Fuel | fuel | Fuel | *(RFM)* | *(RFM)* | — | — |

*Note: Pilot sits in the right seat (standard for helicopters). Lateral arms are measured from aircraft centerline — positive = right, negative = left. "RFM" = Rotorcraft Flight Manual, the helicopter equivalent of a POH.*

**Longitudinal Envelope (normal category):**

```json
[
  { "weight": 2600, "cg": ... },
  { "weight": 5512, "cg": ... },
  ...
]
```

*Transcribed from the RFM longitudinal CG envelope chart.*

**Lateral Envelope (normal category):**

Lateral envelope is typically symmetric about centerline. Example structure:

```json
[
  { "weight": 2600, "cg": -3.1 },
  { "weight": 5512, "cg": -3.1 },
  { "weight": 5512, "cg": 3.1 },
  { "weight": 2600, "cg": 3.1 }
]
```

*Lateral CG limits for the AS350 B3e are approximately ±3.1 in (±80mm) across the full weight range. This forms a narrow vertical band on the lateral envelope chart. Exceeding lateral CG limits reduces lateral cyclic authority — especially critical in hover and low-speed flight.*

---

### 6.3 Adding a New Profile

The user flow for creating a W&B profile:

1. **Navigate** to Aircraft → select aircraft → W&B Profiles → New Profile
2. **Enter profile info** — name, datum description
3. **Enter aircraft weights** from the weighing report — BEW, BEW arm (and lateral arm if helicopter). Enter max weight limits from POH/RFM.
4. **Define stations** — add each loading position from the POH loading arrangement diagram. Enter name, category, longitudinal arm (and lateral arm for helicopters). Set max weights where applicable (baggage compartments).
5. **Link fuel stations** to aircraft fuel tanks — max weight auto-calculates from tank capacity × fuel weight per gallon.
6. **Enter envelope points** — transcribe the CG envelope polygon coordinates from the POH/RFM appendix. For helicopters, enter both longitudinal and lateral envelopes.
7. **Verify** — load a known scenario (e.g., solo pilot + full fuel) and confirm the computed CG matches a hand calculation.

Future enhancement: pre-loaded templates for common aircraft types can seed steps 3–6 from TCDS/POH data, with the user only needing to update BEW and BEW arm from their specific weighing report.

---

## 7. Integration Points

### 7.1 Aircraft Profiles Module

- **W&B Profile → Aircraft**: Each W&B profile belongs to an aircraft (by `aircraft_id`). The aircraft entity already stores `empty_weight`, `max_takeoff_weight`, `max_landing_weight`, and `fuel_weight_per_gallon` — these serve as defaults when creating a new W&B profile.
- **Fuel Tanks → Fuel Stations**: W&B fuel stations link to `FuelTank` entities. Fuel capacity and weight-per-gallon are sourced from the aircraft/tank config.
- **Profile Templates**: When a user applies a W&B template (e.g., "Cessna 172S"), it auto-creates stations and envelope data on the W&B profile.

### 7.2 Flight Planning Module

- **Scenario → Flight**: A W&B scenario can be linked to a flight via `flight_id`. When linked:
  - Trip fuel is auto-populated from the flight's calculated fuel burn.
  - Fuel load can be derived from the flight's required fuel (trip + reserve + alternate + taxi).
- **Flight Detail Screen**: The existing `FlightWeightsSection` widget (currently shows ZFW, Ramp, TOW, LDW as simple calculations) should be enhanced to link to the full W&B module for CG-aware calculations.
- **Preflight Checklist**: W&B status (pass/fail) displayed in flight briefing.

### 7.3 Maps Module (Future)

- Glide range ring already uses aircraft `best_glide_speed` and `glide_ratio` — could factor in actual gross weight for more accurate glide distance.

---

## 8. Backend API Endpoints

All endpoints prefixed with `/api/aircraft/:aircraftId/wb`.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/profiles` | List all W&B profiles for an aircraft |
| `POST` | `/profiles` | Create a new W&B profile |
| `GET` | `/profiles/:profileId` | Get profile with stations and envelopes |
| `PUT` | `/profiles/:profileId` | Update profile details |
| `DELETE` | `/profiles/:profileId` | Delete a profile |
| `POST` | `/profiles/:profileId/apply-template` | Apply a pre-loaded aircraft type template |
| `POST` | `/profiles/:profileId/stations` | Add a station |
| `PUT` | `/profiles/:profileId/stations/:stationId` | Update a station |
| `DELETE` | `/profiles/:profileId/stations/:stationId` | Remove a station |
| `PUT` | `/profiles/:profileId/stations/reorder` | Reorder stations |
| `PUT` | `/profiles/:profileId/envelopes` | Set envelope points (upsert by type + axis) |
| `GET` | `/profiles/:profileId/scenarios` | List saved scenarios |
| `POST` | `/profiles/:profileId/scenarios` | Create/save a scenario |
| `GET` | `/profiles/:profileId/scenarios/:scenarioId` | Get a scenario |
| `PUT` | `/profiles/:profileId/scenarios/:scenarioId` | Update a scenario |
| `DELETE` | `/profiles/:profileId/scenarios/:scenarioId` | Delete a scenario |
| `POST` | `/profiles/:profileId/calculate` | Compute W&B for a given set of station loads (stateless — does not save) |
| `GET` | `/templates` | List available W&B templates (not aircraft-scoped) |

---

## 9. Frontend State Management

Following the Riverpod patterns established in the aircraft module:

| Provider | Type | Purpose |
|----------|------|---------|
| `wbProfilesProvider(aircraftId)` | `FutureProvider` | List of W&B profiles for an aircraft |
| `wbProfileProvider(profileId)` | `FutureProvider` | Single profile with stations and envelopes |
| `wbScenariosProvider(profileId)` | `FutureProvider` | Saved scenarios for a profile |
| `wbCalculationProvider` | `StateNotifierProvider` | Live W&B calculation state — holds current station loads, computes weights/CG in real-time as user edits values |
| `selectedWBProfileProvider` | `StateProvider` | Currently selected profile ID |

The `wbCalculationProvider` performs all CG math client-side for instant feedback. The `/calculate` API endpoint serves as a validation/confirmation step and for generating the PDF summary.

---

## 10. Implementation Status

**Not Started** — This module has no implementation yet. All features remain spec-only.

### Suggested Build Order

| Phase | Features | Dependencies |
|-------|----------|--------------|
| **Phase 1 — Core** | W&B Profile entity + CRUD, Station definitions, CG envelope entity, basic calculation engine, envelope chart visualization, weight summary bar | Aircraft module (existing) |
| **Phase 2 — Loading UI** | Station loading interface, real-time CG updates, limit alerts, fuel station ↔ fuel tank linking | Phase 1 |
| **Phase 3 — Templates** | Pre-loaded templates for common aircraft types (future — seeded from TCDS/POH data), template application flow | Phase 1 |
| **Phase 4 — Scenarios** | Save/load scenarios, link to flights, trip fuel auto-population | Phase 2, Flight Planning module |
| **Phase 5 — Polish** | PDF export, scenario comparison, side-by-side view, enhanced envelope chart interactions | Phase 3, Phase 4 |
