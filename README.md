# ORBIT 0.5

ORBIT — персональная цифровая экосистема на Flutter. Проект продолжен из последнего ORBIT Visual Lab `0.4.0+4`; отдельное демонстрационное приложение не создавалось.

## Реализовано

- Четыре самостоятельных оформления с единым поведением: **ORBIT One**, **Atelier**, **Flow** и **Zen**.
- Экраны «Сегодня», «Почта», письмо по ID, локальный черновик, «Календарь», создание события, «Задачи», карточка задачи, «Настройки», диагностика и **ORBIT Brain**.
- Единые Application Core, UI Engine, Scene Engine, Motion Engine, Navigation, Settings Repository, Module Interfaces и Diagnostics.
- Flutter/Impeller procedural scene, локальные Rive resources и экспериментальный нативный Android/Filament PBR renderer.
- Auto/Eco/Balanced/Ultra, статический fallback, остановка анимаций в фоне и учёт системных ограничений.
- Версионированное сохранение оформления, качества, темы, акцента, языка, плотности, движения, renderer и масштаба текста.
- Сохранение локальных задач, событий, статусов прочтения и черновиков между запусками.
- Независимые ветки навигации, системный back и сохранение введённых данных при смене оформления.
- RU/EN/DE/FR/ES через ARB + `gen_l10n`, адаптивная раскладка и поддержка системного масштабирования текста.
- Контракты будущих модулей и `flutter_secure_storage` для будущих секретов. Секреты в ORBIT 0.5 не используются и не сохраняются.

Все записи являются **явно маркированными локальными демонстрационными данными**. Реальные аккаунты, корпоративные сервисы и сетевые AI-запросы не подключены. Почта не отправляется, вложения не загружаются, ORBIT Brain работает только с подготовленными локальными сценариями.

## Требования

- Flutter **3.47.9**, Dart **3.13.7**, Java 17.
- Android SDK **37.0** для compile-time, build-tools 36.0.0 и NDK 28.2.13676358.
- Официальные Android AAR Filament **1.79.0** включены в `android/app/libs/`.
- Готовые `.filamat` включены; `matc` нужен только для пересборки материалов.

На Windows Android Gradle не принимает не-ASCII путь. Если рабочий каталог содержит такие символы, подключите тот же каталог под ASCII-буквой диска, не создавая вторую копию проекта:

```bat
subst O: "D:\Кими"
cd /d O:\orbit_visual_lab
```

После завершения `subst O: /D` удаляет временное подключение.

## Запуск и проверки

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test --reporter expanded
flutter run
```

Android:

```bash
flutter build apk --debug --target-platform android-arm64
flutter build apk --debug --target-platform android-x64
flutter test integration_test/app_test.dart -d <android-device>
```

Текущий фактический статус хранится в `ORBIT_PROJECT_STATE.json`, `ORBIT_PROGRESS.md` и `ORBIT_0.5_validation.md` после формирования release artifacts. Подготовленный тест или скрипт не считается выполненным. Static fallback не считается доказательством Rive/Filament runtime.

## Структура

- `lib/core/` — контракты независимых модулей и будущего Brain.
- `lib/data/` — demo models, local-state repository и secure-store adapter.
- `lib/state/` — единое состояние приложения.
- `lib/visual_engine/` — оформления, качество, сцены, движение и адаптивная раскладка.
- `lib/screens/` — функциональные поверхности ORBIT.
- `lib/widgets/` — общие Flutter-компоненты, навигация и PlatformView.
- `android/app/src/main/kotlin/.../Filament*` — нативный Android renderer.
- `native/filament/` — исходники PBR/atmospheric materials.
- `assets/rive/` и `rive/` — проверяемые ресурсы и редактируемые исходники.
- `test/`, `integration_test/`, `tool/` — host tests, Android contract test и evidence collectors.

## Документы

- `ORBIT_PROJECT_STATE.json` — состояние и следующий шаг.
- `ORBIT_PROGRESS.md` — выполненная работа и фактические проверки.
- `ORBIT_ISSUES.md` — реестр P0–P3.
- `ORBIT_RELEASE_CHECKLIST.md` — gates передачи.
- `ORBIT_RESUME.md` — инструкция следующей итерации.
- `docs/ARCHITECTURE.md`, `docs/TESTING.md`, `docs/KNOWN_ISSUES.md`, `docs/PERFORMANCE.md`.
- Исторические Sprint 02–04 reports сохранены для происхождения и не являются evidence ORBIT 0.5.

Release-сборка использует debug signing исходного проекта и предназначена только для пользовательского тестирования, не для публикации в магазине.
