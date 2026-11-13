# ORBIT 0.5.1 — план устранения независимого аудита

База: существующий ORBIT `0.5.0+6`, не новый проект. Источник замечаний: `2026-11-07_ORBIT_0.5_Independent_Audit (1).md`.

Ограничение входа: полное ТЗ по Drive file ID `1i8VLolI99NgJwzfJuGitpwYeQiL39AMd` перенаправляет на Google sign-in. Локальной копии нет. До получения ТЗ работа ведётся по всем 17 пунктам аудита; COMPLETE без сверки полного ТЗ не объявляется.

| ID | Действие | Статус |
|---|---|---|
| ORB05-01 | Fail-closed Rive capability fallback и тест отсутствующего system channel | DONE: unit + release Static |
| ORB05-02 | Не создавать Rive FileLoader при недоступном runtime; release UI test Static↔Rive | DONE: lazy loader + release UI evidence |
| ORB05-03 | Filament stats timeout, frame watchdog, release resources и GPU hang test | DONE: watchdog unit + native lifecycle PASS |
| ORB05-04 | Доказать Rive elapsed-time advancement и разные системные кадры | DONE: elapsed stats + ADB frames differ (flutter-transform fallback) |
| ORB05-05 | Системные screencap/screenrecord Filament с синхронными native stats | DONE: ADB frames differ + native stats |
| ORB05-06 | Task/event/draft через обычный UI → force-stop/relaunch → upgrade | DONE: XML byte equality + UI evidence |
| ORB05-07 | Наблюдаемая ошибка save, failing flush, UI retry/notice и repository failure test | DONE: repository + widget retry PASS |
| ORB05-08 | ARM64 smoke/regression при наличии устройства; иначе точный NOT RUN | BLOCKED: нет ARM64 |
| ORB05-09 | Authenticated Drive upload/read-back; иначе точный BLOCKED | BLOCKED: sign-in |
| ORB05-10 | Compatibility matrix и поддерживаемая стратегия x86 fallback | DONE: docs/COMPATIBILITY.md |
| ORB05-11 | Branded first frame, сокращение critical startup path, cold-start measurements | DONE: branded splash + 3 cold starts (393/421/732 ms) |
| ORB05-12 | Зафиксировать applicationId/signing policy без нарушения upgrade | DONE: stable ID + upgrade evidence |
| ORB05-13 | Android localization/text/adaptive matrix | DONE: 5 locales, profiles, 1.95x text PASS |
| ORB05-14 | Явная data security boundary: demo-only plaintext, запрет реальных писем | DONE: documented boundary + secure adapter |
| ORB05-15 | Визуальная дифференциация профилей без изменения навигации | DONE: profile-specific materials, padding/radii, goldens |
| ORB05-16 | Physical performance только на устройстве; иначе NOT MEASURED | BLOCKED: нет ARM64 |
| ORB05-17 | Локальные записи после upgrade через UI/debuggable QA без root | DONE: task/event/draft UI after +6→+7 |

Порядок: сначала P1 code safety, затем Android evidence, P2/P3, финальные сборки и повторный аудит.
