#!/usr/bin/env bash
# Collect raw Android performance evidence for one manually selected renderer.
# The renderer argument is a label; select the same mode in ORBIT Visual Lab
# before running this script. No FPS/RAM/thermal value is synthesized.
set -euo pipefail

PACKAGE="app.orbit.orbit_visual_lab"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="${ADB:-adb}"
RENDERER="${1:-}"
DURATION="${2:-120}"
WARMUP="${WARMUP_SECONDS:-15}"
OUT="${3:-$ROOT/validation/performance-$(date -u +%Y%m%dT%H%M%SZ)-${RENDERER:-unlabeled}}"

if [[ "$RENDERER" != "static" && "$RENDERER" != "rive" && "$RENDERER" != "filament" ]]; then
  echo "Usage: $0 {static|rive|filament} [duration_seconds] [output_dir]" >&2
  exit 2
fi
[[ "$DURATION" =~ ^[1-9][0-9]*$ ]]
[[ "$WARMUP" =~ ^[0-9]+$ ]]
command -v "$ADB" >/dev/null
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  DEVICE="$ANDROID_SERIAL"
else
  mapfile -t DEVICES < <("$ADB" devices | awk 'NR > 1 && $2 == "device" {print $1}')
  ((${#DEVICES[@]} == 1)) || { echo "One online device required" >&2; exit 1; }
  DEVICE="${DEVICES[0]}"
fi
ADB_DEVICE=("$ADB" -s "$DEVICE")
mkdir -p "$OUT/samples"

cat > "$OUT/METHOD.txt" <<EOF
renderer_label=$RENDERER
duration_seconds=$DURATION
warmup_seconds=$WARMUP
utc_start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
serial=$DEVICE
The label is supplied by the operator. Select $RENDERER in the app before capture.
Raw samples are evidence, not automatically calculated performance claims.
EOF
"${ADB_DEVICE[@]}" shell getprop > "$OUT/device-properties.txt"
"${ADB_DEVICE[@]}" shell dumpsys package "$PACKAGE" > "$OUT/package.txt"
"${ADB_DEVICE[@]}" shell dumpsys battery > "$OUT/battery-before.txt"
"${ADB_DEVICE[@]}" shell dumpsys thermalservice > "$OUT/thermal-before.txt" 2>&1 || true
"${ADB_DEVICE[@]}" shell dumpsys gpu > "$OUT/gpu-before.txt" 2>&1 || true
sleep "$WARMUP"
"${ADB_DEVICE[@]}" shell dumpsys gfxinfo "$PACKAGE" reset
"${ADB_DEVICE[@]}" exec-out screencap -p > "$OUT/start.png"

END=$((SECONDS + DURATION))
INDEX=0
while ((SECONDS < END)); do
  SAMPLE="$OUT/samples/$(printf '%04d' "$INDEX")"
  PID="$("${ADB_DEVICE[@]}" shell pidof "$PACKAGE" | tr -d '\r' | awk '{print $1}')"
  {
    echo "epoch=$(date +%s)"
    echo "uptime=$(cat /proc/uptime)"
    echo "pid=$PID"
    "${ADB_DEVICE[@]}" shell dumpsys meminfo "$PACKAGE"
    if [[ -n "$PID" ]]; then
      "${ADB_DEVICE[@]}" shell cat "/proc/$PID/status"
      "${ADB_DEVICE[@]}" shell cat "/proc/$PID/stat"
    fi
  } > "$SAMPLE.txt" 2>&1
  sleep 2
  INDEX=$((INDEX + 1))
done

"${ADB_DEVICE[@]}" shell dumpsys gfxinfo "$PACKAGE" framestats \
  > "$OUT/gfxinfo-framestats.txt"
"${ADB_DEVICE[@]}" shell dumpsys gfxinfo "$PACKAGE" \
  > "$OUT/gfxinfo-summary.txt"
"${ADB_DEVICE[@]}" shell dumpsys cpuinfo > "$OUT/cpuinfo.txt"
"${ADB_DEVICE[@]}" shell dumpsys battery > "$OUT/battery-after.txt"
"${ADB_DEVICE[@]}" shell dumpsys thermalservice > "$OUT/thermal-after.txt" 2>&1 || true
"${ADB_DEVICE[@]}" shell dumpsys gpu > "$OUT/gpu-after.txt" 2>&1 || true
"${ADB_DEVICE[@]}" shell dumpsys meminfo "$PACKAGE" > "$OUT/meminfo-after.txt"
"${ADB_DEVICE[@]}" logcat -d -v threadtime > "$OUT/logcat.txt"
"${ADB_DEVICE[@]}" exec-out screencap -p > "$OUT/end.png"
sha256sum "$OUT"/*.png > "$OUT/SHA256SUMS"

echo "Raw capture complete: $OUT"
echo "Frame pacing, P95, memory, power and thermal conclusions require analysis of these files."
