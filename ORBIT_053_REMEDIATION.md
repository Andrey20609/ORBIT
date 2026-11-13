# ORBIT 0.5.3 — выполнение аудита OR052

База: ORBIT `0.5.2+8`, Git `4ceb536`, ветка `orbit/0.5.3`. Аудит `2026-11-08_ORBIT_052_Independent_Audit.md` и полное ТЗ прочитаны из переданного ZIP. Проект не пересоздаётся. Google Drive не требуется; выдача — прямой ZIP в чат.

| ID | Приоритет | Действие | Статус |
|---|---|---|---|
| OR052-01 | P1 | DraftState, последовательное autosave, debounce + flush на lifecycle/Back/dispose, Android Back/force-stop/upgrade и отказ записи | DONE: Android Back/force-stop/upgrade + XML equality + write-failure tests |
| OR052-02 | P1 | Физический ARM64 или инструкция владельцу | NOT RUN: устройство не подключено; `ORBIT_ARM64_USER_SMOKE_TEST.md` готова |
| OR052-03 | P1 | Разделить native artboard proof, Flutter transform и Static | ANDROID PASS: asset/state-machine/flags; native artboard proof остаётся PARTIAL |
| OR052-04 | P2 | Filament watchdog/fallback и доступные motion evidence; physical perf отдельно NOT RUN | ANDROID x86 PASS: lifecycle, counters и `scene_differ=True`; physical perf NOT RUN |
| OR052-05 | P2 | Usable shell до необязательной graphics init, раздельные startup timings | DONE: branded 32/32/35ms, interactive 151/130/171ms, am-start отдельно |
| OR052-06 | P2 | Corrupt local JSON: raw recovery, no silent defaults overwrite | DONE: raw `.corruptBackup`, write guard, confirmed reset + tests |
| OR052-07 | P2 | Corrupt appearance JSON: raw recovery, no silent defaults overwrite | DONE: raw `.corruptBackup`, write guard, confirmed reset + tests |
| OR052-08 | P2 | Документированный план защищённого хранилища до реальной почты | DONE: `ORBIT_053_SECURITY_AND_COMPATIBILITY.md` |
| OR052-09 | P2 | Reply all/Forward/formatting: DEMO-семантика без пустых действий | DONE: recipient/forward models, disabled formatting, widget test PASS |
| OR052-10 | P2 | Сохранить ID/debug signing для v8→v9; план production identity | DONE: ID/signing unchanged; migration plan documented |
| OR052-11 | P2 | Точечные различия стилей без потери плотности | DONE локально: сохранены palette/typography/radius/density + адаптивные Interface cards; фотореалистичный rewrite вне scope |
| OR052-12 | P3 | Расширить locale assertions и сложные состояния | ANDROID PASS: все 6 matrices, section titles + 200% Detail/Compose/Interface |
| OR052-13 | P3 | Манифест кадров из фактических PNG | DONE: `tool/package_orbit053.py` вычисляет SHA/размеры непосредственно из PNG |
| OR052-14 | P3 | Зафиксировать совместимость Flutter/Kotlin/Rive без слепого upgrade | DONE: точная матрица задокументирована, предупреждение не ошибка |
| OR052-15 | P3 | Physical FPS/P95/RAM/battery/thermal | NOT RUN: устройство отсутствует |
