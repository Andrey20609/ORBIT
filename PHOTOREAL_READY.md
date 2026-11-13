# ORBIT photoreal — READY_FOR_ARM64_DEVICE_TEST

Дата: 2026-11-09. Подготовлены единый исходный проект, ARM64/x86_64 APK, фотографические ассеты и лицензии, реальные Android x86_64 кадры/видео, логи и отчёты.

## Подтверждено исполнителем

- `flutter analyze`: PASS; host suite: **101/101 PASS**.
- Календарь: 4/4; Light/Dark/System host: 14/14; Android UI после force-stop: 3/3 режима PASS.
- Android graphics/lifecycle и navigation integration: PASS.
- x86_64 release установлен без wipe и запущен; System theme восстановлен.
- **63/63 PNG** непрозрачные и непустые; 5 MP4 screenrecord присутствуют, playback **NOT RUN**.
- Обе APK: version `0.5.4+10`, APK v2 signature, CRC, ABI и обязательные graphics assets PASS.
- SHA-256 ARM64: `64ceba9c0966b1475eb2e9270566483f489340023c20bdb9f2efea747549e877`.
- SHA-256 x86_64: `7b99220b4d89f349605e858ab72ff58f71dc9ed4568b5943f53af42a63faa848`.

## Не подтверждено

- **Physical ARM64: NOT RUN.** Нельзя объявлять `ARM64_VERIFIED` или полное выполнение пользовательских критериев.
- **Physical FPS/frametime/RAM/thermal/battery: NOT MEASURED.**
- **Плавность не принята:** x86_64 Layered `intervalP50=183.33 ms`; это не гладкий FPS.
- **Художественная приёмка:** выполняется пользователем по реальному устройству, не по одному статическому изображению.
- **Rive native artboard:** PARTIAL, `nativeArtboardAnimationProven=false`.
- **MP4 playback:** NOT RUN; сохранены container и screenrecord logs.
- Подпись Android Debug — test-only, не production. Google Drive upload/read-back — NOT RUN.

## Следующий gate

1. Проверить SHA-256 ARM64 APK по `ORBIT_0.5.4_photoreal_SHA256SUMS.txt`.
2. Установить `ORBIT_0.5.4_photoreal_android_arm64.apk` на физический ARM64 без реальных паролей и переписки.
3. Проверить One/Atelier/Flow/Zen, Light/Dark/System, календарь, навигацию, Rive/Filament/Static fallback и прокрутку; записать видео.
4. Измерить FPS/frametime/RAM/thermal/battery и сравнить Layered/Filament на целевом GPU. Не переносить emulator metrics на физическое устройство.
5. Передать `2026-11-09_ORBIT_0.5.4_photoreal_FULL_PACKAGE.zip` и новые device evidence на повторный независимый аудит ChatGPT.

Полный отчёт: `ORBIT_0.5.4_photoreal_validation.md`. Известных открытых P0 нет, но обязательные физические и художественные проверки остаются открытыми.
