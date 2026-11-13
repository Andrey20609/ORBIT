# ORBIT Visual Engine — руководство по последующей интеграции

## Граница Sprint 02

Основное приложение ORBIT в этом спринте не изменялось. Visual Lab остаётся изолированным пакетом `app.orbit.orbit_visual_lab`. Ниже — план переноса после отдельной приёмки Android runtime; это не разрешение считать экспериментальный Filament production-ready.

## 1. Переносимые компоненты

Переносите в отдельную ветку основного проекта:

- `lib/visual_engine/` — `OrbitStyleManager`, `OrbitSceneEngine`, `OrbitMotionEngine`, `OrbitLayoutEngine`, `OrbitQualityManager`, `OrbitAppearanceRepository`, палитры и настройки;
- необходимые общие виджеты из `lib/widgets/`;
- `lib/l10n/`, `l10n.yaml` и ARB-каталоги `app_{ru,en,de,fr,es}.arb`;
- `assets/fonts/`, `assets/rive/orbit_mark.riv`, `assets/rive/orbit_atmosphere.riv`;
- при выборе нативного 3D — Kotlin `Filament*`, `OrbitFilamentScene`, `.filamat`, исходники `native/filament/` и официальные AAR.

Не переносите `OrbitAppState`, `lib/data/demo_data.dart`, демонстрационные маршруты и тексты Demo Mode в production. Подключите существующие repository/use cases основного ORBIT через адаптеры, не переписывая рабочую почтовую архитектуру.

## 2. Зависимости

Зафиксированные прямые зависимости находятся в `pubspec.yaml` и `pubspec.lock`:

- `go_router` 18.x;
- `shared_preferences`;
- `rive` 0.14.11 и transitive `rive_native` 0.1.11;
- `intl`;
- `clock` `^1.1.2` (lockfile: 1.1.3) — также используется для воспроизводимых дат в Today/Calendar и тестах;
- `flutter_localizations` и Flutter `generate: true`.

Для тестов нужны `flutter_test`, `integration_test` и `flutter_lints`. Не обновляйте Rive/Filament независимо без повторной проверки assets и ABI.

## 3. Инициализация

1. Создайте `WidgetsFlutterBinding` и `OrbitStyleManager`.
2. Выполните `OrbitStyleManager.load()` до построения темы.
3. Инициализируйте `RiveNative` в `try/catch`. Ошибка Rive не должна блокировать запуск приложения; Static остаётся доступным.
4. Создайте один долгоживущий `OrbitQualityManager`, подключите lifecycle и системные сигналы.
5. Не вызывайте `Filament.init()` в `MainActivity` или при старте. Нативная библиотека загружается лениво только при создании выбранной 3D PlatformView.

## 4. Тема, локализация и навигация

`MaterialApp` должен получать:

- `themeMode` из сохранённых настроек;
- `Locale(languageCode)`;
- `AppLocalizations.delegate` и `supportedLocales`;
- `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations`.

Добавьте новые пользовательские строки сначала во все пять ARB, затем выполните `flutter gen-l10n` или обычный `flutter pub get/build` с генерацией. Демонстрационные записи локализуются по стабильным ID, а не по русскому тексту.

Сохраните независимые ветки `StatefulShellRoute.indexedStack`, обработку системной кнопки «Назад» и recoverable unknown route. Даты, зависящие от golden-тестов, получайте через `clock.now()`.

## 5. Persistence и миграции

Текущий ключ: `orbit.visual.appearance.v1`, `schemaVersion = 1`. JSON включает профиль, renderer, качество, ThemeMode, ARGB accent, язык, плотность и motion.

`OrbitStyleManager` применяет изменение оптимистично и сериализует записи через одну очередь. Не заменяйте её независимыми несериализованными `save()` — медленная старая запись может перезаписать новую. При ошибке последней записи выполняется rollback.

При смене схемы:

- добавьте миграцию и тест старого JSON;
- не удаляйте старый ключ до успешного чтения нового;
- сохраните безопасные defaults для неизвестных enum и повреждённых значений;
- проверьте force-stop/relaunch, reboot и установку APK с большим versionCode без очистки данных.

Uninstall удаляет SharedPreferences по модели Android; это не тест upgrade.

## 6. Android / Filament

AAR Filament 1.79.0 находятся в `android/app/libs/`, контрольные суммы — в `SHA256SUMS`. Используйте совместимые material package version 79 и тот же runtime.

```kotlin
android {
    compileSdk = 37
}

dependencies {
    implementation(files("libs/filament-v1.79.0-android.aar"))
    implementation(files("libs/filament-utils-v1.79.0-android.aar"))
    implementation(files("libs/gltfio-v1.79.0-android.aar"))
}
```

Пересборка materials при наличии официального `matc` 1.79.0:

```bash
matc -p mobile -a opengl -o android/app/src/main/assets/materials/orbit_pbr.filamat native/filament/orbit_pbr.mat
matc -p mobile -a opengl -o android/app/src/main/assets/materials/orbit_unlit.filamat native/filament/orbit_unlit.mat
```

Перед включением в основном приложении обязательны реальные Android-проверки: Engine/Scene/Camera, Surface/SwapChain, несколько PlatformView по ID, поворот/resize, touch parallax, pause/resume, Surface detach, low memory и полное освобождение resources. Статическая процедурная сцена должна оставаться под нативным Surface при инициализации и после ошибки.

Не переносите глобальный singleton Engine в приложение с другими Filament-сценами без анализа потоков. Не заявляйте отсутствие блокировки UI или энергетические преимущества до device-профилирования.

## 7. Качество и fallback

Auto намеренно разрешается максимум в Balanced; Ultra — только явный opt-in до появления подтверждённых device-профилей. Eco, background, Low Memory, Battery Saver, Reduce Motion и выключенное motion переводят сцену в Static.

Не удаляйте Static-подложку под Rive/Filament. Ошибка загрузки `.riv`, Engine, Surface, SwapChain или material должна журналироваться и оставлять работающий Flutter UI без чёрного экрана. После low memory нативная сцена освобождается; повторный запуск требует явного безопасного пересоздания.

## 8. Production gate

До интеграции и публикации:

1. Выполнить clean build из зафиксированного commit.
2. Прогнать `integration_test/app_test.dart` и `tool/android_validation.sh` на физическом Android.
3. Получить реальные Static/Rive/Filament PNG/video и проверить их визуально.
4. Провести A/B/C profile/release измерения минимум в трёх повторениях на одном устройстве.
5. Проверить 100/130/150/200% текста на целевых экранах и все пять языков.
6. Заменить demo signing на собственный release signing вне Visual Lab.
7. Сформировать полный third-party notice по фактически закреплённым версиям.
8. Не показывать успешную отправку письма или подключение сервера до реального подтверждения backend.

Существующие рабочие модули основного ORBIT изменяйте только по отдельной необходимости и после резервной копии.
