# ORBIT 0.5.2 — выполнение ТЗ Evidence and Stability

База: ORBIT `0.5.1+7`, архив `2026-11-07_ORBIT_0.5.1_FULL_SOURCE_AND_EVIDENCE.rar` проверен. SHA-256 source ZIP совпадает с манифестом: `2779e750988e2f8f0571909cc79bebb77ff409206c80ba9ba51acace886ffd22`. Проект не пересоздаётся.

| Требование | Действие | Статус |
|---|---|---|
| ORB051-01 Artifacts | Полные APK/source/screenshots/reports/SHA в отдельной папке 0.5.2 | IN PROGRESS: оба APK проверены; финальная упаковка |
| ORB051-02 Startup consistency | Generation guards против поздней перезаписи после timeout + user edit | DONE: db4b33b + startup_consistency_test |
| ORB051-03 Appearance failure | Видимое уведомление и retry именно отклонённого оформления | DONE: `_retrySettings` + widget tests |
| ORB051-04 Filament watchdog | Stats timeout, frame watchdog, pause/resume, fallback diagnostics | DONE: код и Android contract |
| ORB051-05 Rive fallback | `flutter-transform-fallback` не повышать до native keyed motion | DONE: явная маркировка + x86_64 release Static UI PASS |
| ORB051-06 Motion evidence | Системные ADB-кадры + scene-region SHA + ABI/GPU/UTC/actualRenderer | DONE: `scene_differ=True` для Rive/Filament; PixelCopy не используется как motion proof |
| ORB051-07 Tests/UX/persistence/localization/startup/ARM64 | Полные проверки среды и честные NOT RUN для физического устройства | DONE локально: analyze PASS, host 54/54, 6 matrices, navigation, process death, v7→v8, 3 cold starts; physical ARM64 NOT RUN |
| ORB051-08 Drive delivery | Upload/read-back с hash verification, иначе BLOCKED | BLOCKED: HTTP 401/sign-in; локальная выдача |

Новый независимый аудит `2026-11-07_ORBIT_0.5.1_Independent_Audit.md` в локальном `03_CHATGPT_AUDITS` отсутствует. Выполняются все обязательные пункты ТЗ и предыдущие ORB05-01–ORB05-17.
