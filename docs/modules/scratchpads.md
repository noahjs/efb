# ScratchPads Module

## Overview

ScratchPads provides pilots with a digital notepad for quickly jotting down clearances, ATIS information, PIREPs, holding instructions, and other in-flight notes using Apple Pencil or finger input. It replaces the traditional kneeboard paper pad with a reusable, organized digital equivalent.

ScratchPads is a **primary navigation tab** (replacing Aircraft in the bottom nav bar) given its frequent in-flight usage.

## Priority

**P1** — High-frequency in-flight tool. Pilots copy clearances on nearly every IFR flight.

## User Stories

- As a pilot, I want to quickly jot down an IFR clearance using the CRAFT format so I can read it back accurately.
- As a pilot, I want to write down ATIS information so I have it available during approach.
- As a pilot, I want a blank drawing pad for freeform notes during flight planning or in-flight.
- As a pilot, I want to review previous scratchpads to reference earlier clearances or notes.
- As a pilot, I want to clear and reuse scratchpads so I don't accumulate clutter.

## Screens

### 1. ScratchPads List Screen (`/scratchpads`)

Grid view of all saved scratchpads displayed as thumbnail cards.

**Layout:**
- **App bar**: "Edit" button (left), "ScratchPads" title (center), "+" button (right)
- **Body**: Horizontal-scrolling row or wrapping grid of scratchpad thumbnail cards
- **New Scratchpad card**: Always last in the grid — large "+" icon with "NEW SCRATCHPAD" label

**Thumbnail Card:**
- Miniature preview of the scratchpad content (rendered strokes on template background)
- Template section labels visible (e.g., C/R/A/F/T for CRAFT template)
- Footer bar: creation date (left) + time (right), styled with darker background
- Tap opens the scratchpad in the editor

**Edit Mode:**
- Toggled by "Edit" button
- Shows delete badges on each card
- Allows reordering (drag)

### 2. Template Picker (Bottom Sheet)

Triggered by "+" button or "NEW SCRATCHPAD" card.

**Layout:**
- Header: "Choose A Template"
- 3-column grid of template options

**Templates:**

| Template | Icon | Description |
|----------|------|-------------|
| **DRAW** | Pencil | Blank freeform drawing canvas |
| **TYPE** | Text cursor | Text input scratchpad (keyboard entry) |
| **GRID** | Grid lines | Graph paper background for diagrams |
| **CRAFT** | Boxed "CRAFT" | IFR clearance format: Clearance, Route, Altitude, Frequency, Transponder |
| **ATIS** | Cloud | ATIS recording template with structured fields |
| **PIREP** | Speech bubble | Pilot report template |
| **TAKEOFF** | Airplane ascending | Takeoff briefing template |
| **LANDING** | Airplane descending | Landing/approach briefing template |
| **HOLDING** | Holding pattern | Holding instruction template |

### 3. ScratchPad Editor Screen (Full-Screen)

Full-screen drawing canvas with toolbar overlay.

**Top Toolbar (left to right):**
- **Close** button — saves and returns to list
- **Pen tool** — active drawing tool (highlighted when selected)
- **Color swatches** — white (default), with stroke width indicator
- **Eraser** — switch to erase mode
- **Clear** button — clears all strokes (with confirmation)
- **Undo** button — undoes last stroke

**Date/Time Bar:**
- Centered below toolbar
- Shows creation date in format: "M/D/YY, h:mm AM/PM"

**Canvas:**
- Full-screen drawing area below toolbar
- Template background rendered underneath strokes (e.g., CRAFT section dividers)
- Supports Apple Pencil with pressure sensitivity
- Supports finger drawing as fallback
- Scrollable vertically for long content

**Template Backgrounds:**

**CRAFT Template:**
- Five evenly-spaced horizontal sections
- Left-side labels: **C** (Clearance), **R** (Route), **A** (Altitude), **F** (Frequency), **T** (Transponder)
- Thin horizontal divider lines between sections
- Dark background matching app theme

**DRAW Template:**
- Blank canvas, no guides

**GRID Template:**
- Light grid lines (graph paper style)

**ATIS Template:**
- Structured fields: Information letter, Wind, Visibility, Ceiling, Temperature, Dewpoint, Altimeter, Remarks, NOTAMs

**PIREP Template:**
- Fields: Location, Time, FL/Altitude, Aircraft Type, Sky Cover, Wx, Temp, Wind, Turbulence, Icing, Remarks

**TAKEOFF Template:**
- Sections: Runway, Departure procedure, Initial altitude, Emergency return, Abort criteria

**LANDING Template:**
- Sections: Approach type, Runway, Minimums, Missed approach, Notes

**HOLDING Template:**
- Sections: Fix, Radial/Course, Leg length/time, Direction (L/R), EFC time, Diagram area

## Data Model

### ScratchPad

| Field | Type | Description |
|-------|------|-------------|
| `id` | String (UUID) | Unique identifier |
| `template` | Enum | Template type (draw, type, grid, craft, atis, pirep, takeoff, landing, holding) |
| `strokes` | List<Stroke> | Drawing stroke data |
| `textContent` | String? | Text content (for TYPE template) |
| `createdAt` | DateTime | Creation timestamp |
| `updatedAt` | DateTime | Last modification timestamp |
| `sortOrder` | int | Display order in list |

### Stroke

| Field | Type | Description |
|-------|------|-------------|
| `points` | List<Point> | Ordered points forming the stroke |
| `color` | Color | Stroke color (hex) |
| `strokeWidth` | double | Stroke thickness |
| `isEraser` | bool | Whether this stroke erases |

### Point

| Field | Type | Description |
|-------|------|-------------|
| `x` | double | X coordinate |
| `y` | double | Y coordinate |
| `pressure` | double | Pressure (0.0–1.0, for Apple Pencil) |

## Storage

**Local-only** — ScratchPads are stored on-device using JSON files in the app's documents directory. No backend API required.

```
documents/
  scratchpads/
    {uuid}.json          # Individual scratchpad data
    index.json           # List metadata (order, count)
```

## Drawing Engine

- Built on Flutter `CustomPainter` with gesture detection
- Stroke smoothing for natural handwriting feel
- Pressure-sensitive width variation when Apple Pencil is detected
- Efficient rendering: only repaint changed strokes
- Auto-save on each stroke completion

## Design Notes

- Dark theme consistent with cockpit UI (`AppColors.background`, `AppColors.surface`)
- Template labels in muted white/gray — visible but not distracting
- Stroke color default: white (high contrast on dark background)
- Toolbar uses pill-shaped buttons matching existing app bar style
- Thumbnail cards use `AppColors.card` background with `AppColors.divider` border

## Navigation

ScratchPads occupies the **4th tab** in the bottom navigation bar (between Flights and More), replacing the Aircraft tab (Aircraft moves to More screen).

**Bottom Nav Order:**
1. Airports
2. Maps
3. Flights
4. **ScratchPads** (icon: `Icons.edit_note` or custom pencil)
5. More

**Routes:**
- `/scratchpads` — List screen
- `/scratchpads/new/:template` — Create new with template
- `/scratchpads/:id` — Edit existing

## Future Enhancements

- Cloud sync of scratchpads across devices
- Share/export as image
- Text recognition (OCR) for handwritten clearances
- Pre-populated templates with airport-specific frequencies
- Integration with flight plan (auto-fill departure/destination frequencies)
