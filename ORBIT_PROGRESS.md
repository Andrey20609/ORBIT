# ORBIT 0.5 — ход разработки

## Выполнено

- Восстановлен последний найденный архив ORBIT Visual Lab `0.4.0+4`: `Kimi_Agent_ORBIT Visual Engine Development (2).zip`, SHA-256 `edd5ba1eb986c815c8dacee429b5ff024d16f4b9cf588cb967b481dbcc55f7aa`.
- Создан Git checkpoint исходников `06d1833`; новый проект не создавался.
- Реализованы локальные задачи, события, прочитанные письма и черновики с восстановлением через `SharedPreferences`.
- Добавлены создание события, переключение дат, карточка задачи, приоритеты и статусы.
- Добавлены сохраняемый масштаб текста, диагностика, контракты будущих модулей и защищённое хранилище секретов.
- Обновлены RU/EN/DE/FR/ES ARB и сгенерированные Flutter-локализации.
- Версия приложения: `0.5.0+6`. Изменения сохранены в commit `5fec137e16945757818676262393f9f709fc442a`.

## Фактические проверки

- `dart analyze`: PASS.
- `flutter analyze --no-pub` из ASCII-пути `O:\orbit_visual_lab`: PASS, No issues found.
- Полный host Flutter suite: PASS 45/45 после визуальной проверки и обновления Windows golden-кадров.
- Новые functional tests: создание события, карточка задачи, приоритет/статус, масштаб текста и local-state round-trip — PASS.
- Адаптивные проверки 320 px и системный текст 100/130/150/200% — PASS в host suite.
- Android emulator: `emulator-5554`, Android 15, `x86_64`, boot completed.

## Обнаруженные ошибки и исправления

- Android Gradle отклонил не-ASCII путь `D:\Кими`. Тот же source tree подключён как `O:` через `subst`; непереносимые дубли и новый проект не создавались.
- `flutter analyze` в Cyrillic-пути однажды завершился LSP FormatException; `dart analyze` и штатный `flutter analyze` из ASCII-пути проходят.
- Пять Linux golden-кадров отличались на Windows на 5–6%. Layout визуально совпадал; кадры перегенерированы и повторный полный suite прошёл.
- В новых widget tests исправлены off-screen tap и неверный ключ настройки; приложение не требовало обходных изменений.

- На Android исправлена бесконечная высота Rive header, Pulse проведён через translucent pointer listener, Static освобождает Rive-ресурсы.
- Добавлены тайм-ауты startup native/storage initialization. Обычный installed APK запускается на главный экран; startup log подтверждает все этапы.
- Release lint потребовал увеличения Gradle Metaspace; лимит скорректирован, ARM64 release собран.

## Фактические Android-результаты

- `integration_test/app_test.dart`: **PASS**. Rive loaded/artboard/state machine/advancing/Pulse=1; Filament initialized/sceneReady/SwapChain/renderedFrames=110 и рост frames, pause/resume/release — подтверждены.
- `integration_test/navigation_test.dart`: **PASS**. Письмо по ID, back, bottom navigation, task card, settings и четыре профиля.
- Получено 13 настоящих Android screenshots 1080×2400 через MediaStore; четыре профиля и Static/Rive/Filament визуально проверены.
- Обычный installed debug APK запущен, выбран Zen через UI. После force-stop/relaunch SharedPreferences XML побайтово совпал (`a69797df…840`), Zen восстановлен.
- ARM64 release `0.5.0+6`: PASS build, version/label/signature/ZIP CRC/ABI/assets. SHA-256 `ea5c2f9137a0e56873eb48483df122852c8110d68d8481d6ccc4a9e843c36192`.
- x86_64 release: PASS build/install/launch. SHA-256 `30a9779e7cad82d40ee80bdc89faab9d12665ea09ced99482a558f4b0a405003`.
- x86_64 release Impeller/Rive GL driver crash исправлен безопасным Skia/Static fallback. Повторные integration tests под fallback: PASS.
- Upgrade `+5` → `+6`: install Success, Zen сохранён. Перезапуск AVD без очистки диска также сохранил Zen.
- Source commit release-кода и safe fallback: `30bddda`.

## Текущий статус

