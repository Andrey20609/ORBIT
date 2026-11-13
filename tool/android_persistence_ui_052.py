from __future__ import annotations

import hashlib
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit052"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")
DEVICE = "emulator-5554"
PACKAGE = "app.orbit.orbit_visual_lab"
ACTIVITY = f"{PACKAGE}/.MainActivity"
TASK = "ORB05 persistence task"
EVENT = "ORB05 persistence event"
DRAFT = "ORB05 persistence draft"
BODY = "Process death evidence"

LABELS = {
    "tasks": ["Задачи", "Tasks", "Aufgaben", "Tâches", "Tareas"],
    "calendar": ["Календарь", "Calendar", "Kalender", "Calendrier", "Calendario"],
    "mail": ["Почта", "Mail", "E-Mail", "Courrier", "Correo"],
    "add_task": ["Добавить задачу", "Add task", "Aufgabe hinzufügen", "Ajouter une tâche", "Añadir tarea"],
    "add_event": ["Новое событие", "New event", "Neuer Termin", "Nouvel événement", "Nuevo evento"],
    "compose": ["Новое письмо", "New email", "Neue E-Mail", "Nouvel e-mail", "Nuevo correo"],
    "confirm": ["Добавить", "Add", "Hinzufügen", "Ajouter", "Añadir"],
    "save_draft": ["Сохранить черновик", "Save draft", "Entwurf speichern", "Enregistrer le brouillon", "Guardar borrador"],
    "more": ["Ещё", "More", "Mehr", "Plus", "Más"],
    "today": ["Сегодня", "Today", "Heute", "Aujourd'hui", "Hoy"],
    "visual_lab": ["ORBIT Visual Lab"],
    "rive": ["Rive"],
}


def adb(*args: str, binary: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(ADB), "-s", DEVICE, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
        text=not binary,
    )


def dump(name: str) -> ET.Element:
    _safe_mode(name)
    last_error = None
    for _ in range(4):
        try:
            adb("shell", "uiautomator", "dump", "/sdcard/orbit-persistence-ui.xml")
            xml = adb("exec-out", "cat", "/sdcard/orbit-persistence-ui.xml").stdout
            # uiautomator output comes from the device and must never contain
            # a DTD: forbid entity definitions outright (billion-laughs guard).
            if "<!DOCTYPE" in xml or "<!ENTITY" in xml:
                raise ET.ParseError("DTD/entities are not allowed in UI dumps")
            root = ET.fromstring(xml)
            (OUT / "persistence" / f"{name}.xml").write_text(xml, encoding="utf-8")
            return root
        except (subprocess.CalledProcessError, ET.ParseError) as error:
            last_error = error
            time.sleep(1)
    raise RuntimeError(f"UI dump failed: {last_error}")


