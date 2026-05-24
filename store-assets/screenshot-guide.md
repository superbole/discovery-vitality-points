# Screenshot Capture Guide — Discovery Vitality Points

This guide explains how to capture clean, representative screenshots for the user manual
and Garmin Connect IQ store listing using the simulator.

---

## Before you start — settings to set

Apply these settings before capturing any screenshot (Object Emulator → Settings or via Garmin Connect):

| Setting | Value for screenshots |
|---|---|
| Validation Mode | **OFF** — removes the debug overlay |
| Age Source | User Profile (or Manual Age = 40–45 for a typical zone spread) |
| Endurance Athlete | OFF (unless shooting endurance-specific screenshots) |
| HR Axis Labels | Names (V/M/L/E) — cleaner than bpm values |
| Crosshair | Red — visible and recognisable |
| Guidance Mode | Next Tier |
| Show HR Guidance | ON |
| Show tier headroom | OFF (cleaner for hero screenshots) |
| Tier colours | Leave at defaults (Yellow / Orange / Green) |

---

## Simulator setup

### 1. Build for the target device

```powershell
# Edge 840 (rectangle CHART-RECT + TILE layouts)
.\build.ps1 -Device edge840 -KeyPath .\developer_key.der

# Forerunner 745 (round CHART-ROUND + STD + TILE layouts)
.\build.ps1 -Device fr745 -KeyPath .\developer_key.der
```

### 2. Open the simulator

Open the Garmin Connect IQ Simulator from the Start menu (or via VS Code Run Task),
then File → Run App → select the `.prg` from `bin/`.

### 3. Load a FIT file

Use `Commute_96_Easy_to_work_212_28_59_.fit` from the project root — moderate intensity,
realistic HR spread across zones.

In the simulator:
1. Set **Data Source → Data Simulation**
2. Click **Load File** → select the `.fit` file
3. Click **Start**
4. Scrub to the target moment using the playback slider or fast-forward

### 4. Scrub to the right moment

| Screenshot | Target state |
|---|---|
| 200 pts (orange) | ~40–45 min elapsed, avg HR in Moderate zone |
| 300 pts (green) | ~65 min elapsed, avg HR in Moderate zone |

### 5. Switch slot size in the simulator

To see different field slot sizes on Edge 840, use the simulator's **Activity** panel to
change the number of data fields displayed. The data field redraws at the new slot dimensions.

**5 Fields B has three distinct layout tiers across its five slots:**

| Simulator setting | Slot | Slot size | Layout class |
|---|---|---|---|
| 1 Field | 1 | 246 × 322 | CHART-RECT |
| 2 Fields | 1 | 246 × 160 | CHART-RECT |
| 5 Fields B | 2 | 246 × 126 | STD |
| 5 Fields B | 1 or 5 | 246 × 63–64 | CMPCT |
| 5 Fields B | 3 or 4 | 122 × 63 | TILE |

On FR745, the full-screen (1-field) is the primary layout; 2-field gives STD.

### 6. Capture the screenshot

Crop tightly to **the data field only** — exclude the simulator chrome and device frame.
Use Windows Snipping Tool (Win+Shift+S). Save as PNG at native resolution (do not upscale).

All screenshots land in `store-assets/screenshots/`.

---

## Full screenshot list (8 shots, 2 build runs)

### Edge 840 build — 4 shots

| File | Slot | Size | State | Purpose |
|---|---|---|---|---|
| `chart-rect-300.png` | 1-field | 246 × 322 | ~65 min, Moderate → 300 pts green | Manual §3 · Store #1 |
| `chart-rect-200.png` | 1-field | 246 × 322 | ~40 min, Moderate → 200 pts orange | Store #2 |
| `chart-rect-2field.png` | 2-field | 246 × 160 | ~40 min, 200+ pts | Store #3 |
| `compact-tile.png` | 5-field B (half) | 122 × 63 | ~40 min | Manual §3 · Store #5 |

### FR745 build — 4 shots

| File | Slot | Size | State | Purpose |
|---|---|---|---|---|
| `chart-round-200.png` | 1-field | 240 × 240 | ~40 min, Moderate → 200 pts | Manual §3 · Store #4 |
| `chart-round-300.png` | 1-field | 240 × 240 | ~65 min, Moderate → 300 pts | Store alt |
| `standard-fr745.png` | 2-field (slot 2) | 240 × 119 | ~40 min, 200 pts | Manual §3 |
| `compact-fr745.png` | 4-field A (slot 2) | 119 × 67 | ~40 min | Extra FR745 |

---

## Wiring into the user manual

Once captured, the four manual screenshots replace placeholders in `user-manual.html`:

| Placeholder | File | Caption |
|---|---|---|
| Chart layout (rect) | `chart-rect-300.png` | Chart layout on Edge 840 — 300 pts, full zone × time grid |
| Chart layout (round) | `chart-round-200.png` | Chart layout on Forerunner 745 — adapted for round display |
| Standard layout | `standard-fr745.png` | Standard layout on Forerunner 745 2-field — current zone row fills the centre |
| Compact layout | `compact-tile.png` | Compact tile layout on Edge 840 5-field B — two numbers + guidance |

---

## Garmin store listing — 5 formatted shots

Garmin requires screenshots at **480 × 800 px** (portrait) or **800 × 480** (landscape).
The native data field crops are smaller — centre each on a `#0d0610` background at 480 × 800.

Recommended order (most impactful first):

| Store slot | Source file | Why |
|---|---|---|
| 1 (hero) | `chart-rect-300.png` | Green = goal achieved — immediately legible in thumbnail |
| 2 | `chart-rect-200.png` | Shows mid-ride guidance in action |
| 3 | `chart-round-200.png` | Demonstrates watch support |
| 4 | `chart-rect-2field.png` | Shows condensed chart for users who prefer multi-field layouts |
| 5 | `compact-tile.png` | Shows compact mode works in a tight strip |

Formatted store images go in `store-assets/Screenshots/` (capital S, the existing store folder).

---

## Slot sizes quick reference

| Device | Slot | Size | Layout class |
|---|---|---|---|
| Edge 840 | 1-field | 246 × 322 | CHART-RECT |
| Edge 840 | 2-field | 246 × 160 | CHART-RECT (condensed rows ~19 px) |
| Edge 840 | 5-field B (half) | 122 × 63 | TILE |
| Forerunner 745 | 1-field | 240 × 240 | CHART-ROUND |
| Forerunner 745 | 2-field (slot 2) | 240 × 119 | STD |
| Forerunner 745 | 4-field A (slot 2) | 119 × 67 | TILE |
