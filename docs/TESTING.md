# Фактические результаты проверок

Дата финального прогона: 2026-11-06. Проект: изолированный `orbit_visual_lab`, demo package `app.orbit.orbit_visual_lab`.

Статусы: **PASS** — команда действительно выполнена и завершилась успешно; **FAIL** — выполненная проверка обнаружила дефект; **NOT RUN** — сценарий не выполнялся; **NOT MEASURED** — значение не измерялось; **NOT DELIVERED** — артефакт не создан и не передаётся.

## Среда

- Flutter 3.47.9, framework revision `c197ca5199e9ee5661e865596c9c07294dfab51c`, engine revision `89c39edfdfae2949f6806e4a315c0c08522238b7`.
- Dart 3.13.7, DevTools 2.60.0.
- Android SDK 37.0, build-tools 36.0.0, platform-tools 37.0.1, Java 17, Gradle 9.3.1 и NDK 28.2.13676358.
- Юнит-, widget- и golden-тесты выполнялись на Linux x64 во Flutter test environment, не на Android device.
- Финальная чистая последовательность запущена в новом executable workspace из актуального исходного проекта, без прежних `build/`, `.dart_tool/` и Gradle project caches.

## Чистые проверки и финальная сборка

Выполнялись последовательно, без параллельного тяжёлого test/build процесса:

```bash
flutter clean
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --target-platform android-arm64
```

| Проверка | Результат | Evidence |
|---|---|---|
| `flutter clean` | PASS | `validation/logs/delivery-flutter-clean.log`, exit 0 |
| `flutter pub get` | PASS | `validation/logs/delivery-flutter-pub-get.log`, exit 0 |
| `dart format --output=none --set-exit-if-changed ...` | PASS | `validation/logs/delivery-dart-format.log`, exit 0 |
| `flutter analyze --no-pub` | PASS — `No issues found!` | `validation/logs/delivery-flutter-analyze.log`, exit 0 |
| `flutter test --no-pub` | PASS — **36/36** | `validation/logs/delivery-flutter-test.log`, exit 0 |
| `flutter build apk --debug --target-platform android-arm64` | PASS — exit 0, 2026-11-06 12:38 UTC | `validation/logs/delivery-flutter-build-apk-debug-arm64.log`, `.exit` |

Общий журнал финальной чистой сборки и проверки: `validation/logs/delivery-build-final-arm64-sequence.log`. Host-проверки выполнены в чистой последовательности 12:27–12:30 UTC; после packaging-only исправления повторены `flutter clean` и стандартная arm64-сборка 12:35–12:38 UTC.

## Охват 36 host-тестов

| Область | Подтверждённый охват |
|---|---|
| Основные маршруты и навигация | Today, Mail, detail/back, branches, unknown route recovery |
| Профили и состояние | One/Atelier/Flow/Zen, смена оформления без потери Compose draft |
| Persistence | Round-trip всех полей, safe defaults, repository recreation, отложенные/concurrent writes, rollback |
| Качество и lifecycle | Auto/Balanced/Ultra, Static constraints, renderer switches, MethodChannel power/memory signals |
| Eco и native view | При Eco нативный Filament `AndroidView` не создаётся |
| Задачи | Создание локальной задачи, обновление списка и прогресса, локализованные metadata |
| Почта | Reply/Reply all формируют локализованные draft subject/body; сетевая отправка не выполняется |
| Локализация | RU/EN/DE/FR/ES, смена языка, ThemeMode и восстановление настроек |
| Adaptive layout | 320×640, 390×844, 840×1000; secondary routes и offline host test |
| Текст | Все основные поверхности при 100/130/150/200% |
| Quick actions и Brain | Локальные действия и явно маркированный demo response |
| Golden rendering | Четыре Today-профиля и пять дополнительных поверхностей, 390×844 |

Golden PNG находятся в `test/goldens/` и `screenshots/`. Их источник — **Flutter golden test**. Это не Android screenshots, не Rive Android runtime и не Filament native frames.

## Дефекты, найденные и исправленные в Sprint 02

1. Auto автоматически выбирал Ultra. Теперь Auto консервативно разрешается в Balanced, Ultra требует explicit opt-in.
2. Системные ограничения проверяются до explicit Balanced/Ultra, поэтому Eco/background/Low Memory/Battery Saver/Reduce Motion/motion off дают Static.
3. `Filament.init()` больше не вызывается безусловно из `MainActivity`; инициализация выполняется лениво при создании 3D view.
4. Ошибка Filament configuration удаляет PlatformView и оставляет Static-подложку вместо потенциального чёрного AndroidView.
5. Независимые записи настроек заменены последовательной очередью, чтобы старая медленная запись не перезаписывала новое состояние.
6. `OrbitEnvironment.updateShouldNotify()` сравнивал identity mutable `OrbitAppState`, из-за чего новая задача существовала в state, но список и прогресс не обновлялись. Dependents теперь уведомляются при корневой пересборке; regression PASS.
7. Локальные задачи получили стабильные `local-list` и `no-due`; Reply использует локализованные subject/body. Regression PASS.
8. Даты Today/Calendar переведены на `clock`, демонстрационные записи локализуются по стабильным ID.

