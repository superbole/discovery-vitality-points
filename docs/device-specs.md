# Device Specs & Data Field Layout Reference

Generated from SDK `connectiq-sdk-win-9.1.0` simulator.json files.
Used to tune layout thresholds in `DiscoveryVitalityPointsView.mc`.

---

## Quick Legend

| Symbol | Meaning |
|--------|---------|
| CHART-RECT  | Rectangle, `w>=220 && h>=150` — full 4-row matrix chart |
| CHART-ROUND | Round screen, `w>=220 && h>=150` — same chart, circle-safe positioning |
| STD    | `w>=200 && h>=100` — zoomed 3-row matrix + header + guidance |
| CMPCT  | `w>=130 && h<100` — large number + guidance line (header if h>=80) |
| TILE   | `w<130` — large number + abbreviated guidance; shares code with CMPCT |

See `design-spec.md` for full content definitions per design.

Round-display clipping note: on 240×240 round screens (FR745, Fenix 5X Plus) the
inscribed circle has radius 120 centred at (120,120). Any pixel at distance > 120 from
that centre is invisible. This clips the **corners of full-screen and top/bottom edge
slots**. Safe horizontal range per Y position (field-local coords, field at y=0):

| Field Y position | Safe X range  |
|-----------------|---------------|
| y = 0   (top)   | 77 .. 163     |
| y = 8           | 77 .. 163     |
| y = 28          | 73 .. 167     |
| y = 60          | 16 .. 224     |
| y = 119 (mid)   | 0  .. 240     |
| y = 180         | 16 .. 224     |
| y = 212         | 73 .. 167     |
| y = 232         | 77 .. 163     |

**Rule of thumb:** keep text centred (`x = width/2`) or horizontally inset by at
least `max(8, round_inset(y))` when `screenShape == SCREEN_SHAPE_ROUND`.

---

## Edge 840

**Screen:** 246 × 322 px, rectangle  
**Manifest ID:** `edge840`  
**Status:** ✅ already in manifest

| Layout       | Slot | W   | H   | x   | y   | Class  | Notes |
|-------------|------|-----|-----|-----|-----|--------|-------|
| 1 Field      | 1    | 246 | 322 | 0   | 0   | CHART-RECT | Full screen, full matrix |
| 2 Fields     | 1    | 246 | 160 | 0   | 0   | CHART-RECT | h=160 ≥ 150; rows ~19px — overview |
| 2 Fields     | 2    | 246 | 160 | 0   | 162 | CHART-RECT | |
| 3 Fields A   | 1    | 246 | 106 | 0   | 0   | STD    | zoomed matrix; centre row ~32px |
| 3 Fields A   | 2    | 246 | 106 | 0   | 108 | STD    | |
| 3 Fields A   | 3    | 246 | 106 | 0   | 216 | STD    | |
| 3 Fields B   | 1    | 246 |  63 | 0   | 0   | CMPCT  | number + guidance only |
| 3 Fields B   | 2    | 246 | 126 | 0   | 65  | STD    | centre row ~44px |
| 3 Fields B   | 3    | 246 | 129 | 0   | 193 | STD    | centre row ~46px |
| 4 Fields A   | 1-4  | 246 |  79 | 0   | var | CMPCT  | h=79 < 100; number + guidance |
| 4 Fields B   | 1-2  | 122 |  63 | var | 0   | TILE   | w=122; number + short guidance |
| 4 Fields B   | 3    | 246 | 126 | 0   | 65  | STD    | |
| 4 Fields B   | 4    | 246 | 129 | 0   | 193 | STD    | |
| 5–10 Fields  | full | 246 | 62-66 | var | var | CMPCT | Very thin; number + guidance |
| 5–10 Fields  | half | 122 | 62-66 | var | var | TILE  | number + short guidance |

