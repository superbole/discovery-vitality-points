# Connect IQ SDK Reference (Discovery Vitality Points)

## SDK Setup (Windows)

Garmin requires the **Connect IQ SDK Manager** to download SDKs.

- SDK Manager EXE (on your machine):
  - `C:\Users\SheldonBole\Downloads\connectiq-sdk-manager-windows\sdkmanager.exe`

## Install SDK 9.1.0 Side-by-Side

1. Open SDK Manager and log in.
2. Download **Connect IQ 9.1.0**.
3. Confirm the SDK folder exists under:
   - `C:\Users\SheldonBole\AppData\Roaming\Garmin\ConnectIQ\Sdks\`

Note: this project uses SDK 9.1.0 via `build.ps1` and does not rely on the "current SDK" setting.

## Build

```powershell
cd "C:\Users\SheldonBole\Projects\Discovery Vitality Points"
.\build.ps1 -Device edge840 -KeyPath .\developer_key.der
```

## Run (Simulator)

```powershell
monkeydo bin\DiscoveryVitalityPoints.prg edge840
```
