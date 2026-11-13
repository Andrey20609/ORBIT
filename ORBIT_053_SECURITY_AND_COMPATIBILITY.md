# ORBIT 0.5.4 — безопасность и совместимость

## Текущая DEMO-модель

В ORBIT 0.5.4 нет реальных аккаунтов, паролей, токенов, сетевой почты или AI API. Демонстрационные задачи, события и черновики остаются локальными JSON в SharedPreferences. Это допустимо только для явно маркированных DEMO-данных.

## План перед Accounts/Mail (не реализуется в 0.5.4)

1. Не принимать реальные почтовые данные до отдельной миграции хранилища.
2. Хранить ключи шифрования и будущие токены только через `flutter_secure_storage`; секреты не включать в JSON, логи, ZIP или screenshots.
3. Перенести реальную переписку в зашифрованную локальную БД (SQLCipher-совместимый вариант после отдельной проверки поддерживаемых Android ABI). Ключ БД хранить в Android Keystore через secure storage, не в исходниках.
4. Перед миграцией сделать экспорт/backup после подтверждения пользователя. Не удалять plaintext-записи до проверки расшифровки и rollback-плана. Повреждённые JSON уже сохраняются в `.corruptBackup` и не затираются defaults.
5. Выполнить отдельные тесты upgrade, process death, потери ключа, восстановления и очистки при logout. До этого этапа не подключать Gmail/Exchange/IMAP/SMTP.

## Android identity и обновления

- В 0.5.4 сохраняются `applicationId=app.orbit.orbit_visual_lab` и прежняя test debug signing configuration, поэтому update v9→v10 не ломает установленную DEMO-версию.
- Перед коммерческой публикацией предложить стабильный production `applicationId` и отдельный release keystore. Ключ не хранить в проекте/ZIP; использовать защищённое владельцем хранилище/CI secrets.
- Смена ID или подписи — отдельный миграционный релиз: экспорт данных, установка нового пакета, проверка импорта, затем удаление старого только пользователем. Не выполнять её скрыто в shell-hardening.

## Зафиксированная build-матрица

- Flutter `3.47.9`, Dart `3.13.7`, Java `17.0.20.1`.
- Android Gradle Plugin `9.1.1`, Kotlin Gradle Plugin `2.4.0`, Gradle `9.3.1`.
- `rive=0.14.11`, `rive_native=0.1.11`, `flutter_secure_storage=9.2.4`.
- compileSdk 37, minSdk 24, targetSdk 36, Java/Kotlin JVM 17.

Flutter предупреждает о будущем переходе на Built-in Kotlin; `rive_native` ещё применяет Kotlin Gradle Plugin. В 0.5.4 версии не обновляются вслепую. Следующая миграция должна сначала проверить совместимый Flutter/Rive release, затем пройти analyze, host tests, обе ABI release builds и Android runtime/fallback. Текущее предупреждение не является ошибкой сборки.