def center(node: ET.Element) -> tuple[int, int]:
    values = [int(value) for value in re.findall(r"\d+", node.attrib["bounds"])]
    return ((values[0] + values[2]) // 2, (values[1] + values[3]) // 2)


def click_labels(root: ET.Element, group: str) -> None:
    labels = LABELS[group]
    matches = [
        node
        for node in root.iter("node")
        if node.attrib.get("text", "").split("\n")[0] in labels
        or node.attrib.get("content-desc", "").split("\n")[0] in labels
    ]
    if not matches:
        visible = [
            f"text={node.attrib.get('text')!r} desc={node.attrib.get('content-desc')!r}"
            for node in root.iter("node")
            if node.attrib.get("clickable") == "true"
        ]
        raise RuntimeError(f"Labels {labels} not found; clickable nodes: {visible}")
    x, y = center(matches[-1])
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(2.5)


def enter_text(node: ET.Element, value: str) -> None:
    x, y = center(node)
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(0.4)
    adb("shell", "input", "text", value.replace(" ", "%s"))
    time.sleep(0.6)


def edit_fields(root: ET.Element) -> list[ET.Element]:
    return [node for node in root.iter("node") if "EditText" in node.attrib.get("class", "")]


def screenshot(name: str) -> None:
    _safe_mode(name)
    path = OUT / "screenshots" / f"{name}.png"
    with path.open("wb") as stream:
        subprocess.run(
            [str(ADB), "-s", DEVICE, "exec-out", "screencap", "-p"],
            stdout=stream,
            stderr=subprocess.PIPE,
            check=True,
        )
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    print(f"screenshot={path.name} sha256={digest}")


def launch() -> None:
    adb("shell", "am", "force-stop", PACKAGE)
    time.sleep(0.5)
    result = adb("shell", "am", "start", "-W", ACTIVITY).stdout
    (OUT / "logs" / "persistence-launch.log").write_text(result, encoding="utf-8")
    time.sleep(5)


def assert_text(root: ET.Element, expected: str) -> None:
    values = [
        value
        for node in root.iter("node")
        for value in (node.attrib.get("text", ""), node.attrib.get("content-desc", ""))
    ]
    if not any(expected in value for value in values):
        raise AssertionError(f"{expected!r} absent from visible UI semantics: {values}")


def create() -> None:
    launch()
    click_labels(dump("create-today"), "tasks")
    click_labels(dump("create-tasks"), "add_task")
    root = dump("create-task-dialog")
    fields = edit_fields(root)
    if len(fields) != 1:
        raise AssertionError(f"Expected one task field, got {len(fields)}")
    enter_text(fields[0], TASK)
    click_labels(dump("create-task-entered"), "confirm")
    root = dump("create-task-added")
    assert_text(root, TASK)
    screenshot("android_persistence_create_task")

    click_labels(root, "calendar")
    click_labels(dump("create-calendar"), "add_event")
    root = dump("create-event-dialog")
    fields = edit_fields(root)
    if len(fields) != 1:
        raise AssertionError(f"Expected one event field, got {len(fields)}")
    enter_text(fields[0], EVENT)
    click_labels(dump("create-event-entered"), "confirm")
    root = dump("create-event-added")
    assert_text(root, EVENT)
    screenshot("android_persistence_create_event")

    click_labels(root, "mail")
    click_labels(dump("create-mail"), "compose")
    for index, value in enumerate(["persistence@example.demo", DRAFT, BODY]):
        root = dump(f"create-compose-{index}")
        fields = edit_fields(root)
        if len(fields) != 3:
            raise AssertionError(f"Expected three draft fields, got {len(fields)}")
        enter_text(fields[index], value)
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.8)
    click_labels(dump("create-compose-entered"), "save_draft")
    screenshot("android_persistence_create_draft")


def _safe_mode(mode: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", mode):
        raise SystemExit(f"Unsafe mode argument: {mode!r}")
    return mode


def verify(mode: str) -> None:
    mode = _safe_mode(mode)
    launch()
    click_labels(dump(f"{mode}-today"), "tasks")
    root = dump(f"{mode}-tasks")
    assert_text(root, TASK)
    screenshot(f"android_persistence_{mode}_task")
    click_labels(root, "calendar")
    root = dump(f"{mode}-calendar")
    assert_text(root, EVENT)
    screenshot(f"android_persistence_{mode}_event")
    click_labels(root, "mail")
    click_labels(dump(f"{mode}-mail"), "compose")
    root = dump(f"{mode}-draft")
    values = [node.attrib.get("text", "") for node in edit_fields(root)]
    if values != ["persistence@example.demo", DRAFT, BODY]:
        raise AssertionError(f"Draft mismatch: {values}")
    screenshot(f"android_persistence_{mode}_draft")
    print(f"{mode}: UI persistence PASS")


def release_rive() -> None:
    launch()
    click_labels(dump("release-rive-today"), "more")
    click_labels(dump("release-rive-settings"), "visual_lab")
    click_labels(dump("release-rive-lab"), "rive")
    time.sleep(3)
    root = dump("release-rive-static-fallback")
    assert_text(root, "Fallback: Static")
    screenshot("android_release_rive_static_lab")
    click_labels(root, "today")
    screenshot("android_release_rive_static_today")
    print("release-rive: Static fallback UI PASS")


def main() -> None:
    choices = {"create", "verify-restart", "verify-upgrade", "release-rive"}
    if len(sys.argv) != 2 or sys.argv[1] not in choices:
        raise SystemExit(f"Usage: android_persistence_ui_052.py {'|'.join(sorted(choices))}")
    (OUT / "persistence").mkdir(parents=True, exist_ok=True)
    (OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    (OUT / "logs").mkdir(parents=True, exist_ok=True)
    if sys.argv[1] == "create":
        create()
    elif sys.argv[1] == "release-rive":
        release_rive()
    elif sys.argv[1] == "verify-restart":
        verify("verify-restart")
    elif sys.argv[1] == "verify-upgrade":
        verify("verify-upgrade")


if __name__ == "__main__":
    main()