APK, source, validation и screenshots готовятся к локальной передаче. Известных открытых P0 нет. Physical ARM64 runtime и performance остаются NOT RUN/NOT MEASURED. Drive по-прежнему требует вход; upload не заявляется.

## Следующий этап

Сформировать `ORBIT_0.5_source.zip`, `ORBIT_0.5_screenshots.zip`, `ORBIT_0.5_SHA256SUMS.txt`, скопировать обязательные материалы в `ORBIT_AI_EXCHANGE/02_RESULTS_FROM_KIMI` и зафиксировать BLOCKED только по Drive upload/read-back.


## ORBIT 0.5.2+8 — Evidence and Stability (2026-11-07)

- Исходный ORBIT 0.5.1 source ZIP проверен по SHA-256 `2779e750988e2f8f0571909cc79bebb77ff409206c80ba9ba51acace886ffd22`; проект продолжен без пересоздания.
- `db4b33b`: добавлены startup generation guards, раздельные ошибки загрузки/сохранения и корректный retry отклонённого оформления.
- `485cfb3`: Filament integration test ожидает реальную положительную дельту кадров, без подмены `null` нулём.
- `63c2c88`: исправлены compact/large-text layouts и испанский `_ModeChip`; добавлена регрессионная проверка 320dp/200%.
- Host: `flutter analyze` PASS; полный suite **54/54 PASS**, exit code 0.
- Android motion: системные ADB-кадры Rive/Filament различаются как полностью, так и в области сцены; записаны UTC, ABI, GPU, actualRenderer и SHA.
- Android localization: все шесть конфигураций 320/390dp при 100/150/200% — PASS для 5 языков, 4 оформлений и 5 основных разделов.
- Android navigation: PASS; четыре оформления и основные экраны проверены. Финальные кадры получены с обычного release APK через ADB UI.
- UI-created process-death persistence: PASS; SharedPreferences 2656 байт побайтово совпал, SHA-256 `552a30abb28f0b0d8f088068fdfac7b07f9709dfe8e5091689a96ab4e6fd3f58`.
- Update debug v7 → release v8 без wipe: PASS; задача, событие и черновик видны после обновления.
- Release cold starts: Dart main→first frame 201/220/209 мс; `am start -W TotalTime` 4604/4530/4775 мс.
- x86_64 release Rive Static fallback: PASS без SIGABRT. Оба APK `0.5.2+8` собраны, подпись/CRC/ABI проверены.
- Google Drive и ссылка на новый аудит требуют вход (HTTP 401). Upload/read-back и получение нового аудита — NOT RUN; локальные материалы сохраняются.

Следующий этап: завершить упаковку и read-back локальных SHA-256. Внешние gates: Drive upload/read-back и physical ARM64 — NOT RUN до появления соответствующего доступа.


## ORBIT 0.5.3+9 — Final Shell Hardening (2026-11-08)

- Независимый аудит OR052-01…15 и полное ТЗ прочитаны из прямого ZIP. Проект продолжен в ветке `orbit/0.5.3`, baseline `4ceb536`, новый ORBIT не создавался.
- `ad5a01d`: DraftState, подтверждённое/неподтверждённое состояние, последовательная запись, debounce и flush на system Back/pause/dispose; write-failure retry.
- `ab07d45`: raw `.corruptBackup`, запрет записи повреждённых JSON до confirmed reset; `OrbitBootstrap` показывает branded shell до graphics init.
- `1d2c1f2`: DEMO Reply all/Forward и disabled formatting; раздельные Rive diagnostics и Filament timeout fallback test.
- Полный host suite: **63/63 PASS**, `flutter analyze`: PASS.
- Android x86_64: `app_test.dart` PASS, включая Rive flags/Filament lifecycle; `navigation_test.dart` PASS.
- Расширенная Android localization matrix содержит titles всех разделов и 200% Detail/Compose/Interface states. Первые конфигурации 320dp/100% и 320dp/150% PASS; остальные выполняются.
- Physical ARM64: NOT RUN. Подготовлена исполняемая `ORBIT_ARM64_USER_SMOKE_TEST.md`.


## ORBIT 0.5.3 — Android evidence и release (2026-11-08)