**Smallest useful slot:** 3 Fields B slot 2 = 246×126 (STD class).  
**Recommended slot for this data field:** 1 Field, 2 Fields, or 3 Fields B slot 2.

---

## Edge 530

**Screen:** 246 × 322 px, rectangle  
**Manifest ID:** `edge530`  
**Status:** ❌ NOT in manifest — needs to be added  
**Notes:** Identical screen geometry to Edge 840.

| Layout       | Slot | W   | H   | x   | y   | Class  |
|-------------|------|-----|-----|-----|-----|--------|
| 1 Field      | 1    | 246 | 322 | 0   | 0   | CHART  |
| 2 Fields     | 1-2  | 246 | 160 | 0   | 0/162 | CHART |
| 3 Fields A   | 1-3  | 246 | 105-106 | 0 | var | CMPCT |
| 3 Fields B   | 1    | 246 |  63 | 0   | 0   | STRIP  |
| 3 Fields B   | 2    | 246 | 126 | 0   | 65  | STD    |
| 3 Fields B   | 3    | 246 | 127 | 0   | 193 | STD    |
| 4 Fields A   | 1-4  | 246 | 78-79 | 0 | var | STRIP |
| 4 Fields B   | 1-2  | 122 |  63 | var | 0   | HALF   |
| 4 Fields B   | 3    | 246 | 126 | 0   | 65  | STD    |
| 4 Fields B   | 4    | 246 | 127 | 0   | 193 | STD    |
| 5–10 Fields  | full | 246 | 62-63 | var | var | STRIP |
| 5–10 Fields  | half | 122 | 62-63 | var | var | HALF  |

---

## Forerunner 745 (fr745)

**Screen:** 240 × 240 px, **ROUND**  
**Manifest ID:** `fr745`  
**Status:** ✅ already in manifest  
**Clipping:** inscribed circle r=120 centred at (120,120). Corners of full-screen and
top/bottom-edge slots are invisible (corner dist ≈ 170 px > 120 px).

| Layout      | Slot | W   | H   | x   | y   | Class  | Corner dist | Safe X at mid-Y |
|------------|------|-----|-----|-----|-----|--------|------------|-----------------|
| 1 Field     | 1    | 240 | 240 | 0   | 0   | CHART-ROUND | 170 ⚠️ corners — use centred layout | 0..240 |
| 2 Fields    | 1    | 240 | 119 | 0   | 0   | STD  | TL/TR=170 ⚠️ top edge risk | 16..224 |
| 2 Fields    | 2    | 240 | 119 | 0   | 122 | STD  | BL/BR=170 ⚠️ bottom edge risk | 17..223 |
| 3 Fields A  | 1    | 240 |  76 | 0   | 0   | CMPCT | 170/128 ⚠️ top edge | 32..208 |
| 3 Fields A  | 2    | 240 |  84 | 0   | 78  | CMPCT | 127 ✅ centre safe | 0..240 |
| 3 Fields A  | 3    | 240 |  76 | 0   | 164 | CMPCT | 128/170 ⚠️ bottom edge | 32..208 |
| 3 Fields B  | 1    | 240 |  86 | 0   | 0   | CMPCT | 170/125 ⚠️ top edge | 28..212 |
| 3 Fields B  | 2    | 240 |  68 | 0   | 86  | CMPCT | 125 ✅ centre safe | 0..240 |
| 3 Fields B  | 3    | 240 |  86 | 0   | 153 | CMPCT | 124/169 ⚠️ bottom edge | 27..213 |
| 4 Fields A  | 1    | 240 |  85 | 0   | 0   | CMPCT | 170/125 ⚠️ top edge | 28..212 |
| 4 Fields A  | 2    | 119 |  67 | 0   | 87  | TILE  | 124/125 ✅ | 0..240 |
| 4 Fields A  | 3    | 119 |  67 | 121 | 87  | TILE  | 33/34 ✅ | 0..240 |
| 4 Fields A  | 4    | 240 |  85 | 0   | 156 | CMPCT | 125/170 ⚠️ bottom edge | 29..211 |

