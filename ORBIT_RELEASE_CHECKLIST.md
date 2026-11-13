# ORBIT 0.5.4 (build 10) — контроль готовности

## Код и host

- [x] Существующий ORBIT 0.5.3+9 продолжен без пересоздания; ветка `orbit/0.5.4`.
- [x] Версия `0.5.4+10`, ID/debug signing сохранены для update.
- [x] Полная типизированная схема и атомарная загрузка без частичных списков.
- [x] Fail-closed persistence при corrupt/transient/timeout и pending reconciliation.
- [x] Negative/migration/concurrency tests; полный host suite 79/79 PASS.
- [x] Corrupt backup export и checked backup write.
- [x] Pixel alpha/bins/luma variance validation; прозрачный PixelCopy отклонён.
- [x] `flutter analyze`: PASS.

## Android x86_64 evidence

- [x] Graphics contract и navigation: PASS; финальный graphics integration test PASS.
- [x] Rive/Filament counters и installed-system motion PNG + 5s screenrecord; обе scene_differ=True.
- [x] Force-stop 0/100/250/500ms: все поля черновика восстановлены, фактические логи сохранены.
- [x] Все шесть localization matrices с deep routes для всех профилей: PASS.
- [x] 10/10 циклов на финальном installed release; crash/ANR не найдены, финальный Static activeViews=0.
- [x] 10 cold starts; P50/P95 отдельно для branded/data/interactive/am start.
- [x] 36 основных release-экранов; 78/78 PNG pixel validation PASS. Финальный manifest формируется при упаковке.
- [ ] Physical ARM64 install/runtime/GPU/FPS/P95/RAM/battery/thermal — NOT RUN / NOT MEASURED.

## Выдача прямо в чат

- [x] Оба release APK, source, screenshots, reports, logs/persistence/runtime упакованы.
- [x] Все вложенные ZIP CRC, read-back и обязательные SHA-256 проверены.
- [x] `ORBIT_0.5.4_SHA256SUMS.txt` и FULL_PACKAGE с отдельным SHA.
- [ ] Повторный независимый аудит ChatGPT после передачи ZIP.

Статус: `READY_FOR_ARM64_DEVICE_TEST`, не `ARM64_VERIFIED` и не production release.

## Photoreal candidate — 2026-11-09

- [x] Ветка `feature/orbit-photoreal-055` продолжает единый ORBIT 0.5.4+10.
- [x] Четыре photographic интерфейса и experimental Filament PBR с CC0 assets/licenses.
- [x] Календарь 4/4 и Light/Dark/System 14/14 host; Android UI 3/3 после force-stop.
- [x] `flutter analyze` PASS; полный host suite 101/101 PASS.
- [x] Android graphics/navigation integration PASS; 45 canonical integration PNG.
- [x] x86_64 release install без wipe, launch и System restore PASS.
- [x] Обе APK проверены по version/ABI/CRC/APK v2 signature/required graphics assets.
- [x] 63/63 PNG pixel validation; 5 MP4 containers сохранены. MP4 playback — NOT RUN.
- [x] FULL_PACKAGE: точный media/source состав, nested ZIP CRC/read-back и `sha256sum -c` PASS.
- [ ] Physical ARM64 install/runtime/GPU/FPS/frametime/RAM/thermal/battery — NOT RUN / NOT MEASURED.
- [ ] Плавность не принята: emulator Layered intervalP50=183.33ms; нужна проверка и оптимизация на целевом устройстве.
- [ ] Художественная приёмка референсов пользователем на физическом Android.
- [ ] Повторный независимый аудит ChatGPT после передачи FULL_PACKAGE.
- [ ] Authenticated Google Drive upload/read-back — NOT RUN; локальная папка обмена используется без обхода входа.

Итоговый статус комплекта: `READY_FOR_ARM64_DEVICE_TEST`, не production.
