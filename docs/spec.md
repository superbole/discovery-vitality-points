# Discovery Vitality Points — Garmin Data Field Spec

Goal: a **Connect IQ data field** that helps the user **predict** Discovery Vitality “fitness points” for the current activity using **age, average HR, and duration** (and optionally steps / speed when HR isn’t available).

This file is written so it can be handed to Claude to implement in this repo.

## Scope

### In scope (v1)
- Compute **predicted points** from **average HR** and **duration**.
- Display (see `docs/design-spec.md` for per-slot layouts):
  - **Current predicted points** (based on current avg HR + duration so far)
  - **Guidance** (configurable):
    - Default: **Next tier** requirements, shown as **`12m | 8bpm`** (minutes to next band pipe HR delta above current avg)
    - Optional: **Target points** requirements (e.g., target=300)
  - For the chosen tier/target, show:
    - **minutes remaining** at current intensity, and
    - **HR requirement** to reach/maintain that tier:
      - `HR ≥ <bpm>` and, if below, `(-<delta>bpm)` difference
  - Optional (configurable): **avg HR** and **zone label**
- Handle **<65** vs **65+** rule set (derived from age; override available).
- Handle optional **Endurance / High Performance Athlete** rule set (configurable; default OFF).
- Fallback scoring when HR is not available:
  - Steps-based points
  - Speed-based points (when activity type supports it and HR is unavailable)

### Out of scope (v1)
- Weekly/monthly/annual caps enforcement (we can display a note but not track caps).
- Deep workout type classification beyond basic activity-profile detection.
- Race-specific/“parkrun” detection from events.
- Anything that requires login, network calls, or Discovery APIs.

## References (for human verification)
- Discovery Vitality points help: `https://www.discovery.co.za/vitality/help-points`
- Garmin benefit guide: `https://www.discovery.co.za/wcm/discoverycoza/assets/vitality/benefit-rules/garmin-benefit-guide.pdf`
- HR zone table and rule summary (legacy but aligns with 220-age): `http://www.angelavanbreda.co.za/wp-content/uploads/2019/10/Summary-of-Vitality-Points-2019-1.pdf`

## User Inputs

### Required
- **Age source**:
  - Preferred: read **age/DoB from Garmin user profile** if the Connect IQ API exposes it for this app/device.
  - Fallback: user-configured **Date of birth (DoB)** (day/month/year) or **Age (years)**.
  - If DoB is known, age calculation should be **date-accurate** (increments on birthday), not just year difference. If only Age is known, treat it as the current age.
- **Endurance / High Performance Athlete**:
  - toggle, default **OFF** (only enable if the member is actually registered).
- **Guidance / Target settings**:
  - Guidance mode:
    - `Next tier` (default)
    - `Target points`
  - Target points:
    - Normal: 100 / 200 / 300
    - Endurance enabled: 100 / 200 / 300 / 450 / 600

### Derived (no explicit toggle required)
- **Member category `<65` vs `65+`** is derived from age.
  - Provide an override only for edge cases.

### Explicitly NOT implemented (v1)
- Weekly goal / caps display (not useful during a workout without current balance).

## Data Inputs from Garmin (runtime)

From `Toybox.Activity.Info` (data field `compute(info)`):
- **Average HR (bpm)**:
  - Use the **best available average HR field** exposed by Connect IQ for data fields.
  - Implementation detail: probe available members at runtime defensively (try known names) and fall back gracefully.
- **Duration seconds**:
  - We do not know with certainty whether Discovery uses **moving time** or **elapsed time**.
  - Data field should prefer **moving/active time if available**, otherwise fall back to elapsed time.
  - Convert to whole minutes using `mins = floor(durationSeconds / 60)`.

Fallback data (only if HR unavailable):
- **Steps** (walking/hiking/general).
- **Speed / pace** for activity types where it makes sense:
  - running, cycling, swimming (where available).
  - Apply speed rules **only when HR is unavailable and speed/pace is measurable** for the activity profile.

## Core Calculations

### Max HR
\[
maxHR = 220 - age
\]

### Zone thresholds (percent of maxHR)
- **Light**: 60% to 69% (inclusive)
- **Moderate**: 70% to 79% (inclusive)
- **Vigorous**: 80%+ (inclusive)

