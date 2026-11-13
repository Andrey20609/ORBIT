# ORBIT Visual Lab 0.4.0+4 — Android Sprint 04

Документ описывает воспроизводимую проверку именно Sprint 04. Он не является подтверждением выполненного Android прогона. На момент сохранения пакета результатов APK и Android runtime evidence отсутствуют; итоговый статус — **BLOCKED**, а не DONE.

## 1. Изоляция и версия

- Проект: `orbit_visual_lab`.
- Ветка: `sprint04`.
- Baseline: Sprint 03, commit `b9aef8459d4bc695085d06fe17660394b1705b86`.
- Целевая версия: `0.4.0+4`.
- Основной ORBIT не изменяется и не объединяется с Visual Lab.
- Используются только локальные демонстрационные данные. Почта, Exchange, серверы, облачная аналитика, рекламные SDK и внешний ИИ не подключаются.

## 2. Штатная сборка APK

Требуются Flutter 3.47.9, JDK 17, Android SDK с API 37.0, NDK 28.2.13676358 и CMake 3.22.1. Сборка выполняется последовательно, одним Gradle worker:

```bash
flutter pub get
flutter build apk --debug --target-platform=android-arm64
cp build/app/outputs/flutter-apk/app-debug.apk \
  ORBIT-Visual-Lab-0.4.0+4-debug-arm64-v8a.apk

flutter build apk --debug --target-platform=android-x64
cp build/app/outputs/flutter-apk/app-debug.apk \
  ORBIT-Visual-Lab-0.4.0+4-debug-x86_64.apk
```

APK не перепаковываются вручную; `kernel_blob.bin` и другие файлы внутри готовых пакетов не заменяются. Ограничение ABI выполняется штатной конфигурацией AGP в `android/app/build.gradle.kts`.

Для каждого фактически созданного APK нужно сохранить:

1. SHA-256 и размер;
2. `apkanalyzer manifest version-name`, `version-code`, `min-sdk`, `target-sdk`;
3. ZIP/CRC verification;
4. список `lib/<abi>` и нативных библиотек Rive/Filament;
5. подпись и отсутствие посторонних ABI.

В этом прогоне ни один Sprint 04 APK не был сохранён. Поэтому перечисленные проверки имеют статус **NOT RUN**, а не PASS или FAIL.

## 3. Строгий Android native test

На разблокированном online Android device:

```bash
flutter test integration_test/app_test.dart -d <device-id>
```

Успешный Rive gate обязан подтвердить:

- `actualRenderer == rive`;
- загруженный `.riv`, artboard и state machine `OrbitLoop`;
- `stateMachineAdvancing == true` и положительный `stateMachineAdvanceCount`;
- доступный trigger `Pulse` и `pulseCount > 0` после взаимодействия.

Успешный Filament gate обязан подтвердить:

- существование native `filament-native-surface`;
- `initialized == true`, `sceneReady == true`, `hasSwapChain == true`;
- `renderedFrames > 0` и положительный `framesDelta5Seconds`;
- `actualRenderer == filament` и `lastError == null`;
- освобождение native view в background и создание нового rendering scene после resume.

Static fallback не засчитывается как успешный Rive или Filament runtime. Static/Eco и lifecycle fallback проверяются отдельными assertions внутри Android integration suite как поведение отказоустойчивости, а не как native 3D proof.

Полный сборщик evidence:

```bash
bash tool/android_validation.sh \
  --apk /path/to/ORBIT-Visual-Lab-0.4.0+4-debug-arm64-v8a.apk \
  --upgrade-apk /path/to/higher-version.apk \
  --out validation/sprint04-android
```

Опция `--reboot` разрешена только при явном согласии на reboot конкретного устройства. Без неё reboot test остаётся NOT RUN.

## 4. Screenshots, lifecycle и persistence

Для завершения Gate 3 необходимы реальные Android screenshots Static, Rive и Filament, logcat, native stats, pause/resume, `onTrimMemory`, force-stop/relaunch и сравнение SharedPreferences. Upgrade test должен использовать APK с бо́льшим `versionCode`; простая повторная установка той же версии не считается upgrade.

Для Sprint 04 эти операции не выполнялись. Flutter golden tests, host screenshots и прежние Sprint 03 PNG не используются как замена Android evidence.

## 5. Performance

На одном физическом устройстве, без смены build/profile/display conditions:

```bash
bash tool/android_performance_suite.sh validation/sprint04-performance
```

Метод: warm-up, затем 3 × 120 секунд для Static, Rive и Filament; raw framestats, P50/P95, jank, RAM PSS, доступные battery/thermal данные. Balanced budget — 33,33 мс. При отсутствии raw capture результат не вычисляется и не экстраполируется.

Sprint 04 performance: **NOT MEASURED**.

## 6. Текущий блокер

Временная `/tmp` среда repeatedly очищалась: исчезали Flutter/JDK/Android SDK, build workspace, Gradle caches и незавершённые build logs. После последнего восстановления одновременно исчезли уже подготовленные SDK и workspace. `/dev/kvm` также отсутствует; предыдущие программные emulator launches оставались offline с TCG CPU feature errors.

Достигнут лимит трёх материально сходных неудач восстановления/сборки. Повторные попытки остановлены согласно протоколу. Следующее продолжение требует стабильной executable build environment и online Android runtime; нельзя выдавать host-only результат за завершение Android gates.
