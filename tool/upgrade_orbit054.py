from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import android_draft_autosave_053 as draft
import android_persistence_ui_052 as ui

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit054"
V9 = ROOT / "validation" / "orbit053" / "ORBIT_0.5.3_android_x86_64.apk"
V10_DEBUG = OUT / "ORBIT_0.5.4_debug_x86_64.apk"
V10_RELEASE = OUT / "ORBIT_0.5.4_android_x86_64.apk"


def install(path: Path) -> str:
    result = ui.adb("install", "-r", str(path))
    if "Success" not in result.stdout:
        raise RuntimeError(f"Install failed for {path.name}: {result.stdout}\n{result.stderr}")
    return result.stdout


def main() -> None:
    for directory in ["logs", "persistence", "screenshots", "runtime"]:
        (OUT / directory).mkdir(parents=True, exist_ok=True)
    ui.OUT = OUT
    draft.ui.OUT = OUT
    log = [f"utc={datetime.now(timezone.utc).isoformat()}"]
    ui.adb("shell", "am", "force-stop", ui.PACKAGE)
    ui.adb("uninstall", ui.PACKAGE)
    log.append(f"v9 install:\n{install(V9)}")
    ui.create()

    log.append(f"v10 debug install:\n{install(V10_DEBUG)}")
    draft.create()

    log.append(f"v10 release install:\n{install(V10_RELEASE)}")
    ui.launch()
    log.append(f"v10 release first launch:\n{(OUT / 'logs' / 'persistence-launch.log').read_text(encoding='utf-8')}")
    (OUT / "logs" / "upgrade-launch.log").write_text("\n".join(log) + "\n", encoding="utf-8")

    draft.verify("verify-upgrade")
    ui.click_labels(ui.dump("upgrade-v10-today"), "tasks")
    root = ui.dump("upgrade-v10-tasks")
    ui.assert_text(root, ui.TASK)
    ui.screenshot("android_054_upgrade_baseline_task")
    ui.click_labels(root, "calendar")
    root = ui.dump("upgrade-v10-calendar")
    ui.assert_text(root, ui.EVENT)
    ui.screenshot("android_054_upgrade_baseline_event")
    result = {
        "environment": "ANDROID_X86_EMULATOR",
        "from": "0.5.3+9 release",
        "through": "0.5.4+10 debug",
        "to": "0.5.4+10 release",
        "wipe_during_upgrade": False,
        "draft": draft.SUBJECT,
        "baselineTask": ui.TASK,
        "baselineEvent": ui.EVENT,
        "status": "PASS",
        "utc": datetime.now(timezone.utc).isoformat(),
    }
    (OUT / "runtime" / "upgrade-v9-v10.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("v9 -> v10 debug -> v10 release: draft/task/event PASS", flush=True)


if __name__ == "__main__":
    main()
