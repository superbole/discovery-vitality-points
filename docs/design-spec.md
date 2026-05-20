# Discovery Vitality Points — Design Specification

Authoritative reference for the five layout designs.
**Do not change these without conscious review and updating this file.**

---

## Design Tier Overview

| # | Name | Trigger | Key slots |
|---|------|---------|-----------|
| 1 | CHART-RECT  | `rect && w>=220 && h>=150` | Edge 840/530: 1-Field (246×322), 2-Fields (246×160) |
| 2 | CHART-ROUND | `round && w>=220 && h>=150` | FR745 1-Field (240×240), Fenix 5X+ 1-Field (240×240) |
| 3 | STANDARD    | `w>=200 && h>=100`          | Edge 840/530: 3-Fields B (246×126-129), 3-Fields A (246×106) · FR745/Fenix: 2-Fields (240×119) |
| 4 | COMPACT     | `w>=130 && h>=50` (and not STANDARD) | Edge 840/530: 4-Fields A (246×79), strips (246×62) · FR745/Fenix: 3-Fields strips (240×68-86) |
| 5 | TILE        | `w<130`                     | Edge 840/530: half-wide (122×62) · FR745: half-wide (119×67) · Fenix: quarter tiles (119×119) |

> COMPACT and TILE share one code path. Width drives guidance verbosity;
> height drives whether an HR header row is shown.
> See COMPACT / TILE section below.

---

## CHART-RECT

**Slots:** Edge 840/530 1-Field (246×322), 2-Fields (246×160)
**Shape:** rectangle — left/right edges are safe at all y positions.

### Layout (top → bottom)

```
┌─────────────────────────────────────┐
│ ♥ 162          12m | 8bpm      A 157│  ← HR row + pipe guidance + avg (large digits; ♥ = red heart)
├──────────────────────────────────────┤
│ y─┬──────────────────────────────── │
│ V │  (col 0─14) │ (15─29) │ (30─59) │  chart matrix (moved down; graphic = matrix + trace + crosshairs)
│ M │             │         │         │
│ L │      200    │         │         │  ← crosshair + current pts centred in cell (no "pts" label)
│ E │             │         │         │
│   └───┬─────────┴─────────┴──────── │
│      15         30        60        │  ← x-axis time labels
└─────────────────────────────────────┘
```

### Elements

| Element | Detail |
|---------|--------|
| **Header** | Red vector heart + current HR digits (left) and **A** + average HR digits (right). Same number font size as centred points value (`FONT_NUMBER_HOT` on rect CHART slots). Symmetric horizontal padding from slot edges (`8px`). No "HR" / "Avg" word labels. |
| **Guidance** | Full-width centred **below** the HR header row and **above** the matrix. Pipe format `12m \| 8bpm` (same font ladder as points on tall slots; scales down on short CHART slots). |
| **Chart matrix** | 4 rows (Vig / Mod / Light / Easy) × 5 columns (0–14 / 15–29 / 30–59 / 60–89 / 90+). Columns extend to endurance thresholds when endurance mode is on. Cells filled with tier colour. **Y-axis labels default to colour-only (none mode)** — the colour bands are sufficient at small row heights. Labels are an opt-in setting. |
| **Current points** | Number centred in the current cell (intersection of current zone row and current time column). No "pts" suffix or sub-label. Selectable: text colour options — foreground, background colour, or same as current points colour. Optional halo for legibility on coloured cells. |
| **Trend line** | Overlaid on matrix. Selectable colour and thickness. |
| **Crosshairs** | Horizontal + vertical lines through current cell centre. Same colour and thickness as trend line. |
| **Crosshair data labels** | Optional: show current time (x-axis) and/or current avg HR (y-axis) next to crosshair intersection. |
| **Y-axis labels** | Selectable mode: name / value / both / **none (default)**. Names (Vig/Mod/Light/Easy) centred to their row. Values (bpm thresholds from age-based calculation) aligned to zone boundaries. Default none is recommended for the 2-Fields slot (19px rows) where colours carry the information. |
| **X-axis labels** | Time thresholds in minutes, aligned to column boundaries. Label the right edge of each column: 15 / 30 / 60 / 90 / 90+ (or endurance steps). |

### Height budget (reference)

| Slot | Matrix height | Row height | Y-axis label default |
|------|-------------|-----------|---------------------|
| 246×322 | ~236 px | ~59 px — very readable | name or value |
| 246×160 | ~76 px  | ~19 px — colour sufficient | **none** |

---

## CHART-ROUND

**Slots:** FR745 1-Field (240×240), Fenix 5X+ 1-Field (240×240)
**Shape:** round — inscribed circle r=120, centre (120,120). Corners are invisible.

### Safe drawing zones

| Y in field | Safe X range | Typical content at that Y |
|-----------|-------------|--------------------------|
| 0–20      | 77–163      | HR row (heart + digits) |
| 20–40     | 73–167      | Pipe guidance row (when shown) |
| 40–80     | 28–212      | Top partial matrix row |
| 80–160    | 0–240       | Full-width chart centre |
| 160–200   | 16–224      | Lower chart / bottom partial |
| 200–220   | 73–167      | Guidance (centred only) |
| 220–240   | 77–163      | Guidance (centred only) |