Compute:
- \(lightLow = ceil(0.60 * maxHR)\)
- \(lightHigh = floor(0.69 * maxHR)\)
- \(modLow = ceil(0.70 * maxHR)\)
- \(modHigh = floor(0.79 * maxHR)\)
- \(vigLow = ceil(0.80 * maxHR)\)

Classify `avgHR`:
- if `avgHR < lightLow` → **Below qualifying threshold** → 0 points (HR-based)
- else if `avgHR <= lightHigh` → **Light**
- else if `avgHR <= modHigh` → **Moderate**
- else → **Vigorous**

### Minutes rounding
- Use **whole minutes** moving time:
  - `mins = floor(movingSeconds / 60)`
- No points until minimum minutes threshold met.

### Points rules (HR-based)

Use these as the canonical rules in the code. (They match the table you provided for Age 49.)

#### Under 65 (age < 65)

Light (60–69%):
- 30–59 min → 100
- 60–89 min → 200
- 90+ min → 300

Moderate (70–79%):
- 15–29 min → 100
- 30–59 min → 200
- 60+ min → 300

Vigorous (80%+):
- 15–29 min → 100
- 30+ min → 300

#### 65+ (age >= 65)

For members aged 65+, use the following HR-duration matrix (from the attached table):

Light (60–69% of max HR):
- 30–59 min → 100
- 60–89 min → 200
- 90+ min → 300

Moderate (70%+ of max HR):
- 15–29 min → 100
- 30+ min → 300

Vigorous:
- Same as Moderate for 65+ (30+ → 300).

Notes:
- The 65+ table uses “70% of max HR” (not a separate 70–79 / 80+ split).

### Endurance / High Performance Athlete tiers (optional)

The Endurance / High Performance category is **opt-in** (members must apply with Discovery).
Info: `https://www.discovery.co.za/vitality/endurance-high-performance-events`

When the **Endurance / High Performance Athlete** toggle is ON, the points ladder extends to:
- 0 / 100 / 200 / 300 / 450 / 600

Important:
- The screenshot note says these points are “in addition to the points in the tables above”, but for this data field we will implement them as **higher tiers**, not additive stacking, so the user always sees a single clear “predicted points” number.

Eligibility is based on **duration** and **intensity**:

At 60–69% of max HR:
- 90–119 min → 300
- 120–179 min → 450

At 60%+ of max HR:
- 180+ min → 600

At 70%+ of max HR:
- 90–119 min → 450
- 120+ min → 600

Implementation notes:
- If Endurance toggle is OFF, cap at 300 via the base table.
- If Endurance toggle is ON, compute points using the extended tier table above.

### Points rules (steps-based fallback)

Only used if **no HR average** can be read.

Under 65:
- 5,000–9,999 steps → 50
- 10,000+ steps → 100

Age 65+:
- 5,000–7,499 steps → 50
- 7,500+ steps → 100

If steps aren’t available, display `--` for fallback points (don’t guess).

### Points rules (speed-based fallback)

Used only if HR is unavailable and the activity profile supports it.

- 30+ minutes speed workout → 100 points
  - “speed” definition from your table: ~11 min/km or 10 km/h (implementation must confirm the exact metric source available in CIQ; if not measurable reliably, omit).

### “Only highest daily activity counts”

We can’t reliably enforce “highest daily counts” in a single activity data field.
Display note in docs/UI: **“Discovery counts only the highest activity per day.”**

## UI / Layout Requirements

Target devices:
- Start with Edge 840/850/1040/1050/540/550/MTB (similar to PowerRoller) for v1.
- Stretch goal: broaden compatibility to popular watches (e.g., Forerunner and Fēnix families) once layout is confirmed.

Minimal but useful layout (default):
- Center large: **Predicted Points**
  - Endurance OFF: 0 / 100 / 200 / 300
  - Endurance ON: 0 / 100 / 200 / 300 / 450 / 600