Это закрытые дефекты с повторными host-проверками, а не открытые FAIL. Успех host suite не подтверждает Android native runtime.

## Android build и структурная проверка APK

Финальная стандартная сборка: **PASS**, exit 0. Непосредственный `build/app/outputs/flutter-apk/app-debug.apk` скопирован без изменений в `ORBIT_Visual_Lab_Sprint02.apk`; `cmp` подтвердил идентичность. Ручная перепаковка и замена `kernel_blob.bin` не выполнялись.

| Проверка | Фактический результат |
|---|---|
| Размер | 110394777 байт |
| SHA-256 | `ce292e52c4a6d481278a9fad8ed7b49e519303007459047dfc29bbb8b6c953b7` |
| Package / version | `app.orbit.orbit_visual_lab`, versionCode 2, versionName 0.2.0 |
| Подпись | APK Signature Scheme v2: PASS; один Android Debug signer; это не production signature |
| ZIP CRC | PASS — ошибок сжатых данных нет |
| ABI | Только `arm64-v8a` |
| Rive | `orbit_mark.riv` и `orbit_atmosphere.riv` присутствуют |
| Filament | `libfilament-jni.so`, `libfilament-utils-jni.so`, `orbit_pbr.filamat`, `orbit_unlit.filamat` присутствуют для arm64 |
| Flutter engine | `lib/arm64-v8a/libflutter.so`, `lib/arm64-v8a/librive_native.so` и `kernel_blob.bin` присутствуют |

Evidence: `validation/logs/apk-sha256.log`, `apk-size.log`, `apk-badging.log`, `apk-signature.log`, `apk-zip-crc.log`, `apk-contents.txt`, `apk-verification.txt` и `apk-verification.exit=0`.

AGP packaging filters удаляют `armeabi-v7a`, `x86` и `x86_64` из локальных AAR в обычной package task. Два промежуточных кандидата с лишними Filament ABI не прошли проверку и не являются итоговой поставкой.

Отдельная чистая universal debug-сборка 2026-11-06 06:52 UTC завершилась PASS: source SHA-256 `d312f3baefe879dff92ada5669fa4bb867ab56de5c920fac6919e34c269beabd`, размер 210 358 180 байт. Она не входит в передачу. Попытка release-сборки не завершилась итоговым APK; release PASS не заявляется.

## Android device matrix

| Проверка | Статус |
|---|---|
| `integration_test` на Android device/emulator | NOT RUN |
| Rive runtime и Pulse на Android | NOT RUN |
| Filament runtime, Engine/Scene/Camera, Surface/SwapChain и реальные кадры | NOT RUN |
| Pause/resume, resize, low memory и release на Android | NOT RUN |
| Persistence после adb force-stop/relaunch | NOT RUN |
| Persistence после перезагрузки ОС | NOT RUN |
| Persistence после upgrade APK с большим versionCode без очистки данных | NOT RUN |
| Android screenshots/video | NOT RUN |
| Physical Android run | NOT RUN |
| Profile APK | NOT RUN |
| Release APK | NOT DELIVERED — отдельная попытка не завершилась итоговым APK; PASS не присваивался |
| iOS build/IPA | NOT RUN |

На 2026-11-06 повторный `adb devices -l` вернул пустой список; `/dev/kvm` недоступен. Подготовленные `integration_test/app_test.dart`, `tool/android_validation.sh` и `tool/android_performance.sh` не считаются выполненными тестами. Оба shell-скрипта прошли только `bash -n`; `shellcheck` не установлен, поэтому shellcheck — NOT RUN. Evidence: `validation/logs/android-scripts-syntax.log`.

Официальные Filament 1.79.0 AAR прошли SHA-256: `validation/logs/filament-aar-checksums.log`. Это подтверждает целостность локальных AAR, но не работу Filament runtime.

## Производительность

FPS, P50/P95 frame time, холодный запуск, RAM PSS, GPU time/utilization, энергия, нагрев, crash/ANR и sustained stability: **NOT MEASURED / NOT RUN**. Подробный статус и A/B/C-методика находятся в корневом `PERFORMANCE.md`.