- Все шесть расширенных localization matrices PASS; Interface Gallery 320/200 overflow исправлен и покрыт regression test.
- OR052-01 Android: системный Back без Save PASS; force-stop PASS; XML 2656 байт побайтово совпал (`5b99c9e1…653ed`).
- Update v8→v9 release: OR052 draft и baseline task/event восстановлены через UI.
- Motion: Rive/Filament `scene_differ=True`; Rive native keyed proof остаётся PARTIAL.
- Startup: branded 32/32/35 мс, interactive Today 151/130/171 мс; `am start -W` 1471/2453/1573 мс.
- Получены 36 основных release-экранов One/Atelier/Flow/Zen и Rive Static fallback без SIGABRT.
- Оба APK 0.5.3+9 собраны штатно и проверены по version/signature/CRC/ABI. Physical ARM64 NOT RUN.
- Следующий шаг: единый FULL_PACKAGE с CRC/read-back SHA-256 и прямая передача на независимый аудит.


## ORBIT 0.5.4+10 — Persistence Gate и runtime evidence (2026-11-08)

- Независимый аудит OR053-01…14 и полное ТЗ прочитаны. Ветка `orbit/0.5.4`, baseline `d626bd3`.
- `171fa2f`: полная типизированная схема, атомарная загрузка, fail-closed persistence, pending reconciliation и backup export.
- `6c1c3d0`: pixel alpha/bins/luma validation и `QA_CAPTURE_FAILED`; PixelCopy больше не используется как motion proof.
- Полный host suite: **79/79 PASS**, `flutter analyze`: PASS.
- Android graphics contract и navigation: PASS.
- Draft force-stop 0/100/250/500 мс: все четыре сценария PASS, поля восстановлены. Граница неконтролируемой потери процесса задокументирована в `ORBIT_054_CRASH_WINDOW.md`.
- Обе release APK `0.5.4+10` собраны и статически проверены. Physical ARM64 — NOT RUN.
- Все шесть localization matrices PASS: 5 языков × 4 профиля × 320/390dp × 100/150/200%, deep routes на 200%.
- `8bddfe0`: нативный release журнал activeViews, collectors upgrade/motion/startup и упаковка evidence.
- Финальный installed-release stress: **10/10 PASS**, Rive=Static fallback, crash/ANR не найдены, финальный Static `activeViews=0`. PSS 176776→186283 KB на эмуляторе.
- Installed motion: Rive/Filament `scene_differ=True`, 5s MP4 сохранён. Первая fake-async попытка дала одинаковые PNG и не принята как evidence. Rive native artboard остаётся PARTIAL.
- 10 release cold starts: branded P50/P95 47.5/131ms, data 57.5/183ms, interactive 169/233ms, `am start -W` 3884.5/4104ms.
- Получены 36/36 release-экранов; все 78/78 PNG прошли pixel validation.
- Update v9 release → v10 debug → v10 release без wipe: все поля черновика, baseline task/event **PASS**.
- Подготовлены validation, release notes и `READY_FOR_DEVICE_TEST.md`.
- FULL_PACKAGE: обязательные 12 файлов, nested ZIP CRC, read-back и SHA-256 **PASS**; 36 release PNG и installed motion video присутствуют, source secrets/build/.git исключены.
- Финальный статус: `READY_FOR_ARM64_DEVICE_TEST`. Следующие gates: независимый аудит после передачи ZIP и физический ARM64 — NOT RUN.

## ORBIT photoreal + Qwen integration (2026-11-08)

- Ветка `feature/orbit-photoreal-055` создана от проверенного 0.5.4+10 (`32900e1`), прежняя 0.5.5 работа сохранена отдельно. Проект не пересоздавался.
- Реализованы layered photographic One/Atelier/Flow/Zen, отдельный Flow light/glass, static lists и scroll pause. CC0 assets и лицензии в `assets/photoreal`.
- Filament получил UV/diffuse/normal/roughness/mipmaps через официальный matc 1.79.0. Native sceneReady/SwapChain и cameraInputCount=3 подтверждены.
- Qwen candidates не копировались целиком. Календарь: onTap дат, selected EventList, month/year clamp. Тесты 4/4 PASS.
- Light/Dark/System: light palettes, darkTheme, platformBrightness во вложенных widgets и persistence. Тесты 14/14 PASS.
- BackdropFilter ограничен Flow Ultra. Layered intervalP50 300→183.33ms, rasterP95 112.38→47.07ms на x86_64. Это не physical performance verdict.
- Host suite 83/83 и golden refresh PASS. Android integration и release сборка выполняются.

