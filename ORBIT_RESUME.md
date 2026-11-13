# ORBIT 0.5.5+11 — возобновление

## База и границы

Проект `D:\Кими\orbit_visual_lab`, ветка `fix/orbit-photoreal-055-stabilize`, база `2240023`. Предыдущая `feature/orbit-photoreal-055` сохранена. Flutter-команды выполнять из `O:\orbit_visual_lab`. Новый проект не создавать, package ID/test signing сохранять. Независимый аудит распакован в `ORBIT_AI_EXCHANGE/01_TASKS_FOR_KIMI/2026-11-09_ORBIT_054_Photoreal_Audit_and_Kimi_055_TZ`.

## Подтверждено

- Version 0.5.5+11, native build metadata, update 0.5.4→0.5.5 без wipe с побайтовым совпадением SharedPreferences; reboot persistence PASS.
- Flow Light readable, Live System Night, Light/Dark/System 3/3, profile/theme matrix 24 PNG.
- FrameTiming/gfxinfo metrics, immutable aspect snapshots, layered scenes, pre-rendered glow и выборочная интеграция второго Qwen комплекта.
- `flutter analyze` PASS, host 136/136 PASS, Android graphics integration PASS, Android navigation/profile suite 2/2 PASS.
- Android leap-day: реальный переход к March 2024, выбор 31 марта, назад с clamp на 29 февраля, выбор 28 и 29 февраля PASS; semantic keys используются вместо хрупких ADB coordinates.
- Локализация RU/EN/DE/FR/ES × 4 профиля × основные разделы PASS при 100/150/200%. Системный font scale восстановлен в 1.0.
- Пять profile capture configurations завершены, но это не performance PASS: emulator raster P95 55.96–97.43 ms.

## Открытые ограничения

- PR-002/G2: физическая плавность не подтверждена; emulator превышает 16.7 ms budget.
- PR-004/PR-012/G5: физический ARM64, RAM/thermal/battery — NOT RUN.
- PR-005/PR-006: художественная приёмка пользователем — NOT RUN.
- PR-009: Filament Lab показывает белую/пустую карточку; native counters не являются visual proof. TextureView откачен, readPixels probe удалён, повторять одни и те же captures без нового технического решения не нужно.
- PR-013: Rive native artboard motion остаётся PARTIAL.
- PR-014: Android Debug signing только для тестирования.

## Следующий шаг

Rive/MP4/PNG validation завершены, Git code checkpoint `2ba67ce` создан. Обе release APK собраны и проверены. ARM64 SHA-256 `b053ac4f1bfe7839182733f1e1bcf4830a324e742bf8190cf3488241ce27715b`; x86_64 SHA-256 `b56b8cb73e7a87e754e3d172129666b45f6fcba55381814ec44332f7736bfec5`. x86_64 install без wipe/launch/System theme PASS; physical ARM64 NOT RUN.

Не пересобирать неизменённые APK. Source/review ZIP созданы, nested CRC и read-back SHA-256 проверены. Фактические хеши находятся в `ORBIT_0.5.5+11_SHA256SUMS.txt`.

Следующий шаг: передать `ORBIT_0.5.5+11_review.zip` на независимый аудит ChatGPT и выполнить `ORBIT_0.5.5+11_ARM64_CHECKLIST.md` на физическом телефоне. Для проверки выдачи:

```bash
cd ORBIT_AI_EXCHANGE/02_RESULTS_FROM_KIMI/2026-11-09_ORBIT_0.5.5+11_stabilize
sha256sum -c ORBIT_0.5.5+11_SHA256SUMS.txt
```

Evidence: `validation/orbit055_stabilize`. Выдача: `ORBIT_AI_EXCHANGE/02_RESULTS_FROM_KIMI/2026-11-09_ORBIT_0.5.5+11_stabilize`. Статус остаётся `PARTIAL / READY_FOR_CONTROLLED_ARM64_TEST`, не `RELEASE READY`. Authenticated Google Drive upload и повторный ChatGPT audit пока NOT RUN; локальная mirror-папка не считается облачной выгрузкой.