### Layout

```
         ╭──────────────────────────╮
        / ♥162   12m|8bpm    A157     \     ← same header rules as CHART-RECT (heart + A label)
       │ y┬───────────────────────── │
       │ V│                    ┊░░░░ │
       │ M│         200        ┊░░░░ │
       │ L│   ════╪═════╌╌╌╌╌ ┊░░░░ │
       │ E│                    ┊░░░░ │
       │  └────────────────────┴──── │
        \    (x-axis labels)         /
         ╰──────────────────────────╯
```

> Guidance sits **above** the inscribed matrix (not in the bottom bezel band).
> Full 4-row matrix (not zoomed STANDARD); inset ~14px left/right for the circle.

### Elements

| Element | Detail |
|---------|--------|
| **Header** | Same as CHART-RECT: red heart + HR (left), **A** + avg (right), large number fonts, symmetric edge padding. |
| **Current points** | Centred in the current cell. Same options as CHART-RECT. |
| **Chart matrix** | 4 rows × 5 columns. Left inset: ~14px (safe x margin at chart mid-height). Right inset: ~14px. Y-axis labels inset accordingly. |
| **Trend line** | Same as CHART-RECT. |
| **Crosshairs** | Same as CHART-RECT. |
| **Crosshair data labels** | Optional. Must stay within safe-x bounds at their y position. |
| **Y-axis labels** | Same modes as CHART-RECT. Inset from left edge to stay within circle at chart row y positions. |
| **X-axis labels** | As CHART-RECT. Centred per column (not edge-aligned) to avoid corner clipping at bottom of display. |
| **Guidance** | Pipe format, centred above matrix (same font ladder as CHART-RECT). |

---

## STANDARD

**Slots:** Edge 840/530 3-Fields B (246×126-129), 3-Fields A (246×106) · FR745/Fenix 2-Fields (240×119)
**Shape:** rectangle or round — apply `isRound` inset at top and bottom ~30px of slot.

### Concept: zoomed matrix

Shows only the neighbourhood around the current position — not the full overview.
Inspired by the image reference: the current zone row is full height; the row above
and row below are shown as ~1/3-height bands for context; the next time column is
shown as a ~1/3-width band on the right.

```
┌─────────────────────────────────────┐
│ ♥162   12m | 8bpm            A 157  │  ← single top row: heart+HR, pipe guidance, A+avg
├──────────────────────────────────────┤
│y──┬────────────────────────┬───░░░ │  ← row above (1/3 h), faded
│   │                        │   ░░░ │
│   ├────────────────────────┼───░░░ │  ── zone boundary
│   │                        │       │
│   │       [ 200 ]    ═════╪═══ ░░░│  ← current zone row + crosshairs
│   │                        │       │
│   ├────────────────────────┼───░░░ │
│y──┴────────────────────────┴───░░░ │
└─────────────────────────────────────┘
```

### Height budget (1/3 partial rows = 5/3 total matrix units)

| Slot | Total matrix px | Centre row px | Partial row px |
|------|----------------|--------------|---------------|
| 246×106 (3-Fields A) | 54 | 32 | 11 |
| 240×119 (FR745/Fenix 2F) | 67 | 40 | 13 |
| 246×126 (3-Fields B mid) | 74 | 44 | 15 |
| 246×129 (3-Fields B bot) | 77 | 46 | 15 |

*Top band height is driven by the large number fonts + pipe guidance; matrix begins below it.*

### Elements

| Element | Detail |
|---------|--------|
| **Header** | One row: red heart + current HR (left), centred pipe guidance (`12m \| 8bpm`), **A** + average HR (right). No separate bottom guidance row. |
| **Zoomed matrix** | 3 visible zone rows: partial above (1/3h) · current (full h) · partial below (1/3h). 2 visible time columns: current (full w) · next (1/3w, right side). Cells coloured by tier. Partial cells use full tier colour (same as implementation). |
| **Current points** | Centred in the current cell. No "pts" suffix. Same colour/halo options as CHART-RECT. |
| **Trend line** | Same options as CHART-RECT. Clipped to visible matrix area. |
| **Crosshairs** | Same colour/thickness as trend line, centred on current position. |
| **Crosshair data labels** | Optional: time and/or avg HR. |
| **Y-axis labels** | name / value / both / none. For current row: show both if space; for partial rows above/below: show name only if row height ≥ 11px. Values for current zone boundaries only. |
| **X-axis labels** | Current column boundary and next column boundary, aligned to column edges. |
| **Guidance** | Pipe format; same font ladder as CHART-RECT guidance. |

### Round display note

Apply round-safe x-inset at the top and bottom ~30px of the slot. Since top-vs-bottom
slot position cannot be detected at runtime, apply the inset at **both** extremes.
Centre all text in the header row. Guidance must also be centred.

---

## COMPACT / TILE (single design)