## Android verification и release gate (2026-11-09)

- Повторный `app_test.dart` выявил зависание четвёртого `takeScreenshot`: плагин ожидал следующий `FlutterImageView` frame. Добавлен обязательный `tester.pump` перед каждым захватом и timeout на screenshot/MediaStore; graphics/lifecycle integration теперь **PASS**, все 9 PNG получены.
- `navigation_test.dart`: **PASS**, получены 36 Android PNG для четырёх оформлений и основных разделов.
- `QaExportManager.captureWindow`: добавлены timeout 10 секунд, защита от двойного completion и явно маркированный `View.draw.fallback`; прозрачные/пустые изображения по-прежнему отклоняются.
- Обычный debug APK собран отдельно от integration test entrypoint и установлен. UI-сценарий Dark/Light/System **PASS** для каждого режима после force-stop/relaunch; `selected=true` проверено в XML, шесть системных screenshots визуально проверены.
- `flutter analyze`: **PASS**. Полный host suite: **101/101 PASS**.
- Следующий этап: release ARM64/x86_64, installed-release smoke, статические проверки APK и полный ZIP. Physical ARM64 остаётся NOT RUN, физическая плавность NOT MEASURED.

## Release APK и комплект (2026-11-09)

- Штатно собраны ARM64 (39998432 bytes) и x86_64 (42443336 bytes) release APK `0.5.4+10`.
- ARM64 SHA-256 `64ceba9c0966b1475eb2e9270566483f489340023c20bdb9f2efea747549e877`; x86_64 SHA-256 `7b99220b4d89f349605e858ab72ff58f71dc9ed4568b5943f53af42a63faa848`.
- `tool/verify_photoreal055_apks.py`: badging, только целевой ABI, ZIP CRC, APK v2 signature и обязательные graphics assets — PASS для обеих APK. Подпись Android Debug test-only.
- x86_64 release установлен без wipe и запущен; System theme восстановлен, XML `selected=true`, release PNG визуально проверены.
- Получены 45 канонических integration PNG. Общий принятый media set: 63/63 PNG pixel validation PASS и 5 MP4 containers; playback NOT RUN (ffprobe отсутствует).
- Подготовлены validation, release notes, `PHOTOREAL_READY.md` и обновлённый release checklist. Статус `READY_FOR_ARM64_DEVICE_TEST`: физическая плавность и художественная приёмка не заявляются.
- `tool/package_photoreal055.py`: FULL_PACKAGE создан; обязательный media/source состав, nested ZIP CRC и read-back SHA-256 PASS. Независимый `sha256sum -c` подтвердил все 13 обязательных артефактов. Фактический FULL_PACKAGE SHA сохранён в отдельном `*_SHA256.txt` рядом с архивом.
- Следующее действие: физический ARM64 test и повторный независимый аудит. Плавность и художественная приёмка остаются открытыми gates.

## ORBIT 0.5.5+11 — stabilization (2026-11-09)

- Прочитаны независимый аудит и полное ТЗ; создана ветка `fix/orbit-photoreal-055-stabilize` от `2240023`. Входной audit ZIP SHA-256 `1ed9d5ffaa203d264f4661e279783313cdd0e03d1484746c36bb806fc93f836c`.
- `d38faa9`: version `0.5.5+11`, Android BuildConfig versionCode/flavor/git hash, Diagnostics actualRenderer.
- `912968f`: отдельные Flow Light/Dark фоны, WCAG contrast tests и rendered pixel goldens. Первый тест выявил 2.958:1 для accentSecondary; цвет исправлен, порог не снижен.
- `f5dbe52`: per-frame `rasterFinishWallTime`, UI/raster P50/P95/P99, source/n/refresh/rejected/gaps. `gfxinfo` Total=0 и absurd timestamps отклоняются; Dart 4/4 и Python 3/3 tests PASS.
- `c4e022e`: aspect-specific immutable snapshots (appearance/quality/data), real far/foreground photo layers, pre-rendered Flow light/dark glow, scroll-aware BackdropFilter. Локальная задача не пересобирает Today scene; golden captures ждут реальную загрузку assets.
- `9217b1d`: видимый camera path, cameraEyeX/Y/Z, Android assertion изменения камеры, build metadata integration. Persistence error snapshot восстанавливает retry; diagnostics host Timer устранён.
- Update `0.5.4+10 → 0.5.5+11`: task/event/draft PASS без wipe; SharedPreferences before/after SHA-256 `5140b116bf8b6a632f769e5895ba4e400260d42a54588237453c4f1703d1998a` побайтово совпадает.
- `flutter analyze`: PASS. Полный host suite: **111/111 PASS**. Android graphics/navigation integration: **PASS**. Light/Dark/System force-stop: **3/3 PASS**.
- Physical ARM64: **NOT RUN**. Текущая работа: Android matrix/calendar/Night mode, performance/video evidence и release APK/review ZIP. RELEASE READY не объявляется без G1/G2/G4/G5.

