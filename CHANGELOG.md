# Changelog

## 0.5.30+36 — version display consistency (2026-11-13)

- About, лицензии, локализованные подписи, Brain и fallback Diagnostics приведены к единой версии `0.5.30+36`.
- `versionName` и `versionCode` приложения не изменены; функциональность не затронута.
- Добавлен regression-тест отсутствия старых `0.5.0` и `0.5.17+23`.

## 0.5.30+36 — upgrade persistence gate (2026-11-13)

- Кандидат только для проверки обновления принятой `0.5.29+35` на устройстве без потери данных.
- Функциональность, интерфейс и логика приложения не изменены.

## 0.5.29+35 — dock and draft cleanup (2026-11-13)

- Нижний док стал полностью непрозрачным: прокручиваемые кнопки и содержимое больше не просвечивают через него.
- Compose получил кнопку удаления черновика с подтверждением.
- При удалении отменяются отложенные autosave и dispose-save, поэтому черновик не восстанавливается после выхода или повторного открытия.
- Добавлены 2 regression-теста прозрачности дока и полного удаления persisted draft. Свайп-действия в этот выпуск не входят.

## 0.5.28+34 — targeted device-review adjustments (2026-11-13)

- Messenger: нижний отступ композера уменьшен до 16 dp + системный inset, поле ввода находится у нижнего края экрана.
- Центр действий: подпись «Мессенджер» остаётся одной строкой и при необходимости плавно уменьшается, без переноса последней буквы.
- Mail и Calendar: плавающие кнопки создания письма и события смещены ровно на 24 dp вниз; остальные экраны и FAB не изменены.
- Добавлены 3 точечных regression-теста позиций композера, подписи и FAB.

## 0.5.27+33 — large-text UI remediation (2026-11-13)

- Today: при масштабе текста выше 125% метрики One/Atelier перестраиваются из узких плиток в полноразмерные строки; события получают полную ширину заголовка и метаданных; узкая шапка больше не уменьшает логотип до нечитаемого состояния.
- Hub: упрощён поиск при крупном тексте, декоративные shortcut/arrow больше не сжимают содержимое, Brain сохраняет читаемый заголовок и статус.
- Settings: длинные заголовки и подписи получают до 3/4 строк, декоративный chevron скрывается при крупном тексте, имя и email допускают две строки.
- Добавлена визуальная матрица `test/ui_regression_0527_test.dart` для Today, Hub и Settings при 320 dp × 200% текста с пятью проверенными golden-кадрами.
- Усилен GLM regression-тест прокрутки Hub: жест выполняется по scroll view, видимость нижнего блока проверяется координатами.

## 0.5.26+32 — GLM remediation (2026-11-13)

### P0: правая чёрная полоса / обнажённые края фона
- `orbit_photoreal_scene.dart`: добавлены `layerShiftLimit`/`clampLayerShift`; параллакс-сдвиги всех слоёв (базовый 1.12, foreground 1.16, planes sky/far/mid/fg) клампятся к оверскан-запасу с резервом 0.5 dp. Overscan fg-плоскости поднят 1.105 → 1.15 (амплитуда 22.7 dp > старый запас 16.8 dp при 320 dp — воспроизведённый источник полосы). Сдвиги считаются от фактического вьюпорта (LayoutBuilder), а не от констант.

### P0: адаптивная типографика Hub
- `orbit_app_hub_sheet.dart`: при textScale > 1.25 бейдж профиля переносится с строки заголовка на отдельную строку. Ранее при 320 dp и textScale 2.0 фиксированный кластер «бейдж+кнопка» сжимал заголовок до посимвольного вертикального переноса (+21 px overflow справа, +1178 px колонки).

### P0: живой фон
- `orbit_living_backdrop.dart`: сдвиг Ken Burns/наклона клампится к запасу минимального масштаба дыхания (1.125 при полной интенсивности) по фактическому вьюпорту. Старый максимум 28 dp превышал запас 22.5 dp при 360 dp.

### Тесты
- Новый `test/ui_regression_0526_test.dart`: 6 тестов — математика клампа, крайние наклоны planes/living backdrop, Hub при 320 dp × textScale 2.0 (рендер без overflow, прокрутка, закрытие кнопкой).
- Полный набор: 337/337 PASS, analyze 0 issues, goldens без изменений.


## ORBIT 0.5 — 2026-11-07

