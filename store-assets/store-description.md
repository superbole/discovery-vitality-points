# Discovery Vitality Points — Store Listing

## App Name
Discovery Vitality Points

---

## Short Description (≤ 80 characters)
Live Vitality points prediction for your Garmin — while you're riding or running.

---

## Full Description

Know exactly how many Discovery Vitality fitness points your activity will earn — before it ends.

Discovery Vitality Points is a Connect IQ data field that estimates your Vitality fitness points in real time, using your heart rate, age, and activity duration. The points model follows Discovery's published HR-zone and time-band rules, so you always know whether you're on track for 100, 200, or 300 points — and exactly what you need to do to get there.

**What it shows**

The data field displays a colour-coded activity chart — a grid of heart rate zones (Easy / Light / Moderate / Vigorous) against time bands (15 / 30 / 60 / 90 minutes). Your current position is highlighted in the grid, and a trend line traces the path of your average HR over the course of the activity. At a glance you can see which points tier you have locked in, and how far you are from the next one.

Alongside the chart:
- **Current predicted points** — displayed large in the centre of your current cell, coloured by tier (yellow → orange → green, fully customisable)
- **Guidance line** — shows the two most actionable numbers: how many more minutes at your current intensity, and how many bpm above your current average you'd need to reach the next tier. Example: `18m | 6bpm`
- **Heart rate header** — current HR on the left, session average on the right
- **Tier headroom** (optional) — shows how many bpm your average can drop before you slip a tier, so you know when you can ease off

**Compact and tile layouts**

On smaller data field slots the chart is replaced with two large numbers (configurable: current HR, average HR, or points) plus the guidance line below. All information fits cleanly on every supported slot size.

**Alerts**

When your predicted points tier increases or decreases, the data field can play a tone and optionally show a full-screen alert on supported devices.

**Endurance / High Performance Athletes**

Members registered for Discovery's Endurance & High Performance programme can enable extended tiers — 450 and 600 points — in the settings.

**Important disclaimer**

This data field estimates points using Discovery's published rules. Official Vitality points are awarded by Discovery after your activity syncs, and the final tally may differ (for example, if HR data doesn't transfer cleanly to Discovery's platform). This app is not affiliated with or endorsed by Discovery or Garmin.

---

## Supported devices

Edge 530 · Edge 540 · Edge 550 · Edge 840 · Edge 850 · Edge 1040 · Edge 1050 · Edge MTB · Forerunner 745 · Fēnix 5X Plus

---

## Settings reference

### Age & profile
- **Age Source** — whether age is read automatically from your Garmin user profile (recommended) or entered manually. Age drives the max HR calculation (220 − age) and therefore all zone thresholds.
- **Birth Year / Month / Day** — used when Age Source is set to Manual (date-accurate, increments on birthday).
- **Manual Age** — alternative to date of birth when only age in years is known.

### Points & guidance
- **Guidance Mode** — *Next Tier* (default) shows what you need to reach the next points band. *Target Points* shows progress toward a specific points goal.
- **Target Points** — the points value to aim for when Guidance Mode is set to Target Points. Options: 100 / 200 / 300 / 450 / 600.
- **Endurance Athlete** — enables the 450 and 600-point tiers for members registered on Discovery's Endurance & High Performance programme.

### Display
- **Primary Display** — what the large central number shows on chart layouts: Points (default), Average HR, or Current HR.
- **Compact / tile: left value** — the left large number on compact and tile slots. Options: Current HR / Average HR / Points.
- **Compact / tile: right value** — the right large number on compact and tile slots.
- **Show Zone Label** — shows the current HR zone name (VIGOROUS / MODERATE etc.) as a text label. Useful on standard-size slots; can be turned off to reduce clutter.
- **Show HR Guidance** — includes the bpm target in the guidance line. Turn off if you only want the time component.
- **Show tier headroom** — adds a downward indicator showing how many bpm your average HR can fall before you drop a tier. On tall layouts this appears as a second line below the main guidance.

### Chart appearance
- **HR Axis Labels** — labels on the vertical (HR zone) axis of the chart. Options: Off / Values (bpm thresholds) / Names (V/M/L/E abbreviations) / Both.
- **Crosshair** — colour of the crosshair lines that mark your current position in the chart. Options: Off / Black / White / Red / Blue / Yellow / Green.
- **Colour: 100 pts band** — the fill colour used for cells in the 100-point tier of the chart. Default: Yellow.
- **Colour: 200 pts band** — default: Orange.
- **Colour: 300 pts band** — default: Green.
- **Colour: 450 pts band** — default: Teal (Endurance athletes only).
- **Colour: 600 pts band** — default: Blue (Endurance athletes only).

### Alerts
- **Point change tones** — plays a beep through the device when your predicted points tier changes.
- **Point change alerts** — shows a full-screen overlay when your points tier changes (requires Activity Alerts to be enabled for this data field in device settings).

### Developer
- **Validation Mode** — overlays layout tier name and debug info on screen. For development use only — turn off for normal rides.

---

## Changelog

### V1.0.0 — Initial release
- Real-time Vitality points prediction from HR zone × duration matrix
- CHART layout (rect and round) with full zone × time grid, trend line, and crosshairs
- STANDARD zoomed layout for medium slots
- COMPACT / TILE layout for small slots and half-tiles
- Guidance line: time to next tier and HR delta
- Tier headroom display
- Fully customisable tier colours and crosshair colour
- HR axis labels (off / values / names / both)
- Endurance / High Performance extended tiers (450 / 600 pts)
- Sound alerts and full-screen point-change alerts
- Age from Garmin user profile or manual entry (date-accurate)
- Supported: Edge 530/540/550/840/850/1040/1050/MTB, Forerunner 745, Fēnix 5X Plus