## Второй комплект Qwen и profile evidence (2026-11-09)

- Выборочно интегрированы общие date helpers, sorted agenda, semantic date labels/keys, canonical palette cache и resume brightness. Старые environment/app/glass и псевдокод не перенесены; demo-date convention сохранён.
- `library` находится до импортов, `DemoEvent` и `Color` имеют явные импорты. Добавлены calendar math, palette cache и scroll profile tests; `pumpAndSettle` при постоянной анимации больше не используется.
- Полный host suite: **136/136 PASS**, `flutter analyze`: PASS. Android graphics/navigation: PASS.
- `flutter drive --profile`: все пять конфигураций PASS. `OrbitFrameMetrics` содержит per-frame rasterFinishWallTime, UI build/raster/totalSpan P50/P95/P99, refresh=60Hz, over-budget по каждой метрике.
- Это не performance PASS: x86_64 emulator rasterP95 Layered One 65.24ms, Flow Balanced 56.50ms, Flow Ultra 55.96ms, Rive 97.43ms, Filament 91.35ms. Физическая плавность NOT RUN.
- Filament Lab before/after показывает белую/пустую карточку и не доказывает видимую сцену. PR-009 возвращён в OPEN/VISUAL_NOT_VERIFIED; TextureView эксперимент откачен, readPixels probe удалён. Native camera counters и pause/resume работают, но не заменяют видимое изображение.
- Update/reboot persistence и System Night Light→Dark подтверждены. Profile/theme matrix: 24 PNG; Live System Night luminance 216.32→50.46.
- Android localization: 5 языков × 4 профиля × основные разделы PASS при 100%, 150% и 200%. Для 150% использованы system=150%/app=100%; для 200% — system=200%/app=130% (effective 2.6). Системный font scale восстановлен в 1.0.
- Android navigation/profile suite **2/2 PASS**. Leap-day: March 2024 → 31 марта → назад с clamp на 29 февраля → выбор 28/29 февраля; чистый Android PNG сохранён. ADB coordinate strategy заменена semantic Flutter integration после диагностики test-isolate clock и off-screen taps.
- Rive Lab collector: `stateMachineAdvanceCount=74`; Pulse подтверждён отдельным app_test. Четыре MP4 normalize/ffprobe/full decode PASS, 19 PNG decode/non-blank PASS; фактические длительности 1.70/1.83/2.03/4.20 s. Это не visual acceptance.
- Code/evidence tools checkpoint: `2ba67ce`. Чистые последовательные release builds x86_64/ARM64 завершены без параллельных integration/Gradle задач.
- ARM64: 40,634,088 bytes, SHA-256 `b053ac4f1bfe7839182733f1e1bcf4830a324e742bf8190cf3488241ce27715b`; versionCode/ABI/CRC/v2/assets STATIC PASS. Physical ARM64 NOT RUN.
- x86_64: 43,078,992 bytes, SHA-256 `b56b8cb73e7a87e754e3d172129666b45f6fcba55381814ec44332f7736bfec5`; STATIC PASS, install без wipe/launch/System theme PASS.
- Source/review ZIP содержат обязательные исходники, 19 PNG и 4 MP4, логи/JSON, CHANGED_FILES, PR-001–014 и ARM64 checklist. Nested CRC/read-back SHA-256 PASS. Следующие gates: независимый аудит ChatGPT, физический ARM64 и пользовательская художественная приёмка — NOT RUN.
