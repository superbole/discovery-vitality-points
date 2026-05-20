# Agent notes (Discovery Vitality Points)

## Build
```
.\build.ps1 -Device <device> -KeyPath .\developer_key.der
```
Supported devices: `edge840`, `edge530`, `fr745`, `fenix5xplus`  
SDK: Connect IQ 9.1.0 — **do not upgrade without explicit instruction.**  
Requires `developer_key.der` in the project root.

## Key source files
| File | Purpose |
|------|---------|
| `source/DiscoveryVitalityPointsView.mc` | All layout drawing — **the only file touched for UI work** |
| `source/VitalityPointsCalculator.mc` | Points / guidance maths (stable) |
| `source/VitalityTests.mc` | Internal test harness |
| `manifest.xml` | Device targets and app metadata |
| `monkey.jungle` | Build configuration |

## Layout system overview
`dc.getWidth()` × `dc.getHeight()` is the **slot size** assigned by the activity layout,
not the physical screen. The layout tier is chosen inside `onUpdate` based on those slot
dimensions and the `mIsRound` flag.

### Tier selection (in order, first match wins)
| Tier | Code path | Trigger condition |
|------|-----------|------------------|
| CHART-RECT | `drawLargeChartLayout` | `!mIsRound && width >= 220 && height >= 150` |
| CHART-ROUND | `drawRoundChartLayout` | `mIsRound  && width >= 220 && height >= 150` |
| STANDARD | `drawStandardLayout` | `width >= 200 && height >= 100` |
| COMPACT | `drawCompactTileLayout` | `width >= 130` (after STANDARD fallthrough) |
| TILE | `drawCompactTileLayout` | `width < 130` |

### Which slots hit which tier (key devices)
| Device | Layout slot | Slot px | Tier |
|--------|-------------|---------|------|
| Edge 840 | 1-Field | 246×322 | CHART-RECT |
| Edge 840 | 2-Fields | 246×160 | CHART-RECT |
| Edge 840 | 3-Fields A | 246×106 | STANDARD |
| Edge 840 | 3-Fields B (mid) | 246×129 | STANDARD |
| Edge 840 | 4-Fields A | 246×79 | COMPACT |
| Edge 840 | strips 246×62 | 246×62 | COMPACT |
| Edge 530 | 2-Fields | 200×132 | STANDARD (w=200≥200, h=132≥100, but !CHART because h<150) |
| FR745 | 1-Field | 240×240 | CHART-ROUND |
| FR745 | 2-Fields | 240×119 | STANDARD |
| FR745 | 3-Fields A (centre) | 240×86 | STANDARD |
| FR745 | 3-Fields A (top/bot) | 240×68 | COMPACT |
| Fenix 5X+ | same as FR745 | — | same tiers |

## Current implementation status

### CHART-RECT (`drawLargeChartLayout`) — **updated layout**
4-row × 5-column matrix; trend + dashed crosshairs; centred points (no "pts" label).  
**Top:** red heart + large HR (left), **A** + large avg HR (right), symmetric `8px` padding.  
**Second row:** pipe guidance `12m | 8bpm` (large font on tall slots; scales down on 2-field).  
**Below:** matrix + x-axis labels. Validation Mode adds debug line + tier tag bottom-right (**off for clean screenshots**).

### CHART-ROUND (`drawRoundChartLayout`) — **aligned with CHART-RECT header**
Same header + above-matrix guidance rules as CHART-RECT; matrix inset for round safe area.

### STANDARD (`drawStandardLayout`) — **updated**
Single **top row**: heart + HR · centred pipe guidance · **A** + avg; matrix below (zoomed 3-row + next column). Bottom guidance row removed.

### COMPACT / TILE (`drawCompactTileLayout`) — **updated**
Two metrics (Garmin Connect: **Compact main** / **Compact secondary**): HR, Avg, or Points each side. **Points-tier colour** on both value strings. Bottom pipe guidance (same font ladder as CHART). TILE: smaller right font.

## Design reference
- `docs/design-spec.md` — authoritative per-tier design intent (do not modify without review)
- `docs/DEVICE_LAYOUT_REFERENCE.md` — device screen specs and slot pixel tables
- `docs/device-specs.md` — additional device info

## FR stack depth constraint
FR745 has ~8 KB stack. All expensive precomputation (`mChartMaxMinutes`, `mMinuteBounds`,
`mCellPointsCache`, `mChartWindowStart`) runs at `compute()` depth 1.  
Draw functions must stay at depth ≤ 4. No dynamic allocation inside draw paths.

## Simulator automation notes (for screenshot tooling)
- WM_COMMAND 5003 = File > Save Screen Capture
- WM_COMMAND 6007–6021 = Layout slots (6007=1-Field, 6008=2-Fields, 6009=3-Fields A, ...)
- WM_COMMAND 6170 = Simulation > Activity Data panel toggle
- Activity Data panel is a separate top-level window (not a child of the simulator window)
- Start button handle must be found via `EnumChildWindows` on the panel window handle
- `BM_CLICK` and `SendMessage(WM_LBUTTONDOWN)` have not reliably started the timer;
  physical `mouse_event` at the Start button's reported screen rect centre also hasn't worked.
  Manual click on the Start button in the Activity Data panel is the reliable fallback.
