# Discovery Vitality Points (Connect IQ)

## Project Type
- Garmin Connect IQ Data Field (Monkey C)

## Target Toolchain
- Use SDK `9.1.0` for this project (side-by-side with older SDKs).
- Do not change `PowerRoller` toolchain.

## SDK Location (expected)
- `C:\Users\SheldonBole\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.1.0-*\`

## Build
- `.\build.ps1 -Device edge840 -KeyPath .\developer_key.der`
- Other devices: `edge530`, `fr745`, `fenix5xplus`

## Key Files
- `manifest.xml`
- `monkey.jungle`
- `source/DiscoveryVitalityPointsApp.mc`
- `source/DiscoveryVitalityPointsView.mc`

## Safety Rules
- No SDK upgrades unless explicitly requested.
- Keep changes small; compile frequently.
- FR745/Fenix 5X+ have ~8 KB stack — no dynamic allocation or deep call chains in draw paths.
- `dc.getWidth()` / `dc.getHeight()` are the **slot** size (activity layout), not the screen.

## Layout tiers (quick ref)
See `AGENTS.md` for full detail and `docs/design-spec.md` for design intent.
- CHART-RECT: `drawLargeChartLayout` — rect devices, wide+tall slots
- CHART-ROUND: `drawRoundChartLayout` — round devices, full-screen slots
- STANDARD: `drawStandardLayout` — medium slots (≥200×100)
- COMPACT/TILE: `drawCompactLayout` — small slots