**Round-display rule:** text must be centred (or use safe-x inset) at ALL y positions
in the top and bottom ~30px of any slot, because we cannot tell at runtime whether this
slot is the top or bottom half of the screen. Apply the inset at both extremes.

**Chart header fix:** ✅ Done (per developer). Was: `(8,8)` and `(w-8,10)` — invisible
at corner distance ≈ 158. Now centred.

---

## Fenix 5X Plus

**Screen:** 240 × 240 px, **ROUND**  
**Manifest ID:** `fenix5xplus`  
**Status:** ✅ already in manifest  
**Clipping:** same circle geometry as FR745.

| Layout      | Slot | W   | H   | x   | y   | Class  | Corner dist |
|------------|------|-----|-----|-----|-----|--------|------------|
| 1 Field     | 1    | 240 | 240 | 0   | 0   | CHART-ROUND | 170 ⚠️ corners — centred layout |
| 2 Fields    | 1    | 240 | 119 | 0   | 0   | STD  | TL/TR=170 ⚠️ top edge |
| 2 Fields    | 2    | 240 | 119 | 0   | 121 | STD  | BL/BR=170 ⚠️ bottom edge |
| 3 Fields A  | 1    | 240 |  77 | 0   | 0   | CMPCT | 170/128 ⚠️ top edge |
| 3 Fields A  | 2    | 240 |  82 | 0   | 79  | CMPCT | 127 ✅ centre safe |
| 3 Fields A  | 3    | 240 |  77 | 0   | 163 | CMPCT | 128/170 ⚠️ bottom edge |
| 3 Fields B  | 1    | 240 | 119 | 0   | 0   | STD  | TL/TR=170 ⚠️ top edge |
| 3 Fields B  | 2    | 119 | 119 | 0   | 121 | TILE  | Near centre ✅ |
| 3 Fields B  | 3    | 119 | 119 | 121 | 121 | TILE  | Near centre ✅ |
| 4 Fields A  | 1    | 240 |  77 | 0   | 0   | CMPCT | 170/128 ⚠️ top edge |
| 4 Fields A  | 2-3  | 119 |  82 | 0/121 | 79 | TILE | Near centre ✅ |
| 4 Fields A  | 4    | 240 |  77 | 0   | 163 | CMPCT | 128/170 ⚠️ bottom edge |
| 4 Fields B  | 1-4  | 119 | 119 | var | var | TILE  | All near centre ✅ |

**Same round-display rules apply as FR745. Chart header fix: ✅ Done.**

---

## Garmin Lily 2 Active

**Status:** ❌ NOT FOUND in SDK 9.1.0 device list  
**Action required:** Confirm whether this device supports Connect IQ data fields.

The Lily 2 Active does not appear in either the installed SDK device list (163 devices
checked) or the device-reference docs bundled with SDK 9.1.0. The Lily series uses a
small OLED display (~195×195 px round) but the fashion variants may have restricted
Connect IQ support (no third-party data fields).

**Recommendation:** Check https://developer.garmin.com/connect-iq/compatible-devices/
and filter for "Lily" to confirm if data fields are supported. If the device ID is found
(likely `lily2active` or similar), add the SDK device definition and add the manifest
entry before deploying.

---

## Layout Class Boundaries (target — to be implemented)

```
isRound      = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND

CHART-RECT   = !isRound && width >= 220 && height >= 150
CHART-ROUND  =  isRound && width >= 200 && height >= 150   ← w>=200 (not 220) — covers 218px devices
STANDARD     = width >= 200 && height >= 100   (and not CHART)
COMPACT      = width >= 130                    (and not CHART, not STANDARD)
TILE         = width <  130                    (shares COMPACT code path)
```