**COMPACT slots:** Edge 840/530 4-Fields A (246×79), strips 246×62 · FR745/Fenix 3-Fields strips (240×68–86)
**TILE slots:** Edge 840/530 half-wide (122×62) · FR745 half-wide (119×67) · Fenix quarter tiles (119×119)

The designs share one code path. **CompactMainMetric** / **CompactSecondaryMetric** (Garmin Connect) choose left and right: current HR, average HR, or points. Values use **points-tier colour**. Guidance uses the pipe format and the same font ladder as CHART.

```
┌───────────────────────────────────┐
│ 162                    157        │  ← two metrics (example: HR + Avg)
│        12m | 8bpm                 │  ← guidance
└───────────────────────────────────┘
```

### Width-based guidance verbosity

| Width | Guidance text shown |
|-------|-------------------|
| w ≥ 100 | Full pipe: `12m \| 8bpm` |
| w < 100 | Narrow: `12/8` |

### Elements

| Element | Detail |
|---------|--------|
| **Metrics row** | Two user-selected values (HR / Avg / Points). **TILE**: left uses larger number font, right slightly smaller. **COMPACT**: both use large number fonts. Text colour = points-tier ramp (same as matrix points colour). |
| **Guidance** | Bottom-centred pipe line; font from `pickChartGuidanceFont(slotHeight)` (same ladder as CHART). |

### Round display note

On round displays, top- and bottom-edge slots have limited safe-x range (~28–32px
from each side at mid-height). Centre all text. Guidance especially must not be
left-aligned at x=8 on top/bottom-edge strips.

---

## Guidance format (all designs)

The rider needs two **changing** actionable numbers: **how much longer** (time remaining
to next tier) and **how much harder** (HR delta above current avg HR needed).

The absolute HR threshold barely changes during a ride and is inferrable from the header.
The target-points label is redundant when points are visible on screen.

### Format rules

```
Both constraints:   "12m | 8bpm"      ← 12 more minutes, need +8bpm above current avg
Time only (HR ok):  "12m"
HR only:            "8bpm"
Nothing needed:     (guidance row hidden or replaced by "Max tier" / "Target reached")
```

Width-based truncation (very narrow TILE slots):

| Available width | Format |
|----------------|--------|
| w ≥ 100 | `12m \| 8bpm` |
| w < 100 | `12/8` (minutes + HR delta; units implied) |

### What is NOT shown (deliberately)

| Omitted | Reason |
|---------|--------|
| "To 200:" target prefix | Redundant — points/colour already on screen |
| Absolute HR threshold ("avg>=140") | Barely changes; delta is more actionable |
| Current points value in guidance | Already shown as the large number or matrix cell |

---

## Future enhancements (parked)

These ideas are recorded so they are not lost, but are deferred until after real-world
testing with the current design.

### Multi-step time lookahead
Show the HR delta for the *next* time band as well as the current one.
Example: `12m  8bpm | then -5bpm` — meaning "12 more minutes needing +8bpm, but once
you reach the next time threshold the required HR drops (you'll be 5bpm over)".
Gives the rider a view of how the required effort changes over time, and is encouraging
when the next step becomes easier.

Concern: may be too much cognitive load on bumpy terrain. Evaluate after testing the
simplified single-step guidance first.

---

## Global settings that affect all designs

| Setting | Options | Notes |
|---------|---------|-------|
| Primary metric | Points / HR now / Avg HR | Garmin Connect setting; **not** used by current COMPACT/TILE (use Compact* metrics). CHART/STANDARD matrix still centres **points**. |
| Compact / tile: left value | HR / Avg / Points | COMPACT + TILE only (`CompactMainMetric`). |
| Compact / tile: right value | HR / Avg / Points | COMPACT + TILE only (`CompactSecondaryMetric`). |
| Points colour | Coloured by tier / white / custom | Same ramp used in all designs |
| Validation mode | On / Off | When on: avg-HR debug line on CHART + **layout tier tag** bottom-right. **Turn off for clean screenshots.** |
| Points text halo | On / Off | Legibility on coloured matrix cells |
| Trend line colour | Selectable | Used in CHART and STANDARD |
| Trend line thickness | 1 / 2 / 3 px | Used in CHART and STANDARD |
| Crosshair colour | Same as trend line | Used in CHART and STANDARD |
| Crosshair data labels | Time / HR / Both / None | Used in CHART and STANDARD |
| Y-axis mode | Name / Value / Both / None | Used in CHART and STANDARD |
| Zone label (header row) | Show / Hide | STANDARD only |
| Guidance mode | Next tier / Target points | All designs |
| Show HR in guidance | On / Off | All designs |
| Endurance mode | On / Off | Changes matrix columns and point tiers |

---

## Readable-on-the-go sizing targets

Based on field testing: values that change (points, HR, time) must be at minimum
**FONT_NUMBER_MEDIUM** for primary numbers and **FONT_SMALL** for secondary values.
**FONT_TINY** is acceptable only for axis labels and static decorative text.
Avoid FONT_XTINY for any value that the rider needs to act on.
