#!/usr/bin/env bash
# Three measured 120-second runs per renderer, after warm-up, on one device.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/validation/performance-suite-$(date -u +%Y%m%dT%H%M%SZ)}"
BUDGET_MS="${JANK_BUDGET_MS:-33.33}"
mkdir -p "$OUT"
cat > "$OUT/METHOD.txt" <<EOF
utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
renderer_runs=static,rive,filament
repetitions=3
measurement_seconds=120
warmup_seconds=${WARMUP_SECONDS:-15}
jank_budget_ms=$BUDGET_MS
Use one physical device, one build, one profile and unchanged display/brightness.
Balanced target: 30 fps (33.33 ms). For an explicit Ultra run use JANK_BUDGET_MS=16.67.
No result is inferred when raw capture or analysis fails.
EOF
for renderer in static rive filament; do
  printf '\nSelect %s / Balanced in ORBIT Visual Lab, keep the same route open, then press Enter.' "$renderer"
  read -r
  for repetition in 1 2 3; do
    RUN="$OUT/${renderer}-run-${repetition}"
    bash "$ROOT/tool/android_performance.sh" "$renderer" 120 "$RUN"
    python3 "$ROOT/tool/analyze_performance.py" "$RUN" --budget-ms "$BUDGET_MS" \
      > "$RUN/analysis.log"
  done
done
find "$OUT" -name 'derived-metrics.json' -print0 | sort -z | xargs -0 sha256sum > "$OUT/SHA256SUMS"
printf 'Raw suite and derived metrics: %s\n' "$OUT"
