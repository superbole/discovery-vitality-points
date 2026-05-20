Param(
  [string]$Device = "edge840",
  [string]$KeyPath = "developer_key.der",
  [string]$OutFile = "bin\\DiscoveryVitalityPoints.prg"
)

$ErrorActionPreference = "Stop"

$sdkRoot = $env:CIQ_SDK_9
if (-not $sdkRoot) {
  $sdkRoot = Get-ChildItem "C:\\Users\\SheldonBole\\AppData\\Roaming\\Garmin\\ConnectIQ\\Sdks" -Directory `
    | Where-Object { $_.Name -like "connectiq-sdk-win-9.1.0*" } `
    | Select-Object -First 1 -ExpandProperty FullName
}

if (-not $sdkRoot) {
  Write-Error "Connect IQ SDK 9.1.0 not found. Install it side-by-side in SDK Manager first, or set CIQ_SDK_9 to the SDK folder path."
}

$sdkBin = Join-Path $sdkRoot "bin"
if (-not (Test-Path $sdkBin)) {
  Write-Error "SDK bin folder not found: $sdkBin"
}

# Ensure this project uses SDK 9 without touching global PATH/current-sdk.cfg.
$env:Path = "$sdkBin;$env:Path"

if (-not (Test-Path $KeyPath)) {
  Write-Error "Developer key not found at '$KeyPath'. Copy your developer_key.der here, or pass -KeyPath <path>."
}

monkeyc -o $OutFile -f monkey.jungle -d $Device -y $KeyPath
Write-Host "Built: $OutFile"
