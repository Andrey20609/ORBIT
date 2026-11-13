# iOS: проектирование поддержки

## Уже переносимо

Flutter UI, GoRouter, SharedPreferences, настройки, профили, процедурный `OrbitSceneEngine`, motion/layout/quality, ARB-локализация и оба Rive-ресурса не зависят от Android. Impeller является основным современным renderer Flutter на поддерживаемых iOS-конфигурациях.

`OrbitFilamentScene` на не-Android платформах возвращает fallback и не создаёт AndroidView.

## Что потребуется

1. Создать iOS target основного приложения, подключить локальные шрифты/Rive и ARB-локализацию, проверить все пять языков, Safe Area, Dynamic Type, Reduce Motion и VoiceOver.
2. Оставить процедурный/Rive варианты общими.
3. Для эксперимента B выбрать отдельную реализацию: нативный Filament iOS/Metal или MetalKit/SceneKit с тем же контрактом сцены. Android Kotlin PlatformView на iOS не работает.
4. Ввести platform-agnostic интерфейс `configure(profile, quality, paused)`, `release`, `stats` и registry по view ID. Не выдавать Android PBR-сцену за уже существующую iOS-версию.
5. Проверить background/foreground, Metal drawable resize, memory warning, ресурсы камеры/материалов и статический fallback.
6. Выполнить TestFlight/device-проверки на реальных iPhone. Simulator не заменяет GPU/thermal/energy measurements.

## Статус

iOS target, Metal renderer, IPA и измерения на iPhone: **NOT IMPLEMENTED / NOT MEASURED**. Сборка iOS в Linux-окружении невозможна; потребуется macOS/Xcode и действующая подпись разработчика.
