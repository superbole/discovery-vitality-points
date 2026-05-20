---
description: Build the data field, load it into the CIQ simulator, optionally set the layout, and show a screenshot.
argument-hint: [device] [layout]  — device defaults to fr745; layout: 1, 2, 3a, 3b, 4a, 4b, 5a, 5b, 6a, 6b, 7a, 7b, 8, 9, 10
---

Take a screenshot of the Garmin Connect IQ simulator running the Discovery Vitality Points data field.
Uses the simulator's own built-in screen capture (File → Save Screen Capture) for a clean, chrome-free crop of just the watch/device face.

## Argument parsing

Parse `$ARGUMENTS` as space-separated tokens. Order does not matter.

- **Device**: any token containing letters (e.g. `fr745`, `edge840`, `fenix5xplus`). Default: `fr745`.
- **Layout**: a token matching one of the layout keys below. Default: no change (leave current layout).

Layout → simulator WM_COMMAND id (same IDs on all devices):

| Token        | Menu label  | ID   | Typical availability  |
|--------------|-------------|------|-----------------------|
| `1`          | 1 Field(s)  | 6007 | all devices           |
| `2`          | 2 Fields    | 6008 | all devices           |
| `3` / `3a`   | 3 Fields A  | 6009 | all devices           |
| `3b`         | 3 Fields B  | 6010 | all devices           |
| `4` / `4a`   | 4 Fields A  | 6011 | all devices           |
| `4b`         | 4 Fields B  | 6012 | edge & multi-field    |
| `5` / `5a`   | 5 Fields A  | 6013 | edge & multi-field    |
| `5b`         | 5 Fields B  | 6014 | edge & multi-field    |
| `6` / `6a`   | 6 Fields A  | 6015 | edge & multi-field    |
| `6b`         | 6 Fields B  | 6016 | edge & multi-field    |
| `7` / `7a`   | 7 Fields A  | 6017 | edge & multi-field    |
| `7b`         | 7 Fields B  | 6018 | edge & multi-field    |
| `8`          | 8 Fields    | 6019 | edge & multi-field    |
| `9`          | 9 Fields    | 6020 | edge & multi-field    |
| `10`         | 10 Fields   | 6021 | edge & multi-field    |

## Steps

### 1. Build the PRG

```powershell
cd "C:\Users\SheldonBole\Projects\Discovery Vitality Points"
.\build.ps1 -Device <device> -KeyPath .\developer_key.der
```

Stop and report any build error. Do not proceed.

### 2. Launch simulator if not already running

```powershell
$sim = Get-Process -Name "simulator" -ErrorAction SilentlyContinue |
       Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
if (-not $sim) {
    $sdk = "C:\Users\SheldonBole\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b\bin"
    Start-Process "$sdk\simulator.exe"
    Start-Sleep -Seconds 5
}
```

### 3. Load the PRG via monkeydo

```powershell
$sdk = "C:\Users\SheldonBole\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b\bin"
$prg = "C:\Users\SheldonBole\Projects\Discovery Vitality Points\bin\DiscoveryVitalityPoints.prg"
Start-Process -FilePath "$sdk\monkeydo.bat" -ArgumentList "`"$prg`"", "<device>" -WindowStyle Hidden
Start-Sleep -Seconds 3
```

### 4. Change layout (only if a layout argument was given)

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class SimLayout {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, UInt32 Msg, IntPtr wParam, IntPtr lParam);
    public const UInt32 WM_COMMAND = 0x0111;
}
"@
$layoutMap = @{
    "1"="6007"; "2"="6008";
    "3"="6009"; "3a"="6009"; "3b"="6010";
    "4"="6011"; "4a"="6011"; "4b"="6012";
    "5"="6013"; "5a"="6013"; "5b"="6014";
    "6"="6015"; "6a"="6015"; "6b"="6016";
    "7"="6017"; "7a"="6017"; "7b"="6018";
    "8"="6019"; "9"="6020"; "10"="6021"
}
$layoutId = [int]$layoutMap["<layout_token>"]
$proc = Get-Process -Name "simulator" | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
[SimLayout]::PostMessage($proc.MainWindowHandle, [SimLayout]::WM_COMMAND, [IntPtr]$layoutId, [IntPtr]0)
Start-Sleep -Milliseconds 500
```

Skip this step entirely if no layout argument was provided.

### 5. Trigger the simulator's built-in screen capture and save to a fixed path

This uses two WM_COMMAND calls and SendKeys to handle the save dialog — no window positioning needed, gives a clean crop of just the device face.

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class SimSave {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, UInt32 Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc proc, IntPtr lp);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lp);
    public const UInt32 WM_COMMAND = 0x0111;
}
"@
$savePath = "C:\Users\SheldonBole\AppData\Local\Temp\ciq_sim_screenshot.png"
$proc = Get-Process -Name "simulator" | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1

# Trigger File > Save Screen Capture (id 5003)
[SimSave]::PostMessage($proc.MainWindowHandle, [SimSave]::WM_COMMAND, [IntPtr]5003, [IntPtr]0)
Start-Sleep -Milliseconds 600

# Find the "Save Screenshot" dialog and type the save path
$dlgHandle = [IntPtr]::Zero
$cb = [SimSave+EnumWindowsProc]{
    param($hWnd, $lp)
    $sb = New-Object System.Text.StringBuilder(256)
    [SimSave]::GetWindowText($hWnd, $sb, 256) | Out-Null
    if ($sb.ToString() -eq "Save Screenshot") { $script:dlgHandle = $hWnd; return $false }
    return $true
}
[SimSave]::EnumWindows($cb, [IntPtr]::Zero)

if ($script:dlgHandle -ne [IntPtr]::Zero) {
    [SimSave]::SetForegroundWindow($script:dlgHandle)
    Start-Sleep -Milliseconds 400
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait($savePath)
    Start-Sleep -Milliseconds 200
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Start-Sleep -Milliseconds 500
    Write-Output $savePath
} else {
    Write-Error "Save Screenshot dialog not found"
}
```

### 6. Display the result

Read the saved PNG with the Read tool and show it inline.

Also report:
- Device simulated
- Layout applied (or "unchanged" if none specified)
- Whether the simulator was freshly launched or already running
