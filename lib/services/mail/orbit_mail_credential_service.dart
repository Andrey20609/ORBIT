import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

import '../../core/module_interfaces.dart';
import '../../data/orbit_secure_store.dart';

/// Исключение операций с почтовыми учётными данными.
///
/// Сообщение НИКОГДА не содержит значение секрета — только ключ/операцию.
class OrbitMailCredentialException implements Exception {
  const OrbitMailCredentialException(this.message);

  final String message;

  @override
  String toString() => 'OrbitMailCredentialException: $message';
}

/// MAIL-01A: единый сервис хранения app password поверх approved
/// [OrbitSecretStore] (production — `FlutterOrbitSecretStore`, тесты —
/// `MemoryOrbitSecretStore`).
///
/// Гарантии:
/// - ключ версионированный (`mail.v1.<accountId>.appPassword`) и не содержит
///   email или сам секрет;
/// - секрет не возвращается никаким UI/state геттерам — метод чтения
///   предназначен только для будущего mail-транспорта (MAIL-02); в этом
///   этапе его использует исключительно тестовый набор;
/// - исключения sanitized: значение пароля в них не попадает;
/// - сервис не пишет секрет ни в JSON snapshot, ни в SharedPreferences,
///   ни в SQLite — только в secure store.
final class OrbitMailCredentialService {
  OrbitMailCredentialService({OrbitSecretStore? store})
    : _store = store ?? const FlutterOrbitSecretStore();

  final OrbitSecretStore _store;

  static const String _keyPrefix = 'mail.v1';
  static const String _keySuffix = 'appPassword';

  /// Версионированный ключ секрета. Не содержит email или сам секрет.
  @visibleForTesting
  static String secretKeyFor(String accountId) =>
      '$_keyPrefix.$accountId.$_keySuffix';

  /// Сохраняет app password для аккаунта.
  Future<void> saveAppPassword({
    required String accountId,
    required String appPassword,
  }) async {
    final trimmedId = accountId.trim();
    if (trimmedId.isEmpty) {
      throw const OrbitMailCredentialException(
        'Нельзя сохранить пароль без идентификатора аккаунта',
      );
    }
    if (appPassword.isEmpty) {
      throw const OrbitMailCredentialException(
        'Нельзя сохранить пустой пароль приложения',
      );
    }
    try {
      await _store.write(secretKeyFor(trimmedId), appPassword);
    } on OrbitMailCredentialException {
      rethrow;
    } catch (_) {
      // Sanitized: ни значение секрета, ни внутреннее представление ошибки
      // не попадают в сообщение.
      throw OrbitMailCredentialException(
        'Не удалось сохранить пароль приложения (secure storage)',
      );
    }
  }

  /// Чтение секрета БУДУЩИМ mail-транспортом (MAIL-02). В этапе MAIL-01A
  /// используется только тестами; UI и OrbitAppState секрет не получают.
  Future<String?> readAppPasswordForTransport(String accountId) async {
    try {
      return await _store.read(secretKeyFor(accountId));
    } catch (_) {
      throw OrbitMailCredentialException(
        'Не удалось прочитать пароль приложения (secure storage)',
      );
    }
  }

  /// Есть ли сохранённый секрет (не возвращает само значение).
  ///
  /// Платформа без secure storage (например, тестовая среда без плагина)
  /// сообщается как «секрета нет» — это явная, а не ложная «сохранённая»
  ///语义状态; production Android всегда имеет плагин.
  Future<bool> hasAppPassword(String accountId) async {
    try {
      return await _store.read(secretKeyFor(accountId)) != null;
    } on MissingPluginException {
      return false;
    } catch (_) {
      throw OrbitMailCredentialException(
        'Не удалось проверить наличие пароля приложения (secure storage)',
      );
    }
  }

  /// Удаляет секрет аккаунта. Идемпотентна по отсутствующему ключу.
  /// Платформа без secure storage (тестовая среда) — удалять нечего.
  Future<void> deleteAppPassword(String accountId) async {
    try {
      await _store.delete(secretKeyFor(accountId));
    } on MissingPluginException {
      return;
    } catch (_) {
      throw OrbitMailCredentialException(
        'Не удалось удалить пароль приложения (secure storage)',
      );
    }
  }
}
