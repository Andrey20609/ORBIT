# ORBIT Visual Lab Sprint 03 — Android proof package

Этот документ описывает воспроизводимую проверку изолированного Visual Lab. Наличие сценария не означает PASS: результат определяется только фактически сохранёнными логами, PNG и assertions. Не подключайте реальные почтовые аккаунты, Exchange, серверы, AI SDK, рекламу или облачную аналитику. Все данные приложения являются демонстрационными.

## Windows 11 + Android Emulator или USB

1. Установите Flutter 3.47.9, JDK 17 и Android SDK с platform 37, build-tools 36.0.0, platform-tools, NDK 28.2.13676358 и CMake 3.22.1. Откройте проект `orbit_visual_lab`, а не основной ORBIT.
2. Для emulator создайте x86_64 AVD с hardware graphics и установите `ORBIT-Visual-Lab-0.3.0+3-debug-x86_64.apk`. Для физического ARM64-телефона включите USB debugging и используйте `ORBIT-Visual-Lab-0.3.0+3-debug-arm64-v8a.apk`.
3. В PowerShell перейдите в корень проекта и проверьте `adb devices -l`. Устройство должно быть разблокировано. Никакие корпоративные логины, пароли и токены не требуются.
4. Запустите `flutter pub get`, затем `flutter analyze` и `flutter test`. Это host-проверки, не заменяющие Android runtime.

### Renderer, lifecycle и persistence

```powershell
powershell -ExecutionPolicy Bypass -File tool\android_validation.ps1 `
  -Apk .\ORBIT-Visual-Lab-0.3.0+3-debug-arm64-v8a.apk `
  -Out .\validation\android-s03-run01
```

Для emulator замените APK на x86_64. Сценарий устанавливает стандартный APK, запускает `integration_test/app_test.dart`, сохраняет Android PNG/logcat/native stats, отправляет `am send-trim-memory`, затем сравнивает SharedPreferences до и после force-stop/relaunch.

Проверка upgrade выполняется только с APK, у которого versionCode строго больше базового. Например, базовый `0.3.0+3` и отдельно штатно собранный тестовый `0.3.1+4`:

```powershell
powershell -ExecutionPolicy Bypass -File tool\android_validation.ps1 `
  -Apk .\base-0.3.0+3.apk `
  -UpgradeApk .\upgrade-0.3.1+4.apk `
  -Out .\validation\android-s03-upgrade
```

Обычный reinstall одной версии не засчитывается как upgrade. Reboot выполняется только после явного флага `-AllowReboot`; без него статус остаётся NOT RUN.

### Что проверять в raw evidence

- Static: отсутствует native surface, Static/Eco остаётся видимым.
- Rive: `rivLoaded=true`, выбранные `OrbitMark`/`OrbitAtmosphere` и `OrbitLoop`, `pulseAvailable=true`, после tap `pulseCount>0`.
- Filament: `initialized=true`, `sceneReady=true`, `hasSwapChain=true`, `renderedFrames>0`, дельта за 5 секунд >0, `lastError=null`, `actualRenderer=filament`.
- Pause/resume: native `paused` действительно меняется; после смены renderer registry пуст, то есть release выполнен.
- Low Memory: тяжёлый renderer удалён, виден Static и сохранена причина fallback.
- Persistence: XML до/после совпадает, а PNG показывает восстановленный выбранный UI.
- `Fallback: Static` или PNG fallback не являются доказательством Rive/Filament runtime.

## Локальный QA ZIP из приложения

Откройте **Settings → ORBIT Diagnostics / Visual Lab** и нажмите **Capture QA ZIP**. Это единственное действие запускает последовательный capture Static → Rive → Filament. Подождите завершения; исходные quality/motion/renderer будут восстановлены. Нажатие **Share local ZIP** открывает системный share sheet только по явному действию пользователя.

ZIP содержит:

- `screenshots/static.png`, `rive.png`, `filament.png` — PixelCopy реального Android window;
- `capture_manifest.json` — requested/actual renderer для каждого PNG;
- device/build info без serial, аккаунтов, ANDROID_ID и геолокации;
- демонстрационные настройки, runtime stats и checks;
- app-process filtered logcat с redaction email/token/password/authorization/API key;
- `SHA256SUMS.txt` и SHA-256 всего ZIP в UI.

Внешней фоновой выгрузки в коде нет. Если Rive/Filament перешёл в Static, это записано как fallback, а не PASS. QA capture не является 120-секундным performance benchmark.

## Performance: 3 × 120 секунд после warm-up

Используйте одно физическое устройство, один APK, профиль, маршрут, brightness и состояние питания. Выберите Balanced (цель 30 FPS, budget 33.33 ms) и нужный renderer перед каждым прогоном. Для каждого renderer выполните три независимых прогона:

```powershell
powershell -ExecutionPolicy Bypass -File tool\android_performance.ps1 `
  -Renderer static -Duration 120 -Warmup 15 -Out .\validation\perf-static-01
# Повторить static-02/static-03, затем rive-01/02/03 и filament-01/02/03.
```

Для Ultra используйте `-BudgetMs 16.67`. Linux/macOS эквивалент всей последовательности: `bash tool/android_performance_suite.sh`.

Каждый run сохраняет `gfxinfo framestats`, meminfo/PSS, `/proc`, CPU, доступные GPU counters, battery, thermal, logcat и PNG. `analyze_performance.py` рассчитывает P50/P95 frame time, jank и RAM PSS только из этих файлов. Если frame records отсутствуют, статус остаётся NOT MEASURED и скрипт завершается с ошибкой анализа. Startup, GPU time, энергия, нагрев, crash/ANR и выводы о стабильности требуют соответствующих raw данных; значения не подставляются.