- Smaller:
  - `Mins: <mm>`
  - Guidance lines (both shown by default):
    - Time path:
      - If guidance mode = Next tier:
        - `Next: <tier> in <N>m @ current intensity`
      - If guidance mode = Target:
        - `Target <P>: <N>m left @ current intensity`
    - HR path:
      - `HR ≥ <bpm>` and, if below, `(-<delta>bpm)` to indicate how far under the required HR the user is.
  - “Stability” hint when close to dropping a tier:
    - `Borderline: +<bpm>` if just above the threshold
    - `Below tier by <bpm>` if already under.

Optional (configurable UI elements):
- `AvgHR: <bpm>` (or `AvgHR: --`)
- `Zone: Light/Mod/Vig/Below/NoHR` (can be noisy)
 - Ability to hide the HR path line if the user prefers time-only guidance.

Color suggestion:
- Color the **points text**, not the background (background should follow the device’s dark/light theme).
- Map colors based on **points achieved**:
  - 0 → muted/gray
  - 50 → light amber
  - 100 → amber
  - 200 → orange
  - 300 → green
  - 450 (endurance) → teal / bright green
  - 600 (endurance) → cyan / brightest highlight

### Next-tier UX detail (important)

Because the tier is a matrix of time × intensity, show **two actionable paths**:
- **Time path**: “If you keep this intensity, you need X more minutes.”
- **Intensity path**: “If you keep this duration, you need avg HR ≥ Y bpm (−Δ if below).”

Rules for intensity path:
- Only show if current points < max and the next tier/target is reachable by crossing into the next HR band **without decreasing duration thresholds**.
- For 65+ (70%+ model), the intensity path typically becomes: “avg HR ≥ modLow”.

How to compute **Y bpm (min required avg HR)**:
- Determine the **next points tier or configured target** according to the ruleset (e.g., 0→100, 100→200, 200→300, 300→450, 450→600).
- For that tier/target, compute the **minimum qualifying HR threshold** for the tier at the current minutes:
  - Under-65:
    - To reach any Moderate tier: `avgHR ≥ modLow`.
    - To reach Vigorous 300@30+: `avgHR ≥ vigLow`.
    - For Light tiers: `avgHR ≥ lightLow` (only meaningful if current is below light).
  - 65+:
    - To reach 70%+ tiers: `avgHR ≥ modLow` (where `modLow = ceil(0.70 * maxHR)`).
- Let `delta = Y - avgHR`. If `delta > 0`, display it as `(-delta bpm)`; if `delta <= 0`, omit the delta.

### “Close to dropping tier” indicator

Goal: warn the user when they are close to losing the current tier due to avg HR drifting down.

Definition and behavior:
- Determine the **current tier’s minimum HR threshold** (e.g., `lightLow`, `modLow`, `vigLow`, or the 70%+ threshold for 65+).
- Compute `marginBpm = avgHR - tierMinThreshold`.
- Use a warning threshold (default 5 bpm, may be made configurable later).
  - If `marginBpm >= 0` and `marginBpm <= 5` → show `Borderline: +<marginBpm>bpm`.
  - If `marginBpm < 0` → show `Below tier by <abs(marginBpm)>bpm`.
  - Otherwise → show no stability hint (avoid noise).

## Implementation Plan (repo specifics)

Repo: `C:\Users\SheldonBole\Projects\Discovery Vitality Points`

Key files:
- `source/DiscoveryVitalityPointsView.mc`: main compute + draw
- `source/DiscoveryVitalityPointsApp.mc`: boilerplate
- `manifest.xml`: already set
- `build.ps1`: must be used for SDK 9.1.0 builds; **do not change PowerRoller**

### Code structure
- Add a small pure-logic helper class (new file) e.g. `source/VitalityPointsCalculator.mc`:
  - input: `{ age, avgHr, minutes, steps? }`
  - output: `{ points, zone, nextTierMinutes? }`
- `View.compute(info)` extracts runtime signals, calls calculator, caches values for draw.

### SDK/tooling constraints
- Compile with SDK 9.1.0 via `.\build.ps1`
- Sign using `developer_key.der` already present in project root.

## Test Plan (as extensive as possible)

### A. Unit-style test matrix (calculator)
Implement a dev-only test runner function or simple “table-driven tests” inside a test file callable manually (Connect IQ doesn’t have a full unit test framework; keep it simple).

