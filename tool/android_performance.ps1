# Collect one raw 120-second renderer sample on Windows 11; repeat three times per renderer.
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('static','rive','filament')][string]$Renderer,
  [int]$Duration = 120,
  [int]$Warmup = 15,
  [double]$BudgetMs = 33.33,
  [string]$Out = "validation\performance-$Renderer-$(Get-Date -Format 'yyyyMMddTHHmmssZ')",
  [string]$Device = $env:ANDROID_SERIAL
)
$ErrorActionPreference = 'Stop'
$Package = 'app.orbit.orbit_visual_lab'
function Adb([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments) {
  & adb -s $script:Device @Arguments
  if ($LASTEXITCODE -ne 0) { throw "adb $($Arguments -join ' ') failed" }
}
function Screenshot([string]$Name) {
  Adb shell screencap -p "/sdcard/$Name.png"
  Adb pull "/sdcard/$Name.png" "$Out\$Name.png"
  Adb shell rm "/sdcard/$Name.png"
}
if ($Duration -le 0 -or $Warmup -lt 0 -or $BudgetMs -le 0) { throw 'Durations and budget must be positive' }
if (-not $Device) {
  $online = @(& adb devices | Select-String "`tdevice$")
  if ($online.Count -ne 1) { throw 'Exactly one online device is required; set ANDROID_SERIAL for multiple devices.' }
  $Device = ($online[0].ToString() -split "`t")[0]
}
New-Item -ItemType Directory -Force -Path $Out, "$Out\samples" | Out-Null
@"
renderer_label=$Renderer
duration_seconds=$Duration
warmup_seconds=$Warmup
jank_budget_ms=$BudgetMs
serial=$Device
Select the labeled renderer in the app before capture. This script does not infer renderer state.
Balanced target=33.33 ms. Ultra target=16.67 ms.
"@ | Out-File "$Out\METHOD.txt"
& adb -s $Device shell getprop | Out-File "$Out\device-properties.txt"
& adb -s $Device shell dumpsys package $Package | Out-File "$Out\package.txt"
& adb -s $Device shell dumpsys battery | Out-File "$Out\battery-before.txt"
& adb -s $Device shell dumpsys thermalservice 2>&1 | Out-File "$Out\thermal-before.txt"
& adb -s $Device shell dumpsys gpu 2>&1 | Out-File "$Out\gpu-before.txt"
Start-Sleep -Seconds $Warmup
Adb shell dumpsys gfxinfo $Package reset
Screenshot 'start'
$end = (Get-Date).AddSeconds($Duration)
$index = 0
while ((Get-Date) -lt $end) {
  $sample = Join-Path $Out ('samples\{0:D4}.txt' -f $index)
  "epoch=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" | Out-File $sample
  $processId = (& adb -s $Device shell pidof $Package) -join ''
  "pid=$processId" | Out-File -Append $sample
  & adb -s $Device shell dumpsys meminfo $Package | Out-File -Append $sample
  if ($processId.Trim()) {
    & adb -s $Device shell cat "/proc/$($processId.Trim())/status" | Out-File -Append $sample
    & adb -s $Device shell cat "/proc/$($processId.Trim())/stat" | Out-File -Append $sample
  }
  Start-Sleep -Seconds 2
  $index++
}
& adb -s $Device shell dumpsys gfxinfo $Package framestats | Out-File "$Out\gfxinfo-framestats.txt"
& adb -s $Device shell dumpsys gfxinfo $Package | Out-File "$Out\gfxinfo-summary.txt"
& adb -s $Device shell dumpsys cpuinfo | Out-File "$Out\cpuinfo.txt"
& adb -s $Device shell dumpsys battery | Out-File "$Out\battery-after.txt"
& adb -s $Device shell dumpsys thermalservice 2>&1 | Out-File "$Out\thermal-after.txt"
& adb -s $Device shell dumpsys gpu 2>&1 | Out-File "$Out\gpu-after.txt"
& adb -s $Device shell dumpsys meminfo $Package | Out-File "$Out\meminfo-after.txt"
& adb -s $Device logcat -d -v threadtime | Out-File "$Out\logcat.txt"
Screenshot 'end'
& python (Join-Path $PSScriptRoot 'analyze_performance.py') $Out --budget-ms $BudgetMs | Tee-Object "$Out\analysis.log"
if ($LASTEXITCODE -ne 0) { throw 'No derived metrics: inspect raw capture; status remains NOT MEASURED.' }
Get-ChildItem "$Out\*.png" | Get-FileHash -Algorithm SHA256 | Out-File "$Out\SHA256SUMS.txt"
"Raw capture and derived metrics complete: $Out"
