#!/usr/bin/env bash
set -euo pipefail
APK="${1:?Usage: arm64_smoke_collect.sh ORBIT_0.5.4_android_arm64.apk [output_dir]}"
OUT="${2:-ORBIT_ARM64_EVIDENCE}"
ADB="${ADB:-adb}"
PACKAGE="app.orbit.orbit_visual_lab"
mkdir -p "$OUT/screenshots" "$OUT/logs"
"$ADB" devices -l
ABI=$("$ADB" shell getprop ro.product.cpu.abi | tr -d '\r')
QEMU=$("$ADB" shell getprop ro.kernel.qemu | tr -d '\r')
[[ "$ABI" == "arm64-v8a" ]] || { printf 'Physical ARM64 required, got %s\n' "$ABI" >&2; exit 1; }
[[ "$QEMU" != "1" ]] || { printf 'Emulator evidence is not physical ARM64 evidence\n' >&2; exit 1; }
"$ADB" install -r "$APK" | tee "$OUT/logs/install.log"
"$ADB" shell am force-stop "$PACKAGE"
"$ADB" shell am start -W "$PACKAGE/.MainActivity" | tee "$OUT/logs/cold-start.log"
sleep 6
"$ADB" exec-out screencap -p > "$OUT/screenshots/cold-start.png"
"$ADB" shell screenrecord --time-limit 10 /sdcard/orbit-arm64-smoke.mp4 | tee "$OUT/logs/screenrecord.log" &
RECORD_PID=$!
"$ADB" shell dumpsys meminfo "$PACKAGE" > "$OUT/logs/meminfo.txt"
"$ADB" shell getprop ro.product.model > "$OUT/logs/device.txt"
"$ADB" shell getprop ro.build.version.release >> "$OUT/logs/device.txt"
"$ADB" shell getprop ro.product.cpu.abi >> "$OUT/logs/device.txt"
"$ADB" shell dumpsys SurfaceFlinger > "$OUT/logs/surfaceflinger.txt"
wait "$RECORD_PID"
"$ADB" pull /sdcard/orbit-arm64-smoke.mp4 "$OUT/screenshots/orbit-arm64-smoke.mp4"
"$ADB" logcat -d -v time > "$OUT/logs/logcat.txt"
python - "$OUT" <<'PY'
import hashlib
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
lines = []
for path in sorted(root.rglob('*')):
    if path.is_file() and path.name != 'SHA256SUMS.txt':
        lines.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(root)}")
(root / 'SHA256SUMS.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY
printf 'Evidence collected in %s\n' "$OUT"
