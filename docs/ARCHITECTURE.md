# Архитектура ORBIT Visual Engine

## Границы проекта

Visual Lab — изолированный пакет `orbit_visual_lab`. Общий движок находится в `lib/visual_engine/` и экспортируется через `orbit_visual_engine.dart`. Он не импортирует экраны, router или демонстрационные данные, поэтому переносится отдельно.

## Состав движка

- `OrbitStyleManager` — единая точка изменения оформления. Применяет значение оптимистично, сохраняет JSON и откатывает состояние при ошибке записи. Единая очередь сериализует операции и предотвращает затирание новой настройки медленной старой записью.
- `OrbitAppearanceRepository` — интерфейс хранилища. Production-реализация использует `shared_preferences`; memory-реализация нужна тестам.
- `AppearanceSettings` — schema version 1, безопасные defaults, round-trip всех параметров.
- `OrbitSceneEngine` — процедурное небо, солнце, звёзды, облака, три слоя гор, атмосфера и Flow-ленты. Отдельный `RepaintBoundary` ограничивает перерисовку.
- `OrbitMotionEngine` — фирменная кривая, duration, press/reveal-компоненты.
- `OrbitLayoutEngine` — адаптивные отступы, плотность и максимальная ширина контента.
- `OrbitQualityManager` — Auto/Eco/Balanced/Ultra, lifecycle, power save, low memory, reduce motion.

Resolved quality: `static`, `balanced`, `ultra`. Balanced ограничивает фон 30 FPS, Ultra — 60 FPS; это целевые ограничители кадров, а не измеренные FPS. Auto консервативно выбирает Balanced, Ultra доступен только явно. Eco, background, Low Memory, Battery Saver, Reduce Motion и `motionEnabled=false` принудительно выбирают Static даже при явном Balanced/Ultra. Static не создаёт нативную Filament Surface и отключает blur/анимации.

## Навигация и состояние

`StatefulShellRoute.indexedStack` содержит ветки Today/Mail/Calendar/Tasks/Settings. Вложенные маршруты письма, черновика, персонализации и Visual Lab не уничтожают соседние ветки. Черновик находится в `OrbitAppState`, а не в widget state. `/brain` находится вне shell. Неизвестный маршрут получает recoverable error screen.

Корневой `ListenableBuilder` объединяет style, quality и app state. `OrbitEnvironment` уведомляет dependents при каждой такой пересборке: mutable `OrbitAppState` сохраняет объектную ссылку, поэтому сравнения identity недостаточно для обновления списка задач и других локальных данных.

## Эксперимент A

Flutter UI работает через мобильный Impeller. На Today процедурная Static-сцена всегда остаётся базовой подложкой. Поверх неё режим Rive загружает собственный `orbit_atmosphere.riv` с artboard `OrbitAtmosphere`, state machine `OrbitLoop` и trigger `Pulse`; `orbit_mark.riv` используется как отдельный фирменный знак. Loading, failure и Static quality не оставляют чёрный или пустой фон. Сеть и Rive publishing не нужны.

Rive Android runtime и Pulse требуют отдельной device-проверки: host golden-кадры показывают только Flutter/Impeller Static-вариант.

## Эксперимент B

Каждый Android PlatformView владеет собственными `Engine`, `Renderer`, `Scene`, `View`, `Camera`, `SwapChain`, mesh и material resources. Реестр адресует конфигурацию по platform-view ID.

Сцена содержит:

- процедурный terrain mesh с normals и quaternion tangent frames;
- два PBR-слоя рельефа для глубины;
- направленный солнечный свет и ambient irradiance;
- skybox, sun mesh и движущиеся прозрачные cloud meshes;
- perspective camera, движение и touch parallax;
- ACES tone mapping, temporal dithering и FXAA (фактический API Filament 1.79.0).

`matc` и runtime имеют версию 79 / 1.79.0. Material source хранится в `native/filament/`.

## Lifecycle и ресурсы

- `UiHelper.RendererCallback` создаёт/пересоздаёт SwapChain, обновляет viewport и projection.
- Перед уничтожением Surface вызывается `flushAndWait`.
- Раздельные `paused` для поверхности и `activityPaused` для приложения останавливают Choreographer-кадры; resume возобновляет только активные режимы.
- Low memory отправляет сигнал Dart и освобождает нативные ресурсы.
- Dispose удаляет entities, material instances, buffers, materials, skybox, indirect light, camera, scene, view, renderer и engine.
- Неактивный Today в Eco не создаёт AndroidView. Static-подложка остаётся под Rive/Filament на загрузку и ошибку, но одновременно активен только один тяжёлый animated renderer; процедурная анимация подложки в этих режимах остановлена.
- Ошибка конфигурации Filament удаляет PlatformView из дерева и оставляет Static. `Filament.init()` вызывается лениво только при создании 3D view, а не безусловно из `MainActivity`.

## Потоки и UI

Тяжёлая нативная сцена не блокирует Dart UI: PlatformView создаётся отдельно, кадры проходят через Android Choreographer. Все вызовы одного Filament Engine выполняются на его Android main thread. Общие функциональные модули не зависят от выбранного renderer.
