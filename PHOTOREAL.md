# ORBIT Photoreal Today — technical comparison

Ветка `feature/orbit-photoreal-055` продолжает единый ORBIT 0.5.4+10. Полезные исправления Qwen для выбора дат календаря и Light/Dark/System перенесены точечно; почтовая бизнес-логика и схема persistence не переписывались.

## Два независимых варианта

### Layered Today

`lib/widgets/orbit_photoreal_scene.dart` использует photographic CC0 assets, отдельные atmospheric/light layers и умеренный parallax. Это не изображение целого интерфейса: навигация, карточки, списки и формы остаются Flutter widgets.

- One: скальная природная среда, 1080×2400.
- Atelier: море, волны и закат, 1080×2400.
- Flow: отдельный teal light/glass field без горной low-poly геометрии.
- Zen: светлая атмосфера без mirrored lower half HDRI.
- Обновление декоративного motion: 10 FPS для фотографических сцен, 20 FPS для Flow; списки статичны.

### Filament Today

`FilamentPlatformView.kt` создаёт настоящие Engine/Scene/Camera/SwapChain и procedural smooth terrain. `orbit_pbr.mat` компилируется официальным matc 1.79.0 и использует UV0, sRGB diffuse, linear normal/roughness, tangent-frame normal mapping и mipmapped textures.

- Balanced mesh: 112×112; Ultra: 160×160.
- Native frame cap: 15 FPS Balanced, 30 FPS Ultra.
- Material binding проверен через bundled AAR `javap`: `TextureSampler`, `SRGB8_A8`, `PixelBufferDescriptor`, `GEN_MIPMAPPABLE`.
- Textures and views освобождаются при dispose/low-memory.

## Ограничение нагрузки

При ScrollStart фон Today получает `TickerMode=false`; при ScrollEnd восстанавливается. Списки почты, календаря, задач и Settings используют static photographic scenes без continuous 3D. Native watchdog игнорирует состояние `paused=true`, поэтому навигация/scroll не вызывает ложный fallback.

## Evidence

- `validation/orbit055/screenshots`: системные PNG и шестисекундные MP4 для каждого профиля.
- `validation/orbit055/runtime`: `gfxinfo framestats`, memory PSS, logcat и capture results.
- `assets/photoreal/LICENSES.md`: источники, CC0, authors и MD5 discrepancy note.
- `validation/orbit055/logs/matc-version.txt`: official SDK hash and compiler version.

Метрики относятся только к Android 15 x86_64/SwiftShader. Физический ARM64 не выдаётся за проверенный. Окончательная художественная приёмка принадлежит пользователю; наличие красивого статического PNG не считается завершением.
