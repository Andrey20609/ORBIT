param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Out = "ORBIT_ARM64_EVIDENCE",
    [string]$Adb = "adb"
)
$ErrorActionPreference = "Stop"
$Package = "app.orbit.orbit_visual_lab"
New-Item -ItemType Directory -Force -Path "$Out/screenshots", "$Out/logs" | Out-Null
& $Adb devices -l
$Abi = (& $Adb shell getprop ro.product.cpu.abi).Trim()
$Qemu = (& $Adb shell getprop ro.kernel.qemu).Trim()
if ($Abi -ne "arm64-v8a") { throw "Physical ARM64 required, got $Abi" }
if ($Qemu -eq "1") { throw "Emulator evidence is not physical ARM64 evidence" }
& $Adb install -r $Apk | Tee-Object "$Out/logs/install.log"
& $Adb shell am force-stop $Package
& $Adb shell am start -W "$Package/.MainActivity" | Tee-Object "$Out/logs/cold-start.log"
Start-Sleep 6
& $Adb exec-out screencap -p > "$Out/screenshots/cold-start.png"
& $Adb shell screenrecord --time-limit 10 /sdcard/orbit-arm64-smoke.mp4 | Tee-Object "$Out/logs/screenrecord.log" &
$record = Get-Job
& $Adb shell dumpsys meminfo $Package > "$Out/logs/meminfo.txt"
& $Adb shell getprop ro.product.model > "$Out/logs/device.txt"
& $Adb shell getprop ro.build.version.release >> "$Out/logs/device.txt"
& $Adb shell getprop ro.product.cpu.abi >> "$Out/logs/device.txt"
& $Adb shell dumpsys SurfaceFlinger > "$Out/logs/surfaceflinger.txt"
$record | Wait-Job
& $Adb pull /sdcard/orbit-arm64-smoke.mp4 "$Out/screenshots/orbit-arm64-smoke.mp4"
& $Adb logcat -d -v time > "$Out/logs/logcat.txt"
python - $Out @'
import hashlib
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
lines = []
for path in sorted(root.rglob('*')):
    if path.is_file() and path.name != 'SHA256SUMS.txt':
        lines.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(root)}")
(root / 'SHA256SUMS.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
'@
Write-Host "Evidence collected in $Out"