Use Age 49 example:
- \(maxHR = 220 - 49 = 171\)
- lightLow = ceil(0.60*171)=103
- lightHigh = floor(0.69*171)=117
- modLow = ceil(0.70*171)=120
- modHigh = floor(0.79*171)=135
- vigLow = ceil(0.80*171)=137

Test cases (avgHR, mins → expected):

Below threshold:
- 102 bpm, 120 min → 0 (Below)

Light:
- 103 bpm, 29 min → 0
- 103 bpm, 30 min → 100
- 110 bpm, 59 min → 100
- 117 bpm, 60 min → 200
- 117 bpm, 89 min → 200
- 117 bpm, 90 min → 300

Moderate:
- 120 bpm, 14 min → 0
- 120 bpm, 15 min → 100
- 135 bpm, 29 min → 100
- 120 bpm, 30 min → 200
- 135 bpm, 59 min → 200
- 120 bpm, 60 min → 300
- 135 bpm, 60 min → 300

Vigorous:
- 137 bpm, 14 min → 0
- 137 bpm, 15 min → 100
- 170 bpm, 29 min → 100
- 137 bpm, 30 min → 300

Steps fallback:
- steps 4999 → 0
- steps 5000 → 50
- steps 9999 → 50
- steps 10000 → 100

65+ steps fallback:
- steps 5000 → 50
- steps 7499 → 50
- steps 7500 → 100

65+ HR matrix:
- 70%+ threshold @ 15 min → 100
- 70%+ threshold @ 30 min → 300

Endurance/High Performance tiers (only if enabled):
- 90–119 min at 60–69% → 300
- 120–179 min at 60–69% → 450
- 180+ min at 60%+ → 600
- 90–119 min at 70%+ → 450
- 120+ min at 70%+ → 600

### B. Runtime tests (simulator)
- Build:
  - `.\build.ps1 -Device edge840 -KeyPath .\developer_key.der`
- Launch in simulator and confirm:
  - renders without crash
  - values update over time
  - handles missing HR (NoHR path)

### C. On-device sanity tests (manual)
- Outdoor ride with HR strap:
  - verify predicted points transition at minute thresholds (15/30/60/90)
  - verify zones align with HR averages in Garmin summary
- Ride without HR:
  - steps fallback shown if available, else `--`

### D. Regression tests (non-breaking)
- Ensure `PowerRoller` still builds with SDK 8.4.1 (do not change it).

## Claude Handoff Prompt (copy/paste)

You are Claude Code running locally via Ollama (`qwen2.5-coder:14b`).

Task: implement the “Discovery Vitality Points” Garmin Connect IQ data field in this repo.

Constraints:
- Do **not** modify the `PowerRoller` project.
- This project uses SDK 9.1.0 via `build.ps1`. Use that to compile.
- Keep changes small and compile frequently.

Implementation requirements:
- Create `source/VitalityPointsCalculator.mc` with a pure function/class implementing the rules in `docs/spec.md`.
- Update `source/DiscoveryVitalityPointsView.mc` to:
  - read avg HR and **duration** minutes from `Activity.Info` robustly (prefer moving/active time; fall back to elapsed)
  - compute `points`, optional `zone`, and guidance (time remaining + HR requirement, including deltas)
  - add a settings/config screen to capture:
    - Age source (profile vs manual DoB/Age)
    - Endurance/High Performance toggle (default OFF, with explanatory note/link)
    - Guidance mode (Next tier vs Target points) and target value
    - show/hide zone label toggle
  - render a clean layout:
    - big points number in tier color
    - smaller lines for minutes, guidance, and optional stability hint (“Borderline/Below tier”)
    - optional HR/zone line.
- Add a lightweight internal test harness (table-driven) for the calculator and document how to run/verify it.

Definition of done:
- `.\build.ps1 -Device edge840 -KeyPath .\developer_key.der` succeeds with no errors.
- Data field renders correctly in simulator and shows sensible output when HR is missing.

## Confirmed decisions
- 65+: Vigorous is the same as Moderate (30+ → 300).
- Daily “highest activity counts” note: docs only.
- Endurance/High Performance rules: implemented as extended tiers (0/100/200/300/450/600) behind a settings toggle (default OFF).

