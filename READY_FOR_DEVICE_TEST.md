# ORBIT 0.5.4+10 — READY_FOR_ARM64_DEVICE_TEST

Подготовлены исходники, ARM64/x86_64 release APK, реальные Android x86_64 кадры, motion video, логи, persistence/upgrade evidence и SHA-256 manifests.

## Подтверждено исполнителем

- `flutter analyze`: PASS; host suite: 79/79 PASS.
- Android x86_64 graphics/navigation: PASS; 6/6 localization matrices: PASS.
- Draft Back/force-stop 0/100/250/500 мс: PASS.
- Release stress: 10/10; финальный Static `activeViews=0`.
- Installed Rive/Filament scene hashes различаются; screenrecord сохранён.
- 10 cold starts с раздельными P50/P95.
- Update 0.5.3+9 → 0.5.4+10 без wipe: draft/task/event PASS.
- 36/36 release-экранов; 78/78 PNG pixel validation PASS.
- Обе APK: version 0.5.4/code 10, APK v2 signature, CRC и ABI PASS.

## Не подтверждено

- **Physical ARM64: NOT RUN.** Устройства нет; нельзя объявлять `ARM64_VERIFIED`.
- **Physical FPS/P95/PSS/thermal/battery: NOT MEASURED.**
- **Rive native artboard proof: PARTIAL.** `nativeArtboardAnimationProven=false`.
- Подпись Android Debug — test-only, не production.

## Следующий gate

1. Проверить SHA-256 ARM64 APK по `ORBIT_0.5.4_SHA256SUMS.txt`.
2. Выполнить `ARM64_SMOKE_CHECKLIST.md` на физическом ARM64 без реальных паролей/переписки.
3. Запустить `tool/arm64_smoke_collect.sh` или `.ps1`; collectors отклоняют QEMU и ABI, отличный от arm64-v8a.
4. Передать полученные device logs, кадры и фактические статусы на независимый аудит.

Полный отчёт: `ORBIT_0.5.4_validation.md`. Текущая версия не является production release.
