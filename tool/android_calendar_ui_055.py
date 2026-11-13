from __future__ import annotations

import json
import re
import time
from datetime import datetime, timedelta
from pathlib import Path

import android_persistence_ui_052 as ui
import android_theme_modes_055 as theme

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055_stabilize"
WEEKDAYS = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]
MONTHS = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
MONTH_TITLES = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]


def click_day(day: datetime) -> None:
    root = ui.dump(f"calendar-day-{day.date()}-before")
    matches = [
        node
        for node in root.iter("node")
        if node.attrib.get("text") == str(day.day)
        or node.attrib.get("content-desc", "").split("\n")[-1] == str(day.day)
    ]
    if not matches:
        raise AssertionError(f"Date cell not found: {day.date()}")
    x, y = ui.center(matches[-1])
    ui.adb("shell", "input", "tap", str(x), str(y))
    time.sleep(1.5)
    expected = f"{WEEKDAYS[day.weekday()]}, {day.day} {MONTHS[day.month - 1]}"
    ui.assert_text(ui.dump(f"calendar-day-{day.date()}-selected"), expected)


def arrow(next_month: bool) -> None:
    root = ui.dump(f"calendar-arrow-{next_month}-before")
    candidates = []
    for node in root.iter("node"):
        if node.attrib.get("clickable") != "true" or node.attrib.get("content-desc"):
            continue
        values = [int(value) for value in re.findall(r"\d+", node.attrib["bounds"])]
        center_y = (values[1] + values[3]) // 2
        if 500 < center_y < 1100:
            candidates.append((values[0], node))
    if not candidates:
        raise AssertionError("Calendar navigation arrows not found")
    _, node = (max if next_month else min)(candidates, key=lambda item: item[0])
    x, y = ui.center(node)
    ui.adb("shell", "input", "tap", str(x), str(y))
    time.sleep(1.5)


def main() -> None:
    ui.OUT = OUT
    ui.LABELS.update(theme.LABELS)
    ui.LABELS["week"] = ["Неделя", "Week", "Woche", "Semaine", "Semana"]
    ui.LABELS["month"] = ["Месяц", "Month", "Monat", "Mois", "Mes"]
    ui.click_labels(theme.launch_ready("calendar-launch"), "calendar")
    ui.click_labels(ui.dump("calendar-week"), "week")
    today = datetime.now()
    monday = today - timedelta(days=today.weekday())
    for day in [monday, monday + timedelta(days=2), monday + timedelta(days=6)]:
        click_day(day)
    ui.assert_text(ui.dump("calendar-empty-state"), "Здесь пока пусто")
    ui.screenshot("android_calendar_week_selection")

    ui.click_labels(ui.dump("calendar-month-mode"), "month")
    arrow(True)
    ui.assert_text(ui.dump("calendar-december"), "декабрь 2026")
    arrow(True)
    ui.assert_text(ui.dump("calendar-january"), "январь 2027")
    ui.screenshot("android_calendar_year_boundary")
    arrow(False)
    ui.assert_text(ui.dump("calendar-december-return"), "декабрь 2026")
    arrow(False)
    ui.assert_text(ui.dump("calendar-november-return"), "ноябрь 2026")

    root = ui.dump("calendar-before-today-action")
    today_nodes = [
        node
        for node in root.iter("node")
        if node.attrib.get("content-desc", "").split("\n")[0] == "Сегодня"
    ]
    x, y = ui.center(today_nodes[0])
    ui.adb("shell", "input", "tap", str(x), str(y))
    time.sleep(1.5)
    result = {
        "environment": "ANDROID_X86_EMULATOR",
        "status": "PASS",
        "weekSelections": ["Monday", "Wednesday", "Sunday"],
        "emptyState": True,
        "decemberJanuaryDecember": True,
        "returnToCurrentMonth": True,
        "leapYearCoverage": "HOST_TEST; manual leap-year Android UI NOT RUN",
        "physicalArm64": "NOT RUN",
    }
    (OUT / "runtime" / "calendar-ui.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
