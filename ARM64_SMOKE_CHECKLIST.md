# ORBIT 0.5.4 — smoke test на физическом ARM64

Текущий статус Kimi: **NOT RUN**, физическое устройство не подключено. Инструкция для владельца; не считать её выполнением теста. `tool/arm64_smoke_collect.sh` и `.ps1` отклоняют ABI, отличный от `arm64-v8a`, и QEMU, чтобы кадры эмулятора не были выданы за физический ARM64.

1. Подготовьте ARM64-телефон, `ORBIT_0.5.4_android_arm64.apk` и ADB. Запишите модель, Android, ABI и GPU. Не вводите настоящие пароли/переписку: приложение DEMO.
2. Установите `adb install -r ORBIT_0.5.4_android_arm64.apk`. Если подпись отличается от предыдущей, не удаляйте старую версию до backup. Запустите ORBIT и проверьте отсутствие чёрного экрана/crash.
3. Откройте Today, Mail, Calendar, Tasks, Settings. Откройте письмо по ID и вернитесь системным Back. Убедитесь, что нет `Page Not Found`, `GoException` или overflow.
4. В Settings → Interface выберите One, Atelier, Flow и Zen. Проверьте читаемость и сделайте системные кадры. Выполните `adb shell am force-stop app.orbit.orbit_visual_lab` и подтвердите сохранение профиля/языка.
5. В Compose введите три уникальные строки и **не нажимайте Save**. Системный Back → откройте Compose заново: все строки должны быть восстановлены. Затем сверните приложение, сделайте force-stop и повторите проверку.
6. Создайте задачу и событие через UI. После force-stop/hолодного запуска проверьте их в списках. При обновлении v9→v10 используйте `adb install -r` без очистки данных и повторите draft/task/event checks.
7. В Visual Lab выберите Rive. Проверьте `riveAssetLoaded`, state machine advancing, Pulse и раздельные `nativeArtboardAnimationProven`/`flutterTransformActive`. Не считайте Static или один Transform native PASS.
8. Выберите Filament. Проверьте initialized/sceneReady/hasSwapChain и рост renderedFrames/framesDelta5Seconds. Сверните/разверните приложение, проверьте release/recreate и Static fallback. Сохраните t0/t2 через `adb exec-out screencap -p`.
9. Проверьте Eco/Static, поворот экрана, текст 200 % и ширину 320 dp. При сбое переключитесь на Static и убедитесь, что интерфейс остаётся доступен. Для 120-секундного прогона записывайте frame count, PSS и батарею/температуру без выдуманных значений.
10. Сохраните `adb logcat -d -v time > ORBIT_ARM64_logcat.txt`, модель/GPU/ABI, APK SHA-256, кадры и статусы PASS/PARTIAL/FAIL/NOT RUN. Передайте их на независимый аудит. До такого подтверждения версия остаётся `READY_FOR_ARM64_DEVICE_TEST`, не `ARM64_VERIFIED`.
