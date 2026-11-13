# ORBIT Sprint 03 — native Windows 11 Android evidence collector.
# No reboot occurs unless -AllowReboot is explicitly supplied.
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Apk,
  [string]$UpgradeApk,
  [string]$Out = "validation\android-run-$(Get-Date -Format 'yyyyMMddTHHmmssZ')",
  [string]$Device = $env:ANDROID_SERIAL,
  [switch]$AllowReboot
)
$ErrorActionPreference = 'Stop'
$Package = 'app.orbit.orbit_visual_lab'
$Activity = '.MainActivity'
function Invoke-Checked([scriptblock]$Command) {
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "Android command failed with exit code $LASTEXITCODE" }
}
function Adb([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments) {
  & adb -s $script:Device @Arguments
  if ($LASTEXITCODE -ne 0) { throw "adb $($Arguments -join ' ') failed" }
}
function Snapshot-Preferences([string]$Name) {
  $target = Join-Path $Out "persistence\$Name.xml"
  & adb -s $Device shell run-as $Package cat shared_prefs/FlutterSharedPreferences.xml |
    Out-File -Encoding utf8 $target
  if ($LASTEXITCODE -ne 0) { throw 'Preference capture failed' }
  Get-FileHash -Algorithm SHA256 $target | Out-File "$target.sha256"
}
function Screenshot([string]$Name) {
  Adb shell screencap -p "/sdcard/$Name.png"
  Adb pull "/sdcard/$Name.png" (Join-Path $Out "screenshots\$Name.png")
  Adb shell rm "/sdcard/$Name.png"
}
if (-not (Test-Path $Apk)) { throw "APK not found: $Apk" }
New-Item -ItemType Directory -Force -Path $Out, "$Out\logs", "$Out\screenshots", "$Out\persistence" | Out-Null
if (-not $Device) {
  $online = @(& adb devices | Select-String "`tdevice$")
  if ($online.Count -ne 1) { throw 'Exactly one online device is required; set ANDROID_SERIAL for multiple devices.' }
  $Device = ($online[0].ToString() -split "`t")[0]
}
& adb version | Out-File "$Out\logs\adb-version.txt"
& adb -s $Device get-state | Out-File "$Out\logs\device-state.txt"
& adb -s $Device shell getprop | Out-File "$Out\logs\device-properties.txt"
Get-FileHash -Algorithm SHA256 $Apk | Out-File "$Out\logs\base-apk.sha256"
Adb install -r $Apk | Tee-Object "$Out\logs\install-base.log"
Push-Location (Join-Path $PSScriptRoot '..')
try {
  & flutter test integration_test/app_test.dart -d $Device 2>&1 | Tee-Object "$Out\logs\integration-test.log"
  if ($LASTEXITCODE -ne 0) { throw 'Integration test failed; inspect raw log before assigning status.' }
} finally { Pop-Location }
foreach ($name in @('orbit_static_eco','orbit_rive_balanced','orbit_filament_balanced','orbit_filament_static_fallback','orbit_before_low_memory')) {
  & adb -s $Device shell "run-as $Package sh -c 'test -f cache/$name.png && cat cache/$name.png > /data/local/tmp/$name.png'"
  if ($LASTEXITCODE -eq 0) {
    Adb pull "/data/local/tmp/$name.png" "$Out\screenshots\$name.png"
    Adb shell rm "/data/local/tmp/$name.png"
  }
}
& adb -s $Device logcat -d -v threadtime | Out-File -Encoding utf8 "$Out\logs\logcat-renderer.txt"
& adb -s $Device shell am send-trim-memory $Package 80 | Out-File "$Out\logs\low-memory-command.log"
Start-Sleep -Seconds 3
Screenshot 'after_low_memory'
& adb -s $Device logcat -d -v threadtime | Out-File -Encoding utf8 "$Out\logs\logcat-low-memory.txt"
Snapshot-Preferences 'before_force_stop'
Adb shell am force-stop $Package
Adb shell am start -W -n "$Package/$Activity" | Out-File "$Out\logs\relaunch.log"
Start-Sleep -Seconds 4
Snapshot-Preferences 'after_force_stop'
$forceStopEqual = (Get-Content -Raw "$Out\persistence\before_force_stop.xml") -eq (Get-Content -Raw "$Out\persistence\after_force_stop.xml")
"force_stop_preferences_equal=$forceStopEqual" | Out-File "$Out\logs\force-stop-result.txt"
Screenshot 'after_force_stop'
if ($UpgradeApk) {
  $baseCode = [long](& apkanalyzer manifest version-code $Apk)
  $newCode = [long](& apkanalyzer manifest version-code $UpgradeApk)
  if ($newCode -le $baseCode) { throw "Upgrade versionCode $newCode is not greater than $baseCode" }
  Snapshot-Preferences 'before_upgrade'
  Adb install -r $UpgradeApk | Tee-Object "$Out\logs\install-upgrade.log"
  Adb shell am start -W -n "$Package/$Activity" | Out-File "$Out\logs\upgrade-relaunch.log"
  Start-Sleep -Seconds 4
  Snapshot-Preferences 'after_upgrade'
  $upgradeEqual = (Get-Content -Raw "$Out\persistence\before_upgrade.xml") -eq (Get-Content -Raw "$Out\persistence\after_upgrade.xml")
  "upgrade_preferences_equal=$upgradeEqual;base=$baseCode;new=$newCode" | Out-File "$Out\logs\upgrade-result.txt"
  Screenshot 'after_upgrade'
} else { 'NOT RUN: -UpgradeApk not supplied' | Out-File "$Out\logs\upgrade-status.txt" }
if ($AllowReboot) {
  Snapshot-Preferences 'before_reboot'
  Adb reboot
  & adb -s $Device wait-for-device
  do { Start-Sleep -Seconds 2; $booted = (& adb -s $Device shell getprop sys.boot_completed) -join '' } while ($booted.Trim() -ne '1')
  'Unlock the test device if required, then press Enter.' | Out-Host
  Read-Host | Out-Null
  Adb shell am start -W -n "$Package/$Activity"
  Start-Sleep -Seconds 4
  Snapshot-Preferences 'after_reboot'
  $rebootEqual = (Get-Content -Raw "$Out\persistence\before_reboot.xml") -eq (Get-Content -Raw "$Out\persistence\after_reboot.xml")
  "reboot_preferences_equal=$rebootEqual" | Out-File "$Out\logs\reboot-result.txt"
  Screenshot 'after_reboot'
} else { 'NOT RUN: -AllowReboot not supplied' | Out-File "$Out\logs\reboot-status.txt" }
Get-ChildItem "$Out\screenshots\*.png" | Get-FileHash -Algorithm SHA256 | Out-File "$Out\screenshots\SHA256SUMS.txt"
"Evidence collection finished: $Out. Review raw logs before assigning PASS."
