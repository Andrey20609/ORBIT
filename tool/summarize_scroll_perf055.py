from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055_stabilize"
LOG = OUT / "logs" / "scroll-perf-profile.txt"


def main() -> None:
    results = {}
    for label, payload in re.findall(r"\[ORBIT perf\] (\w+[-\w]*)=(\{[^\n]+\})", LOG.read_text(encoding="utf-8", errors="replace")):
        if label == "summary":
            continue
        results[label] = json.loads(payload)
    if not results:
        raise SystemExit("No scroll profile metrics found")
    summary = {
        "environment": "ANDROID_X86_EMULATOR; sdk_gphone64_x86_64; Android 15; SwiftShader",
        "status": "DIAGNOSTIC_ONLY_NOT_PASS",
        "refreshRateHz": 60.000003814697266,
        "physicalArm64": "NOT RUN",
        "metrics": results,
    }
    (OUT / "runtime" / "performance-summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Captured {len(results)} profile configurations; performance acceptance NOT RUN")


if __name__ == "__main__":
    main()
