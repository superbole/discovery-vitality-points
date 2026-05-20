# Screenshot Capture Guide — Discovery Vitality Points

This guide explains how to capture clean, representative screenshots for the Garmin Connect IQ store listing using the simulator, and what makes a good real-device photo.

---

## Before you start — settings to set

Before capturing any screenshot, apply these settings in the simulator (Object Emulator → Settings or via Garmin Connect):

| Setting | Value for screenshots |
|---|---|
| Validation Mode | **OFF** — removes the debug overlay |
| Age Source | User Profile (or Manual Age = 40–45 for a typical zone spread) |
| Endurance Athlete | OFF (unless shooting endurance-specific screenshots) |
| HR Axis Labels | Names (V/M/L/E) — shows zone names, looks cleaner than bpm values |
| Crosshair | Red — visible and recognisable |
| Guidance Mode | Next Tier |
| Show HR Guidance | ON |
| Show tier headroom | OFF (cleaner for hero screenshots; can shoot a second set with it ON) |
| Tier colours | Leave at defaults (Yellow / Orange / Green) |

---

## Simulator setup

### 1. Build for the target device
```powershell
# Edge 840 (rect chart layout)
.\build.ps1 -Device edge840 -KeyPath .\developer_key.der

# Forerunner 745 (round chart layout)
.\build.ps1 -Device fr745 -KeyPath .\developer_key.der

# Fēnix 5X Plus (round, square-ish form factor)
.\build.ps1 -Device fenix5xplus -KeyPath .\developer_key.der
```

### 2. Open the simulator
- Visual Studio Code: Run Task → `Run: edge840` (or whichever device)
- Or: open the Garmin Connect IQ Simulator from the Start menu, then File → Run App → select the `.prg` from `bin/`

### 3. Load a FIT file for realistic data
Use one of the FIT files in the project root — `Commute_96_Easy_to_work_212_28_59_.fit` is a good one (28+ minutes, moderate intensity, realistic HR).

In the simulator:
1. Set **Data Source → Data Simulation**
2. Click **Load File** → select the `.fit` file
3. Click **Start**
4. Wait for the activity to progress to an interesting point (see targets below)

### 4. Scrub to the right moment
Use the playback slider or the fast-forward button to reach a good data state. Good targets:

| Screenshot | Target state |
|---|---|
| Chart – mid ride | ~30–45 min, avg HR in Moderate zone → shows 200 pts in orange cell |
| Chart – green 300 | ~65 min, avg HR in Moderate → shows 300 pts in green cell |
| Chart – vigorous | ~20 min, avg HR in Vigorous → shows 100 pts in red/orange with yellow cells visible |
| Standard layout | Same data, just a different field slot |
| Compact layout | Same data on a narrow field slot |

### 5. Capture the screenshot
- **In the simulator**: the data field renders inside the simulated device screen. Use Windows Snipping Tool (Win+Shift+S) to crop tightly around just the data field area — exclude the simulator chrome.
- Aim for the data field slot only, not the whole device screen.
- Save as PNG at native resolution (do not upscale).

---

## Recommended screenshot set (6 images)

### Screenshot 1 — CHART RECT: full ride in progress (Edge 840)
- **Device**: Edge 840, 1-field layout (full screen slot, 246×322)
- **State**: ~45 min, avg HR ~145 bpm (Moderate zone), 200 pts showing in orange cell
- **Shows**: full 4×5 zone/time grid, orange current cell with "200" large, trend line, crosshairs, heart+HR header, guidance line
- **Caption**: "Live points chart — see your current tier at a glance on Edge 840"

### Screenshot 2 — CHART RECT: 300 points locked in (Edge 840)
- **Device**: Edge 840, 1-field layout
- **State**: ~65 min, avg HR Moderate → green cell shows 300
- **Shows**: 300 pts in green, trend line shows sustained effort, guidance shows "Max tier" or next endurance tier
- **Caption**: "300 points confirmed — green means you've hit your target"

### Screenshot 3 — CHART ROUND: FR745 full screen
- **Device**: Forerunner 745, 1-field layout (240×240 round)
- **State**: ~30–40 min, avg HR Moderate, 200 pts
- **Shows**: round layout with inscribed chart, heart+HR header in the round bezel area
- **Caption**: "Round watch layout — works perfectly on the Forerunner 745"

### Screenshot 4 — STANDARD layout (Edge 840, 3-field slot)
- **Device**: Edge 840, 3-field layout (246×106 or 246×126)
- **State**: ~35 min, avg HR Moderate
- **Shows**: zoomed matrix (current zone row full height, partial rows above/below), guidance line in header, points centred
- **Caption**: "Zoomed view on smaller slots — current zone fills the display"

### Screenshot 5 — COMPACT layout (Edge 840, 4-field slot)
- **Device**: Edge 840, 4-field layout (246×79)
- **State**: same data
- **Shows**: two large numbers (HR + points) with guidance pipe below
- **Caption**: "Compact mode — HR, points, and guidance in a single strip"

### Screenshot 6 — Alerts / settings (optional)
- Screenshot of the settings screen in Garmin Connect showing the key options
- Or: a photo of the full-screen tier-change alert on device
- **Caption**: "Customise tier colours, guidance, and alerts in Garmin Connect"

---

## Real-device photos

A photo of the data field actually running on your bike or on your wrist is the most compelling store image. Tips:

- **Lighting**: shoot outdoors in bright shade, or indoors under a soft window light. Avoid direct sun (washes out the screen) and dark rooms (noisy, blurry).
- **Angle**: straight-on, screen parallel to the camera. A slight tilt (5–10°) can look natural for bike-mounted Edge shots.
- **State**: aim for 200 or 300 pts showing — a green cell is immediately legible in a thumbnail.
- **Edge 840 on bike**: mount it properly, get the bars and stem in background for context. Blurred background (portrait mode or shallow DOF) helps the screen stand out.
- **FR745/Fēnix on wrist**: wear it, hold arm out naturally, shoot at wrist level.
- **Crop**: for the store, a tight crop to just the device (no fingers, no distracting background) usually works best.

---

## Garmin store image specs

| Type | Size | Format |
|---|---|---|
| Screenshots | 480×800 or 800×480 (portrait/landscape) | PNG or JPEG |
| Hero image | 1280×720 | PNG or JPEG |
| Icon | Submitted as part of the app package | PNG (various sizes, in `resources/drawables/`) |

Garmin will accept up to 5 screenshots. Recommended order:
1. Edge 840 chart (300 pts green) — most impactful thumbnail
2. Edge 840 chart (200 pts, mid-ride)
3. FR745 round layout
4. Standard layout (3-field slot)
5. Compact / settings

---

## Slot sizes quick reference

| Device | Layout tier triggered | Slot (1-field) |
|---|---|---|
| Edge 840 | CHART-RECT | 246×322 |
| Edge 840 | STANDARD (3-field) | 246×106–129 |
| Edge 840 | COMPACT (4-field) | 246×79 |
| Forerunner 745 | CHART-ROUND | 240×240 |
| Fēnix 5X Plus | CHART-ROUND | 240×240 |
