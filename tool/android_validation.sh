#!/usr/bin/env bash
# ORBIT Sprint 02 Android evidence collector.
# No step is reported as PASS unless its command and assertions actually run.
set -euo pipefail

PACKAGE="app.orbit.orbit_visual_lab"
ACTIVITY=".MainActivity"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="${ADB:-adb}"
FLUTTER="${FLUTTER:-flutter}"
APK="$ROOT/build/app/outputs/flutter-apk/app-debug.apk"
UPGRADE_APK=""
OUT="$ROOT/validation/$(date -u +%Y%m%dT%H%M%SZ)"
ALLOW_REBOOT=0

usage() {
  cat <<'EOF'
Usage: tool/android_validation.sh [options]
  --apk PATH          Base debug APK (default: build/.../app-debug.apk)
  --upgrade-apk PATH  Higher-version APK for a real no-data-wipe upgrade test
  --out DIR           Evidence directory
  --reboot            Permit the optional physical-device reboot test
  -h, --help          Show this help

Requires one online Android device, or ANDROID_SERIAL for a multi-device host.
The device must be unlocked. Reboot is never performed without --reboot.
EOF
}

while (($#)); do
  case "$1" in
    --apk) APK="$2"; shift 2 ;;
    --upgrade-apk) UPGRADE_APK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --reboot) ALLOW_REBOOT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v "$ADB" >/dev/null
command -v "$FLUTTER" >/dev/null
[[ -f "$APK" ]]
mkdir -p "$OUT/screenshots" "$OUT/logs" "$OUT/persistence"