- Проект продолжен из ORBIT Visual Lab `0.4.0+4` как единое приложение ORBIT `0.5.0+6`.
- Добавлены persistent local tasks, events, read-mail state и offline drafts с отдельным версионированным репозиторием.
- Реализованы создание события, переключение дат, карточка задачи, приоритеты и статусы.
- Appearance schema 2 добавляет сохраняемый масштаб текста; настройки применяются к системному TextScaler.
- Добавлены module/Brain contracts и адаптер `flutter_secure_storage` без сохранения реальных секретов.
- Настройки дополнены диагностикой; версия и описание обновлены на пяти ARB-локалях.
- Host analyzer PASS; полный suite 45/45 PASS, включая новые functional tests и Windows goldens.
- Android build запускается через ASCII `subst` на Windows с Cyrillic workspace; исходный проект не дублируется.
- Android integration PASS: Rive state machine/Pulse, Filament frames/SwapChain/lifecycle, navigation и четыре профиля.
- Добавлены MediaStore screenshots, force-stop/upgrade/AVD restart persistence evidence и startup safeguards.
- x86_64 release использует Skia и Static вместо падающего emulator Impeller/Rive GL driver; ARM64 сохраняет Impeller/Rive.

## Sprint 02 — 2026-11-06

### Графика и стабильность

- Auto больше не включает Ultra автоматически: консервативный результат Auto — Balanced, Ultra остаётся явным opt-in.
- Eco, background, Low Memory, Battery Saver, Reduce Motion и `motionEnabled=false` принудительно выбирают Static, включая явные Balanced/Ultra.
- Static-процедурная сцена остаётся подложкой при загрузке и ошибках Rive/Filament.
- `Filament.init()` перенесён в lazy creation 3D view; ошибка configuration удаляет PlatformView и сохраняет Static fallback.
- Добавлен полноэкранный Rive atmosphere `orbit_atmosphere.riv` с `OrbitAtmosphere`, `OrbitLoop` и `Pulse`, помимо фирменного `orbit_mark.riv`.
- Обновлены процедурные ridgelines, smoothing, snow facets, lake, foreground banks и Zen-палитра.
- Добавлены native stats и Android contract checks для инициализации, scene readiness, ошибок, pause/resume и release.

### Настройки и состояние

- Сохраняются профиль, renderer, качество, ThemeMode, акцент, язык, плотность и motion через schema version 1.
- Записи `OrbitStyleManager` сериализуются одной очередью; медленная старая запись не может завершиться после новой и перезаписать её.
- Исправлено обновление dependents `OrbitEnvironment`: mutable `OrbitAppState` сохраняет identity, поэтому прежнее сравнение ссылок не перерисовывало список задач после добавления.
- Draft и независимые navigation branches сохраняются при смене оформления.

### UX и локализация

- Добавлены ARB + `gen_l10n` для RU/EN/DE/FR/ES; демонстрационные записи переводятся по стабильным ID.
- Локальные задачи используют `local-list` и `no-due`; Reply формирует локализованные subject/body без русского fallback.
- Даты Today/Calendar переведены на `clock` для воспроизводимых тестов.
- Исправлены adaptive layouts для Quick actions, Calendar, Brain, Settings, Gallery и Visual Lab.
- Host tests покрывают масштаб текста 100/130/150/200%, ширину 320 px и основные маршруты.

### Проверки и передача

- Полный host suite после чистого запуска: **36/36 PASS**; format и `flutter analyze --no-pub`: **PASS**.
- Добавлены golden-кадры четырёх профилей и пяти дополнительных поверхностей с явной маркировкой `Flutter golden test`.
- Добавлены `integration_test/app_test.dart`, `tool/android_validation.sh` и `tool/android_performance.sh`.
- Стандартная чистая arm64 debug-сборка: **PASS**; APK 110394777 байт, SHA-256 `ce292e52c4a6d481278a9fad8ed7b49e519303007459047dfc29bbb8b6c953b7`.
- Package/version, Android debug v2 signature, ZIP CRC, обязательные Flutter/Rive/Filament assets и строгий ABI set `arm64-v8a`: **PASS** на уровне структурной проверки.
- AGP packaging удаляет лишние ABI из официальных local Filament AAR; готовый APK не перепаковывается.
- Android runtime, force-stop/reboot/upgrade и physical-device performance не объявляются выполненными без фактического device run; см. `ACCEPTANCE.md`, `PERFORMANCE.md` и `validation/README.md`.
