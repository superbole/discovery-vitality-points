# Implementation prompt — Discovery Vitality Points layout overhaul

Paste this entire file as your first message in a fresh chat.

---

## Project

Garmin Connect IQ data field written in Monkey C.
Project root: `C:\Users\SheldonBole\Projects\Discovery Vitality Points\`
SDK: `connectiq-sdk-win-9.1.0` (do not upgrade).
Build: `.\build.ps1 -Device edge840 -KeyPath .\developer_key.der`

Read these files before making any changes:
- `source/DiscoveryVitalityPointsView.mc` — main view (this is what you are changing)
- `source/VitalityPointsCalculator.mc` — points/guidance logic (read-only reference)
- `docs/design-spec.md` — authoritative design spec
- `docs/device-specs.md` — slot dimensions and tier assignments per device
- agents.md
- clauade.md

---

## What has already been done (do not redo)

1. `mIsRound` is detected in `initialize()` via `System.getDeviceSettings().screenShape` and stored as a member variable.
2. The chart header (`drawChartHeader`) has been fixed for round displays — guidance and header text are centred when `mIsRound` is true.
3. `edge530` has been added to `manifest.xml`.
4. Several member variables have been added: `mChartMaxMinutes`, `mMinuteBounds`, `mCellPointsCache`, `mChartWindowStart`, `mHrAxisLabels`, `mCrosshairColorIndex`, tier colour indices, precomputed HR threshold values (`mMaxHr`, `mVigLow`, `mModLow`, `mLightLow`).
5. `compute()` precomputes chart state at depth 1 (to stay within the FR745 ~8 KB stack limit at draw depth 4+). Do not move any `Math.ceil`, `getChartMaxMinutes`, `getMinuteBounds`, or `getChartTierPoints` calls into draw functions deeper than depth 2.

---

## What needs to be implemented

### 1. Layout tier routing in `onUpdate`

Replace the single `shouldUseChartLayout` branch with a 5-tier router.
Keep the existing `drawLargeChartLayout` function as the **CHART-RECT** path.
Detect shape using the already-stored `mIsRound`.

**Target thresholds (from design-spec.md):**

```
CHART-RECT   = !mIsRound && width >= 220 && height >= 150
CHART-ROUND  =  mIsRound && width >= 200 && height >= 150   ← note: 200 not 220
STANDARD     = width >= 200 && height >= 100  (and not chart)
COMPACT      = width >= 130                   (and not chart, not standard)
TILE         = width < 130
```

> CHART-ROUND uses `w>=200` (not 220) because common round devices like Fenix 3/5S,
> FR55, and FR255S have full-screen slots of only 208–218 px wide. With w>=220 their
> full-screen slot falls into STANDARD instead of the full matrix chart.

COMPACT and TILE share one code path — width determines guidance verbosity,
height gates the HR header row.

### 2. CHART-ROUND — new function `drawRoundChartLayout`

Same structure as the existing `drawLargeChartLayout` (CHART-RECT) but:
- Header (HR now and Avg HR) centred, no left/right corner text.
- Chart matrix left/right inset: `chartLeft = getChartLeft() + 14`,
  `chartRight = getChartRight(width) - 14` (to stay within the inscribed circle).
- Y-axis labels inset from left edge to match the wider `chartLeft`.
- X-axis labels centred per column rather than edge-aligned.
- Guidance centred, anchored just below `chartBottom` (not at `height - 6`).
- Safe-y for header: use y ≈ 20 and y ≈ 40 (not y=8 which is in the clipped corner).

The chart itself (cells, grid, trend line, crosshairs) reuses the same helper
functions as CHART-RECT — just pass the adjusted `cL`/`cR` values.

### 3. STANDARD layout — new function `drawStandardLayout`

This is the most significant new work. Read `docs/design-spec.md § STANDARD` carefully.

**Concept:** zoomed 3-row × 2-column matrix centred on the current position.

**Layout budget** (header 20px · gaps 3px×2 · pad 4px×2 · guidance 18px):

| Slot | Matrix height | Centre row | Partial row |
|------|-------------|-----------|------------|
| 246×106 | 54px | 32px | 11px |
| 240×119 | 67px | 40px | 13px |
| 246×126 | 74px | 44px | 15px |
| 246×129 | 77px | 46px | 15px |

Row heights: `centreH = matrixH * 3 / 5`, `partialH = matrixH / 5`.

**Column widths:** current column fills `matrixW * 3 / 4`, next column fills
`matrixW / 4` (right side). `matrixW` = width minus y-axis label area (~30px left).

**Elements to draw:**
1. Header row (top): HR now (left or centre) and Avg HR (right or centre).
   On round displays centre both; on rect left/right align.
2. Zoomed matrix: 3 rows (partial above · current · partial below) ×
   2 columns (current · next). Fill each cell with tier colour from
   `mCellPointsCache`. Partial cells use a faded/lighter version of the colour
   (blend toward background — a simple approach: use the colour at ~50% opacity by
   drawing a filled rect then a semi-transparent background-coloured rect on top,
   or just use a lighter hardcoded shade per tier).
3. Current points number centred in the current cell. Use `FONT_NUMBER_MEDIUM`
   if centre row >= 32px. No "pts" suffix.
4. Trend line overlay clipped to the matrix bounds (reuse `drawTrendLine` logic
   but map HR to the zoomed y range, and map minutes to the zoomed x range for
   the current column only).
5. Crosshairs: horizontal line at avg-HR y, vertical line at current-minute x,
   within the current column only.
6. Y-axis labels (left of matrix): for the current row show name or bpm value
   (per `mHrAxisLabels` setting); for partial rows above/below show name only
   if `partialH >= 11`.
7. X-axis: show current column right boundary (minutes) and "+" after last column.
8. Guidance line at bottom (see guidance format below).

**Round display:** apply x-inset of `max(8, roundInsetForY(y))` at both the top
~30px and bottom ~30px of the slot. Centre all text (header and guidance).
The `roundInsetForY` for a half-height slot (h≈119, positioned at either top or
bottom of the 240×240 circle):
- Near the slot's top/bottom edge (y=0 or y=h): inset ≈ 24px
- Near the slot's mid-height: inset ≈ 0px
Use a simple linear approximation: `inset = max(0, 24 - (distFromEdge * 24 / 30))`
where `distFromEdge = min(y, h - y)`.

### 4. COMPACT / TILE — update existing compact path

Replace the existing compact/standard branch (`var isCompact = (width < 220 || height < 150)`) with the new COMPACT/TILE code path.

```
Show HR header row:   height >= 80
Primary number font:  FONT_NUMBER_THAI_HOT if height >= 80, else FONT_NUMBER_MEDIUM
Guidance verbosity:   width >= 200 → full · width >= 130 → medium · width < 130 → narrow
```

### 5. Guidance format — update everywhere

**Old format (remove):** `"To 200: 12m @ avg>=140 (+8bpm)"`

**New format:** time-remaining and HR-delta only. The delta is
`hrNeeded - mAvgHR` (positive = need to push harder; omit if ≤ 0, i.e. HR already met).

```
Both needed:  wide "12m   8bpm"  ·  medium "12m  8bpm"  ·  narrow "12/8"
Time only:    "12m"
HR only:      wide/medium "8bpm"  ·  narrow "8"
Nothing:      hide guidance row
```

The "wide/medium/narrow" sizing uses the COMPACT/TILE width bands above.
For CHART and STANDARD (always wide slots), always use the full format.

Update every function that builds guidance text:
- `buildChartGuidanceText()` in the chart path
- The inline guidance builder in `onUpdate` (the `compactGuidanceText` /
  `guidanceLine2` block)
- Any other place that references `"avg>="`, `"(+"`, or `"To "`.

---

## Constraints and gotchas

- **Stack depth:** The FR745 has ~8 KB call stack. Draw helper functions are at
  depth 3 (onUpdate → drawXLayout → helper). Do not call `Math.ceil`,
  `getMinuteBounds`, or `getChartTierPoints` from depth 4+. Use the precomputed
  `mMinuteBounds`, `mCellPointsCache`, `mVigLow`, `mModLow`, `mLightLow` member
  variables instead.
- **Font sizes:** Values the rider acts on (points, HR, time, bpm delta) must be
  at minimum `FONT_SMALL`. Axis labels may use `FONT_TINY`. Never use `FONT_XTINY`
  for actionable values.
- **No new properties yet:** Do not add new `Properties.getValue()` calls in this
  pass. The new settings (crosshair colour, trend thickness, etc.) are already
  partially wired — leave untouched settings as-is.
- **Build after each function:** compile with `.\build.ps1 -Device edge840` after
  adding each new function. Also compile for `fr745` and `fenix5xplus` before
  finishing to catch round-display issues.
- **Do not change** `VitalityPointsCalculator.mc`, `VitalityOnDeviceSettings.mc`,
  `manifest.xml`, `monkey.jungle`, or any resource XML files.
- **Backup exists** at `source_backup_20260506_161710/` if you need to compare.

---

## Acceptance checklist

- [ ] `onUpdate` routes to 5 distinct paths (CHART-RECT, CHART-ROUND, STANDARD, COMPACT, TILE)
- [ ] CHART-RECT: unchanged behaviour, compiles for edge840
- [ ] CHART-ROUND: header centred, matrix inset 14px, compiles for fr745/fenix5xplus
- [ ] STANDARD: zoomed 3-row matrix visible, points centred in cell, guidance at bottom
- [ ] COMPACT: large number + guidance; HR header shown when h >= 80
- [ ] TILE: same as COMPACT, guidance abbreviated
- [ ] Guidance text nowhere contains "To ", "avg>=", or "(+"
- [ ] Builds clean (no errors) for: edge840, edge530, fr745, fenix5xplus