mapfile -t DEVICES < <("$ADB" devices | awk 'NR > 1 && $2 == "device" {print $1}')
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  DEVICE="$ANDROID_SERIAL"
elif ((${#DEVICES[@]} == 1)); then
  DEVICE="${DEVICES[0]}"
else
  echo "Need exactly one online device or ANDROID_SERIAL; found: ${DEVICES[*]:-none}" >&2
  exit 1
fi
export ANDROID_SERIAL="$DEVICE"
ADB_DEVICE=("$ADB" -s "$DEVICE")

"${ADB_DEVICE[@]}" get-state
{
  echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "serial=$DEVICE"
  "${ADB_DEVICE[@]}" shell getprop
  "${ADB_DEVICE[@]}" shell dumpsys package "$PACKAGE"
} > "$OUT/logs/device-before.txt" 2>&1 || true
sha256sum "$APK" > "$OUT/logs/base-apk.sha256"
"${ADB_DEVICE[@]}" logcat -c

snapshot_preferences() {
  local name="$1"
  "${ADB_DEVICE[@]}" exec-out run-as "$PACKAGE" cat \
    shared_prefs/FlutterSharedPreferences.xml \
    > "$OUT/persistence/$name.xml"
  sha256sum "$OUT/persistence/$name.xml" \
    > "$OUT/persistence/$name.sha256"
}

launch() {
  "${ADB_DEVICE[@]}" shell am start -W -n "$PACKAGE/$ACTIVITY"
  sleep 4
}

screenshot() {
  local name="$1"
  "${ADB_DEVICE[@]}" exec-out screencap -p > "$OUT/screenshots/$name.png"
}

# Install and run the actual Flutter integration suite. Its Dart assertions,
# native Filament stats and logcat are the primary renderer evidence.
"${ADB_DEVICE[@]}" install -r "$APK" 2>&1 | tee "$OUT/logs/install-base.log"
(
  cd "$ROOT"
  "$FLUTTER" test integration_test/app_test.dart -d "$DEVICE"
) 2>&1 | tee "$OUT/logs/integration-test.log"

for name in \
  orbit_static_eco \
  orbit_rive_balanced \
  orbit_filament_balanced \
  orbit_filament_static_fallback \
  orbit_before_low_memory; do
  if "${ADB_DEVICE[@]}" shell run-as "$PACKAGE" test -f "cache/$name.png"; then
    "${ADB_DEVICE[@]}" exec-out run-as "$PACKAGE" cat "cache/$name.png" \
      > "$OUT/screenshots/$name.png"
  fi
done
"${ADB_DEVICE[@]}" logcat -d -v threadtime > "$OUT/logs/logcat-renderer.txt"

# Real native onTrimMemory probe. Expected outcome: diagnostics in logcat and a
# visible Static scene. The PNG and log are evidence; this script does not claim
# visual correctness on their behalf.
if "${ADB_DEVICE[@]}" shell am send-trim-memory "$PACKAGE" 80 \
    > "$OUT/logs/low-memory-command.log" 2>&1; then
  sleep 3
  screenshot "after_low_memory"
  "${ADB_DEVICE[@]}" logcat -d -v threadtime > "$OUT/logs/logcat-low-memory.txt"
else
  echo "LOW MEMORY COMMAND FAILED" >&2
fi

snapshot_preferences "before_force_stop"
"${ADB_DEVICE[@]}" shell am force-stop "$PACKAGE"
launch
snapshot_preferences "after_force_stop"
cmp "$OUT/persistence/before_force_stop.xml" \
    "$OUT/persistence/after_force_stop.xml" \
    > "$OUT/logs/force-stop-persistence-diff.log"
screenshot "after_force_stop"

if [[ -n "$UPGRADE_APK" ]]; then
  [[ -f "$UPGRADE_APK" ]]
  sha256sum "$UPGRADE_APK" > "$OUT/logs/upgrade-apk.sha256"
  # apkanalyzer is required to prevent a same-version reinstall being mislabeled
  # as an upgrade. Use the Android SDK cmdline-tools/bin directory in PATH.
  command -v apkanalyzer >/dev/null
  BASE_CODE="$(apkanalyzer manifest version-code "$APK")"
  NEW_CODE="$(apkanalyzer manifest version-code "$UPGRADE_APK")"
  ((NEW_CODE > BASE_CODE))
  snapshot_preferences "before_upgrade"
  "${ADB_DEVICE[@]}" install -r "$UPGRADE_APK" 2>&1 \
    | tee "$OUT/logs/install-upgrade.log"
  launch
  snapshot_preferences "after_upgrade"
  cmp "$OUT/persistence/before_upgrade.xml" \
      "$OUT/persistence/after_upgrade.xml" \
      > "$OUT/logs/upgrade-persistence-diff.log"
  screenshot "after_upgrade"
else
  echo "NOT RUN: --upgrade-apk was not supplied" \
    > "$OUT/logs/upgrade-status.txt"
fi

if ((ALLOW_REBOOT)); then
  snapshot_preferences "before_reboot"
  "${ADB_DEVICE[@]}" reboot
  "$ADB" -s "$DEVICE" wait-for-device
  until [[ "$("${ADB_DEVICE[@]}" shell getprop sys.boot_completed | tr -d '\r')" == "1" ]]; do
    sleep 2
  done
  echo "Unlock the device if required, then press Enter to continue."
  read -r
  launch
  snapshot_preferences "after_reboot"
  cmp "$OUT/persistence/before_reboot.xml" \
      "$OUT/persistence/after_reboot.xml" \
      > "$OUT/logs/reboot-persistence-diff.log"
  screenshot "after_reboot"
else
  echo "NOT RUN: reboot requires explicit --reboot" \
    > "$OUT/logs/reboot-status.txt"
fi

"${ADB_DEVICE[@]}" shell dumpsys package "$PACKAGE" \
  > "$OUT/logs/device-after.txt"
"${ADB_DEVICE[@]}" logcat -d -v threadtime > "$OUT/logs/logcat-final.txt"
sha256sum "$OUT"/screenshots/*.png > "$OUT/screenshots/SHA256SUMS"

cat <<EOF
Evidence collection finished: $OUT
Review integration-test.log, native stats, preference diffs, PNG files and
logcat before assigning acceptance statuses. Uncollected checks remain NOT RUN.
EOF
