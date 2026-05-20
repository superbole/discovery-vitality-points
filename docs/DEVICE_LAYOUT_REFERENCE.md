# Connect IQ device layouts (Vitality Points targets)

Official device pages (human-readable): [Edge 840](https://developer.garmin.com/connect-iq/device-reference/edge840/), [Forerunner 745](https://developer.garmin.com/connect-iq/device-reference/fr745/), [fēnix 5X Plus](https://developer.garmin.com/connect-iq/device-reference/fenix5xplus/).

Machine-readable tables (same content as the site): Garmin publishes static HTML under `https://developer.garmin.com/connect-iq/articles/device-reference/<deviceId>.html` (for example `edge840.html`, `fr745.html`, `fenix5xplus.html`). Each page lists **screen attributes**, **per app-type memory limits**, and **every built-in data-field layout** with pixel `Left`, `Top`, `Width`, `Height`, and obscurity flags per field.

## Summary (from device reference tables)

| Device | Product id | Screen | Shape | Colors | Display | SDK device group (this SDK) |
|--------|------------|--------|-------|--------|---------|-----------------------------|
| Edge 840 / 840 Solar | `edge840` | **246 × 322** | rectangle | 65536 | LCD (16 bpp) | API level 6.0 |
| Forerunner 745 | `fr745` | **240 × 240** | round | 64 | MIP (8 bpp) | API level 3.3 |
| fēnix 5X Plus | `fenix5xplus` | **240 × 240** | round | 64 | MIP (8 bpp) | API level 3.3 |

**Data field memory limit** is **131072** bytes on all three (per reference tables).

## How field sizes correlate across these devices

1. **Watches share one resolution class**  
   FR745 and fēnix 5X Plus are both **240 × 240 round** (`deviceFamily` `round-240x240` in the SDK). Per-layout field rectangles are **nearly identical** (differences of a few pixels on some multi-field variants, e.g. 3-field “A” middle row height). For UI design you can treat them as **one “240 round” tier**: same font budget, same obscured bezel/chronos insets, same need for short secondary copy.

2. **Edge 840 is a different tier entirely**  
   Full-screen single field is **246 × 322** — much taller than a watch face. Multi-field activity layouts slice that into **narrow horizontal strips** (for example 5-field layout A uses five **246 × 62** rows; 6-field layout A uses six **246 × 62** rows except the last row height may differ slightly). A strip **~60 px tall** is the constraining case for secondary text on the bike, not the 322 px single-field case.

3. **`dc.getWidth()` / `dc.getHeight()` are per field, not full device**  
   The Connect IQ data field always draws in **its allocated rectangle** for the chosen layout. Layout tables on the device pages are exactly those rectangles.

4. **Round vs rectangle**  
   On 240 × 240 round devices, fields still receive a **bounding box** rectangle; Garmin documents **obscurity flags** (which edges are clipped by the round mask). Edge 840 rectangles are **not** obscured in the reference tables (`False` on sample rows), so labels can use the full width of the slot.

## Project implications

- **Primary targets**: `edge840`, `fr745`, `fenix5xplus` are listed first in `manifest.xml`. Other Edge products remain supported.
- **`minApiLevel`**: Set to **3.2.0** so the app can run on **fēnix 5X Plus** units still on older part-number firmware (reference lists **3.2.8** as well as **3.3.x** Connect IQ versions). Edge 840 remains compatible (it reports API level 6.0 in the SDK device definition).
- **Typography**: Secondary labels that were drawn with `FONT_XTINY` are scaled up where slot height allows; only very short strips (roughly **under 52 px** tall) still use `FONT_XTINY`. Implementation: `DiscoveryVitalityPointsView.mc` (`pickCaptionFont` / `pickDetailFont` and bottom guidance stacking via `dc.getFontHeight`).

## Reference URLs

- Edge 840 / 840 Solar: https://developer.garmin.com/connect-iq/device-reference/edge840/
- Forerunner 745: https://developer.garmin.com/connect-iq/device-reference/fr745/
- fēnix 5X Plus: https://developer.garmin.com/connect-iq/device-reference/fenix5xplus/
