# ORBIT 0.5 — реестр дефектов и ограничений

Статусы: OPEN / IN PROGRESS / FIXED / BLOCKED. Приоритеты: P0 критический, P1 высокий, P2 средний, P3 низкий.

| ID | P | Статус | Описание | Результат / следующий шаг |
|---|---|---|---|---|
| ORBIT-05-001 | P1 | FIXED | Android graphics, navigation и persistence не были подтверждены | Оба integration tests PASS; Rive/Filament/lifecycle и реальные screenshots проверены |
| ORBIT-05-002 | P1 | BLOCKED | Google Drive требует authenticated session | Все материалы сохраняются локально; выгрузить после появления доступа, не обходить вход |
| ORBIT-05-003 | P2 | FIXED | Android Gradle не принимал Cyrillic project path | Использован ASCII `subst O:` для того же проекта |
| ORBIT-05-004 | P2 | FIXED | Linux goldens не совпадали с Windows rasterization | Кадры визуально проверены, обновлены; 45/45 PASS |
| ORBIT-05-005 | P2 | FIXED | В 0.4 отсутствовали event editor, task card, text scale и persistent local state | Реализовано и покрыто новыми тестами |
| ORBIT-05-006 | P2 | OPEN | Release signing использует debug key исходного проекта | Допустимо только для пользовательского тестирования, не для публикации; указано в release notes |
| ORBIT-05-007 | P3 | OPEN | Производительность, энергия и температура физического устройства не измерены | Не выдавать emulator metrics за physical-device results |
| ORBIT-05-008 | P1 | FIXED | Rive header получал infinite height; Pulse блокировался scroll; Static удерживал ресурсы | Исправлены constraints, translucent listener и lightweight Static header; integration PASS |
| ORBIT-05-009 | P0 | FIXED | x86_64 release падал в Impeller/Rive GL driver | Для x86_64 release включены Skia и запрет Rive init; установка, запуск и Zen persistence PASS |
| ORBIT-05-010 | P2 | FIXED | Обычный запуск мог остаться на splash; release lint исчерпал Metaspace | Startup timeouts/diagnostics и Gradle memory увеличены; installed launch PASS |
| ORBIT-05-011 | P2 | OPEN | Физический ARM64 device отсутствует | ARM64 APK статически проверен; install и GPU runtime на physical ARM64 — NOT RUN |
| ORBIT-05-012 | P1 | FIXED | Поздние startup Future могли перезаписать более новые пользовательские изменения | Generation guards в appearance/local state; delayed-Future regression tests PASS |
| ORBIT-05-013 | P1 | FIXED | Сбой сохранения оформления не имел отдельного UI и retry терял отклонённое значение | Раздельные предупреждения и retry rejected settings; widget tests PASS |
| ORBIT-05-014 | P2 | FIXED | При 320dp/200% были overflow заголовка и испанского `_ModeChip` | Constrained headers/timestamps/chips; Android 5 locales × 4 profiles × 5 tabs PASS |
| ORBIT-05-015 | P2 | FIXED | `PixelCopy.window` возвращал полностью прозрачные PNG для разных сцен | QA export отклоняет alpha=0/пустые кадры; PixelCopy не используется как motion proof, системные ADB PNG/video и scene hashes сохраняются |

| ORB-102 | P1 | PARTIAL | Скроллинг тормозил из-за дорогих background effects | BackdropFilter только Flow Ultra; layered intervalP50 300→183.33ms, rasterP95 112.38→47.07ms. Это не гладкий FPS; плавность не принята, physical ARM64 NOT RUN |
| ORB-103 | P1 | FIXED | Даты не выбирались, January/year переход был неверен | Week/Month onTap + selected EventList + clamp; 4/4 widget tests PASS |
| ORB-104 | P1 | FIXED | Light/Dark/System не менял сцены и не реагировал на систему | Light palettes + darkTheme + platformBrightness + persistence; 14/14 tests PASS |
| ORB-105 | P2 | FIXED (CANDIDATE UX) | Графика выглядела примитивной low-poly заставкой | Layered photographic scenes и PBR textures с реальными Android кадрами; художественная приёмка остаётся за пользователем |
| ORB-106 | P2 | PARTIAL | Filament дороже layered на SwiftShader и требует контроля качества | Native cap 15 FPS, sceneReady/SwapChain/cameraInputCount подтверждены; physical performance NOT MEASURED |
| ORB-107 | P1 | FIXED | Повторный integration `takeScreenshot` зависал перед Filament | Каждый захват выполняется после `tester.pump` и ограничен timeout; graphics integration 9/9 PNG и все assertions PASS |

Известных открытых P0 нет. Бывший P0 ORBIT-05-009 закрыт фактическим release launch на x86_64 и повторными integration tests.

## PR-001…PR-014 — Photoreal independent audit (0.5.5+11)

| ID | P | Статус | Результат на текущий момент |
|---|---|---|---|
| PR-001 | P1 | FIXED (X86_EVIDENCE) | Flow Light/Dark разделены по effectiveBrightness; contrast/pixel tests и Android 3 режима PASS |
| PR-002 | P1 | PARTIAL / PERFORMANCE NOT PASSED | rebuild/Flow blur/layers оптимизированы; emulator raster P95 55.96–97.43ms выше budget, physical smoothness NOT RUN |
| PR-003 | P1 | FIXED | per-frame timestamps, UI/raster P50/P95/P99 и fail-closed gfxinfo; unit tests PASS |
| PR-004 | P1 | BLOCKED | Physical ARM64 отсутствует; runtime/performance/thermal/battery NOT RUN |
| PR-005 | P2 | FIXED (CANDIDATE) | Независимые far/foreground alpha layers с разным parallax; user visual gate pending |
| PR-006 | P2 | PARTIAL | Отдельные Flow assets, Zen без скал, profile composition/cards различны; user artistic acceptance pending |
| PR-007 | P2 | FIXED | Immutable aspect snapshots; regression test: local task не пересобирает Today scene |
| PR-008 | P2 | FIXED (X86_EVIDENCE) | Pre-rendered Flow glow, 3 fine curves вместо 7 blur paths, BackdropFilter только Ultra вне scroll |
| PR-009 | P2 | OPEN (VISUAL_NOT_VERIFIED) | Camera eye/input counters меняются, но Lab before/after показывает белую/пустую карточку без доказанной 3D-сцены; native rendering требует отдельного исправления/физической проверки |
| PR-010 | P2 | FIXED (TECHNICAL MEDIA PASS) | 4 MP4 normalize/ffprobe/full decode и 19 PNG decode/non-blank PASS; фактические durations сохранены, visual acceptance отдельно |
| PR-011 | P2 | FIXED | 0.5.5+11, update без wipe, SharedPreferences byte-identical, build metadata integration PASS |
| PR-012 | P2 | PARTIAL | Новые PSS captures; physical RAM/thermal/battery NOT RUN |
| PR-013 | P3 | PARTIAL | Lab stateMachineAdvanceCount=74, Pulse отдельно подтверждён app_test; `nativeArtboardAnimationProven=false` сохраняется |
| PR-014 | P3 | OPEN (TEST-ONLY) | Debug signing и CC0 provenance сохранены; production signing не внедрять |
