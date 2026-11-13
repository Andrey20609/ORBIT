# Performance — Sprint 02

Дата статуса: 2026-11-06. Проект: изолированный `orbit_visual_lab`, пакет `app.orbit.orbit_visual_lab`.

## Фактический статус

На момент подготовки передачи `adb devices -l` возвращает пустой список, `/dev/kvm` недоступен. Ни physical Android, ни online Android emulator не были доступны. Поэтому сравнительный device-тест Static/Rive/Filament не выполнялся.

| Режим одного экрана Today | Android run | FPS / frame time P50/P95 | RAM PSS | GPU | Энергия | Нагрев | Crash/ANR soak |
|---|---|---|---|---|---|---|---|
| A — Static/Eco, procedural Flutter | NOT RUN | NOT MEASURED | NOT MEASURED | NOT MEASURED | NOT MEASURED | NOT MEASURED | NOT RUN |
| B — Rive/Balanced | NOT RUN | NOT MEASURED | NOT MEASURED | NOT MEASURED | NOT MEASURED | NOT MEASURED | NOT RUN |
| C — Filament/Balanced | NOT RUN | NOT MEASURED | NOT MEASURED | NOT MEASURED | NOT MEASURED | NOT MEASURED | NOT RUN |

Холодный старт, время первого кадра, jank, sustained performance и отсутствие блокировки Flutter UI на Android также **NOT MEASURED / NOT RUN**. Счётчики в коде, успешный `assembleDebug`, host-тесты, golden-кадры и наличие ADB-скриптов не являются измерением производительности.

## Что подтверждено без устройства

- Чистый `flutter analyze --no-pub`: PASS.
- Чистый `flutter test --no-pub`: 36/36 PASS на Linux x64 Flutter test environment.
- Стандартный чистый `flutter build apk --debug --target-platform android-arm64`: **PASS**; 110394777 байт, только arm64-v8a. Это подтверждение сборки, не benchmark. Подробности: `docs/TESTING.md` и `ACCEPTANCE.md`.
- Официальные Filament AAR прошли проверку SHA-256. Это проверка целостности входных файлов, не runtime benchmark.

## Воспроизводимая A/B/C-методика

Использовать один physical Android, один APK, один профиль ORBIT, маршрут Today, одинаковые orientation, brightness, состояние заряда и температурный старт. Не сравнивать debug с profile/release и не сравнивать разные устройства как A/B/C.

1. Установить APK без очистки данных и дождаться стабильного состояния устройства.
2. Для каждого режима вручную выбрать renderer в приложении. Первый аргумент скрипта — только подпись оператора, он не переключает renderer.
3. Выполнить не менее трёх повторений каждого режима, по 120 секунд захвата после одинакового warm-up. Сохранять каждый прогон отдельно.
4. Проверить по PNG/logcat, что подпись соответствует реально показанному режиму. Static fallback после ошибки Filament нельзя считать Filament sample.
5. Рассчитывать метрики только из сохранённых raw files с описанным методом. Не заполнять отсутствующие GPU/energy counters предположениями.

```bash
bash tool/android_performance.sh static 120 validation/perf-static-01
bash tool/android_performance.sh static 120 validation/perf-static-02
bash tool/android_performance.sh static 120 validation/perf-static-03

bash tool/android_performance.sh rive 120 validation/perf-rive-01
bash tool/android_performance.sh rive 120 validation/perf-rive-02
bash tool/android_performance.sh rive 120 validation/perf-rive-03

bash tool/android_performance.sh filament 120 validation/perf-filament-01
bash tool/android_performance.sh filament 120 validation/perf-filament-02
bash tool/android_performance.sh filament 120 validation/perf-filament-03
```

Каждый каталог содержит `METHOD.txt`, device/package properties, `gfxinfo-framestats.txt`, `gfxinfo-summary.txt`, периодические `meminfo` и `/proc` samples, CPU, battery до/после, thermal до/после, logcat, start/end PNG и SHA-256 PNG.

## Правила будущего отчёта

- Frame timing: указать источник `gfxinfo framestats`, число кадров, единицы и алгоритм P50/P95; не приравнивать автоматически dumped FPS к sustained FPS.
- Память: указать метрику (`TOTAL PSS`, private dirty или другую), момент выборки и диапазон по повторениям.
- GPU: публиковать только реально доступные на устройстве counters с именем источника; отсутствие доступа оставить `NOT MEASURED`.
- Энергия и нагрев: не выводить watts/°C из косвенных признаков. Если доступен только battery/thermal status, сообщать именно его, без выдуманной точности.
- Stability: отдельно фиксировать длительность soak, число циклов pause/resume/release, logcat crash/ANR и необработанные исключения.
- Итог сравнивать по всем повторениям с разбросом, а не выбирать лучший единичный запуск.
