# Resizes DiscoveryVitalityPointsLauncher.png to each launcher size required by targeted devices,
# writes shared launcher_<N>.png files under resources/drawables/, and copies the right size into
# resources-<deviceId>/drawables/launcher.png with a drawables.xml override.
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$drawDir = Join-Path $projectRoot "resources\drawables"
$srcPath = Join-Path $drawDir "DiscoveryVitalityPointsLauncher.png"
if (-not (Test-Path $srcPath)) {
    Write-Error "Source image not found: $srcPath"
}

Add-Type -AssemblyName System.Drawing

function Save-LauncherPng {
    param(
        [string]$SourcePath,
        [string]$OutPath,
        [int]$Size
    )
    $srcImg = [System.Drawing.Image]::FromFile($SourcePath)
    $bmp = $null
    try {
        $bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.DrawImage($srcImg, 0, 0, $Size, $Size)
        } finally {
            $g.Dispose()
        }
        $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $srcImg.Dispose()
        if ($null -ne $bmp) { $bmp.Dispose() }
    }
}

$uniqueSizes = @(35, 36, 40, 56, 68)
foreach ($s in $uniqueSizes) {
    $out = Join-Path $drawDir "launcher_$s.png"
    Save-LauncherPng -SourcePath $srcPath -OutPath $out -Size $s
}

$deviceToSize = [ordered]@{
    edge540     = 35
    edge840     = 35
    edgemtb     = 36
    fr745       = 40
    fenix5xplus = 40
    edge1040    = 40
    edge850     = 56
    edge550     = 56
    edge1050    = 68
}

$drawablesXml = @"
<?xml version="1.0"?>
<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">
    <bitmap id="LauncherIcon" filename="launcher.png" dithering="none" />
</drawables>
"@.Trim() + "`n"

foreach ($dev in $deviceToSize.Keys) {
    $sz = $deviceToSize[$dev]
    $dir = Join-Path $projectRoot "resources-$dev\drawables"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Copy-Item -Path (Join-Path $drawDir "launcher_$sz.png") -Destination (Join-Path $dir "launcher.png") -Force
    $xmlPath = Join-Path $dir "drawables.xml"
    [System.IO.File]::WriteAllText($xmlPath, $drawablesXml, [System.Text.UTF8Encoding]::new($false))
}

Write-Host "Launcher assets generated from: $srcPath"
