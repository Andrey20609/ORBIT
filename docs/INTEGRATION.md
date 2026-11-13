# Интеграция в основной ORBIT

Основной проект пользователя не изменялся. Перед интеграцией создайте ветку и резервную копию, затем переносите поэтапно.

## 1. Переносимый Flutter-движок

Скопируйте `lib/visual_engine/`, общие widgets и assets. Добавьте зависимости из `pubspec.yaml`: `go_router`, `shared_preferences`, `rive`, `intl`, `clock`, `flutter_localizations`. Подключите Noto-шрифты, `assets/rive/orbit_mark.riv` и `assets/rive/orbit_atmosphere.riv`. Для RU/EN/DE/FR/ES перенесите ARB-каталоги и `l10n.yaml`; generated localizations обновляются через `flutter gen-l10n` или обычный Flutter dependency/build workflow.

Не копируйте `OrbitAppState` или demo data в production. Вместо этого свяжите существующие repository/use cases с поверхностями через интерфейсы приложения.

## 2. Инициализация

До `runApp` инициализируйте binding, локали, RiveNative и `OrbitStyleManager.load()`. Ошибка графического ресурса не должна блокировать запуск функциональных модулей. QualityManager должен существовать дольше отдельных экранов. Не вызывайте `Filament.init()` безусловно при старте: загрузка нативной библиотеки выполняется лениво при создании выбранного 3D view.

## 3. Навигация

Переносите маршруты постепенно. Сохраните независимые ветки, восстановление state и обработку неизвестного пути. Существующие рабочие модули не следует переписывать ради визуального движка.

## 4. Android/Filament

Добавьте:

```kotlin
android {
    // AAR metadata Filament 1.79.0 требует API 37 при компиляции.
    compileSdk = 37
}

dependencies {
    implementation(files("libs/filament-v1.79.0-android.aar"))
    implementation(files("libs/filament-utils-v1.79.0-android.aar"))
    implementation(files("libs/gltfio-v1.79.0-android.aar"))
}
```

Скопируйте все три проверенных AAR в `android/app/libs/`, затем `FilamentPlatformView.kt`, `FilamentViewFactory.kt`, каналы из `MainActivity.kt`, `OrbitFilamentScene` и `android/app/src/main/assets/materials/`. Контрольные суммы находятся в `android/app/libs/SHA256SUMS`. Не смешивайте AAR и `.filamat` от разных версий Filament. Если новый AGP ещё не объявил поддержку API 37, используйте осознанный `android.suppressUnsupportedCompileSdk=37` только после проверки совместимости toolchain.

Пересборка материалов:

```bash
matc -p mobile -a opengl -o android/app/src/main/assets/materials/orbit_pbr.filamat native/filament/orbit_pbr.mat
matc -p mobile -a opengl -o android/app/src/main/assets/materials/orbit_unlit.filamat native/filament/orbit_unlit.mat
```

Проверьте несколько одновременных PlatformView, конфигурацию по ID, поворот/resize, pause/resume, low memory, Surface detach и отключение 3D. Не переносите глобальный singleton Engine в приложение с другими Filament-сценами без отдельного анализа потоков.

## 5. Persistence и миграции

Текущий ключ — `orbit.visual.appearance.v1`, schema version 1. Записи сериализуются одной очередью, чтобы медленная старая операция не завершилась после новой и не перезаписала её. При изменении схемы добавляйте миграцию, не удаляйте старый ключ до успешного чтения. APK update без очистки данных сохраняет SharedPreferences; uninstall их удаляет по модели Android.

Подробный Sprint 02 production gate и последовательность переноса находятся в корневом `INTEGRATION_GUIDE.md`.

## 6. Production-ограничения

- Debug signing замените собственным release signing вне Visual Lab.
- Демонстрационные email/задачи замените реальными источниками только после отдельной реализации синхронизации.
- Не показывайте «отправлено» до подтверждения сервера.
- Проведите profile/release-замеры на целевых устройствах до включения Ultra по умолчанию.