> **Why w>=200 for CHART-ROUND?** Several common round devices have a full-screen slot
> of exactly 218×218 px (Fenix 3/3HR, Fenix 5S, FR255S, FR255SM, VivoActive 4S) or
> 208×208 px (FR55). Without this correction their only full-screen slot falls into
> STANDARD instead of the full chart view. The narrower CHART-RECT threshold (w>=220)
> stays unchanged because there are no rectangle devices with a near-220px full-screen slot.

### Round-display top-vs-bottom field handling

The field `onUpdate` DC always has `(0,0)` at the top-left of its own allocated
rectangle. **There is no API to detect whether the field occupies the top or bottom
half of the round screen.** Both halves are clipping-symmetric about y=120.

| Field position on screen | Risk edge in field-local coordinates |
|--------------------------|--------------------------------------|
| Top field (screen y 0–119)    | TOP of field (local y 0–30) |
| Bottom field (screen y 122–241) | BOTTOM of field (local y 89–119) |

Because we cannot distinguish the two at runtime, the rule is:
**apply round-safe x-inset at BOTH the top and bottom ~30 px of any slot on a
round display.** Keep all text centred. This handles top and bottom slots correctly
with one code path — no separate variant needed.

### Known issues (current code vs target)

| Issue | Status |
|-------|--------|
| FR745/Fenix 2-Fields (240×119): `h=119` fell below old `h<120` CMPCT threshold | Fixed by new threshold: `h>=100` → STD |
| Round display chart header at `(8,8)` and `(w-8,10)` — clipped on round | Fixed (done by developer) |
| Left-aligned guidance at `x=8` clipped on top/bottom edge round slots | To fix: centre all text on round displays |
| Old CMPCT/STRIP/HALF classes now replaced by COMPACT/TILE | Pending implementation |
| Small round full-screen (218px): fell into STANDARD under old w>=220 CHART-ROUND rule | Fixed by lowering threshold to w>=200 |

---

## Recommended devices to add to manifest.xml

All devices below have been screened against the 5-tier layout thresholds and require
no additional layout work. Group them in `manifest.xml` as they share the same layout paths.

### Round 240 px class (CHART-ROUND + STD + CMPCT/TILE — same as fr745/fenix5xplus)
```
fr745, fr935, fr945, fr945lte, fr955, fr965, fr970
fr265, fr265s, fr255, fr255m, fr245, fr245m, fr165, fr165m, fr645, fr645m
fenix7, fenix7s, fenix7x, fenix8solar, enduro, enduro3
venu, venu2, venu2s, venu2plus, venud
vivoactive4, vivoactive6
```

### Round 218 px class (needs w>=200 CHART-ROUND threshold — see above)
```
fr55, fr255s, fr255sm, fenix3, fenix3_hr, fenix5s, vivoactive4s
```

### Round 390–454 px class (Venu 3, VivoActive 5 — large round, all tiers work cleanly)
```
venu3, venu3s, vivoactive5
```

### Rect cycling — identical to edge840 geometry
```
edge530   (already in manifest)
```

### Devices to skip (incompatible or irrelevant)
Aviation (approach, d2), diving (descent), golf (s40/s60/s62/approach_s70), handhelds
(gpsmap/montana/oregon/rino), instinct (semi-octagon), legacy FR series (fr10/15/25/30),
old semi-round (fr230/235/630/735/230/235), venusq variants, Lily series (no CIQ data fields).

---

## Recommended next steps

1. **Add `edge530` to `manifest.xml`** ✅ Done (per developer).
2. **Fix round-display chart header** ✅ Done (per developer).
3. **Implement 5-tier layout** — see `design-spec.md` for per-design content spec.
4. **Use `CHART-ROUND: w>=200` threshold** (not w>=220) to properly serve 218px round devices.
5. **Add recommended device list above to `manifest.xml`** after layout implementation is tested.
6. **Lily 2 Active** — NOT in SDK 9.1.0 device list; likely no CIQ data field support. Skip.
