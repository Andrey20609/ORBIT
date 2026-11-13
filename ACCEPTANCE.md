# Приёмка ORBIT Visual Lab — Sprint 02

Дата: 2026-11-06. Версия: `0.2.0+2`, package `app.orbit.orbit_visual_lab`.

Статусы: **PASS** — проверка фактически выполнена и завершилась успешно; **FAIL** — выполненная проверка обнаружила дефект; **NOT RUN** — сценарий не выполнялся; **NOT MEASURED** — значение не измерялось. Наличие кода, теста или скрипта само по себе не означает PASS.

## Матрица

| Область | Фактический результат | Ограничение доказательства |
|---|---|---|
| Изолированный Visual Lab, основной ORBIT не изменён | PASS по границе работ | Изменения находятся только в `orbit_visual_lab`; интеграция в основное приложение не выполнялась |
| Десять функциональных поверхностей | PASS в host suite | Linux Flutter tests, не Android device review |
| Четыре профиля One/Atelier/Flow/Zen | PASS в host suite и 4 golden-кадрах | Соответствие native 3D референсам на Android не подтверждено |
| Почта, письмо, Compose, Calendar, Tasks | PASS в host suite и 5 golden-кадрах | Только локальные demo-данные; backend отсутствует |
| RU/EN/DE/FR/ES через ARB + `gen_l10n` | PASS в host suite | Device review перевода и системных настроек — NOT RUN |
| Текст 100/130/150/200%, ширина 320 px, адаптивные размеры | PASS в host suite | Не заменяет проверку physical Android |
| Round-trip всех persisted fields, defaults, rollback, очередь записей | PASS в host suite | Force-stop/reboot/upgrade — NOT RUN |
| Auto → Balanced, Ultra только explicit opt-in | PASS в host suite | Sustained device capability не измерялась |
| Static при Eco/background/Low Memory/Battery Saver/Reduce Motion/motion off | PASS в host/MethodChannel tests | Реальные Android Activity и `onTrimMemory` — NOT RUN |
| Процедурный Static под Rive/Filament, guarded fallback | PASS на уровне Dart/widget contracts | Ошибки реального GPU/Surface и Android fallback — NOT RUN |
| Rive atmosphere и Pulse | PASS на уровне asset/widget contracts | Rive Android runtime — NOT RUN |
| Ленивая инициализация Filament и release contract | Код и Android contract test подготовлены | Android runtime, pause/resume/release — NOT RUN |
| Kotlin/Filament compile и стандартный debug APK | **PASS** — чистый `flutter build apk --debug --target-platform android-arm64`, exit 0, 2026-11-06 12:38 UTC | Непосредственный output Gradle/Flutter, без перепаковки; `validation/logs/delivery-flutter-build-apk-debug-arm64.log` |
| APK package/version/signature/ZIP/assets/ABI | **PASS** — `0.2.0+2`, v2 debug signature, CRC, оба Rive, `.filamat`, `kernel_blob.bin`, только arm64-v8a | 110394777 байт; SHA-256 `ce292e52c4a6d481278a9fad8ed7b49e519303007459047dfc29bbb8b6c953b7`; структурная проверка не является установкой или запуском |
| `integration_test/app_test.dart` на Android | NOT RUN | `adb devices -l` пуст; `/dev/kvm` недоступен |
| Static/Rive/Filament screenshots/video на Android | NOT RUN | Девять переданных PNG имеют источник Flutter golden test |
| Force-stop/relaunch persistence | NOT RUN | Подготовлен `tool/android_validation.sh`, но он не выполнялся |
| Reboot persistence | NOT RUN | Не выполнялось |
| Upgrade APK с большим versionCode без очистки данных | NOT RUN | Обычный reinstall не засчитывается как upgrade |
| A/B/C performance Static/Rive/Filament | NOT RUN / NOT MEASURED | См. `PERFORMANCE.md` |
| Crash/ANR soak, UI jank, энергия и нагрев | NOT RUN / NOT MEASURED | Значения не экстраполируются из host tests |
| iOS native 3D, IPA и device tests | NOT RUN | Android является приоритетом этого этапа |

## Фактические сведения о сборках

- Финальный APK собран стандартной командой `flutter build apk --debug --target-platform android-arm64` после `flutter clean`. AGP `abiFilters` и `packaging.jniLibs.excludes` убирают неподдерживаемые ABI из локальных Filament AAR во время обычной сборки; готовый APK не перепаковывался.
- Отдельная чистая universal debug-сборка ранее завершилась PASS; её source SHA-256 был `d312f3baefe879dff92ada5669fa4bb867ab56de5c920fac6919e34c269beabd`, размер — 210 358 180 байт. Этот universal файл **не входит в передачу** и не подменяет проверку финального arm64 APK.
- Попытка release-сборки не завершилась созданием итогового APK. Release **не имеет статуса PASS и не входит в передачу**.
- Промежуточные arm64-кандидаты с лишними Filament ABI были отклонены структурной проверкой. Финальный APK содержит только `arm64-v8a`.

## Итог приёмки

Sprint 02 принимается только в границах фактически выполненных host-проверок и подтверждённой стандартной сборки, указанной выше. **Production acceptance и Android graphics acceptance не объявляются выполненными.** Для них обязательны physical Android run, визуальная проверка реальных Static/Rive/Filament-кадров, lifecycle/persistence scenarios и повторяемые performance measurements.

Golden-кадры улучшенного procedural landscape не выдаются за работающий нативный 3D-движок. Фотореалистичность и соответствие approved references на Android остаются предметом device review.

## Обязательные исходные ограничения

- «Не использовать реальные почтовые аккаунты на этом этапе.»
- «Не требовать корпоративных логинов, паролей и токенов.»
- «Все демонстрационные данные должны иметь соответствующую маркировку.»
- «Не реализовывать фиктивные сообщения об успешной отправке писем или подключении серверов.»
- «Не менять рабочие модули основного проекта без необходимости.»
- «Не утверждай, что на компьютере пользователя были изменены файлы, если у тебя нет фактического доступа к этой системе.»
- «Не выполнять платные действия, публикацию, удаление чужих данных или изменение системной безопасности без разрешения.»
- «Не задавай промежуточных вопросов, если техническое решение можно принять самостоятельно.»
- «Не прекращать работу после создания архитектуры, демонстрационных картинок или первого экрана.»
- «Нельзя отмечать тест PASS, если он не выполнялся.»

## Дополнительные ограничения Sprint 02

- «Не создавай проект с нуля — продолжай существующий Visual Lab. Основное приложение ORBIT не изменяй.»
- «Обязательно собери APK стандартным способом.»
- «Не выдавай статические картинки за работающий 3D-движок.»
- «Не заявляй успешные тесты без фактического выполнения.»
- Платные действия, публикация и интеграция в основной ORBIT не выполнялись.
- Корпоративные учётные данные не использовались.
- APK не перепаковывался, `kernel_blob.bin` не заменялся.
- Секреты, лишние кэши и большие временные build-файлы не включаются в исходный ZIP.

## Следующий обязательный gate

1. Установить непосредственно собранный APK на physical Android.
2. Выполнить `integration_test/app_test.dart` и `tool/android_validation.sh`.
3. Проверить Rive Pulse, Filament `initialized/sceneReady/lastError`, pause/resume/release и guarded Static fallback.
4. Отдельно выполнить force-stop/relaunch, reboot и настоящий upgrade с большим versionCode.
5. Провести A/B/C минимум в трёх повторениях по методике `PERFORMANCE.md`.
6. Только после этого рассматривать перенос по `INTEGRATION_GUIDE.md`; публикация в объём не входит.
