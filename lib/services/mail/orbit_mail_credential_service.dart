import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

import '../../core/module_interfaces.dart';
import '../../data/orbit_secure_store.dart';
import 'orbit_mail_oauth_service.dart';

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
  /// сообщается как «секрета нет» — это явное отсутствие секрета, а не
  /// ложное «сохранённое» состояние; production Android всегда имеет плагин.
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

  // ===== MAIL-01B: OAuth tokens (access/refresh/expiry/tokenType) =====
  // Тот же secure store, отдельные версионированные ключи. Токены никогда
  // не попадают в model/JSON/snapshot/SQLite/prefs/logs.

  static String _oauthKey(String accountId, String part) =>
      'mail.v1.$accountId.oauth.$part';

  /// Сохраняет набор OAuth-токенов. Refresh token записывается только при
  /// наличии в ответе (rotation по факту); иначе прежний остаётся.
  Future<void> saveOAuthTokens({
    required String accountId,
    required OrbitOAuthTokenSet tokens,
  }) async {
    final id = accountId.trim();
    if (id.isEmpty) {
      throw const OrbitMailCredentialException(
        'Нельзя сохранить токены без идентификатора аккаунта',
      );
    }
    // MAIL-01B r2 fix (блокер 3): пустой access token не является
    // валидным секретом — сохранение отклоняется.
    if (tokens.accessToken.isEmpty) {
      throw const OrbitMailCredentialException(
        'Нельзя сохранить пустой OAuth access token',
      );
    }
    try {
      await _store.write(_oauthKey(id, 'access'), tokens.accessToken);
      await _store.write(
        _oauthKey(id, 'expiry'),
        tokens.expiryUtc.millisecondsSinceEpoch.toString(),
      );
      await _store.write(
        _oauthKey(id, 'tokenType'),
        tokens.tokenType,
      );
      if (tokens.refreshToken != null && tokens.refreshToken!.isNotEmpty) {
        await _store.write(_oauthKey(id, 'refresh'), tokens.refreshToken!);
      }
    } on OrbitMailCredentialException {
      rethrow;
    } catch (_) {
      throw OrbitMailCredentialException(
        'Не удалось сохранить OAuth-токены (secure storage)',
      );
    }
  }

  /// Чтение токенов для транспорта/refresh (MAIL-02 и getValidAccessToken).
  /// Возвращает null, если токенов нет.
  Future<OrbitOAuthTokenSet?> readOAuthTokens(String accountId) async {
    try {
      final access = await _store.read(_oauthKey(accountId, 'access'));
      // MAIL-01B r2 fix (блокер 3): пустой access = валидного токена нет.
      if (access == null || access.isEmpty) return null;
      final expiryRaw = await _store.read(_oauthKey(accountId, 'expiry'));
      final expiryMs = expiryRaw == null ? null : int.tryParse(expiryRaw);
      final refresh = await _store.read(_oauthKey(accountId, 'refresh'));
      final tokenType =
          await _store.read(_oauthKey(accountId, 'tokenType')) ?? 'Bearer';
      return OrbitOAuthTokenSet(
        accessToken: access,
        refreshToken: refresh,
        expiryUtc: expiryMs != null
            ? DateTime.fromMillisecondsSinceEpoch(expiryMs, isUtc: true)
            : DateTime.now().toUtc(),
        tokenType: tokenType,
      );
    } catch (_) {
      throw OrbitMailCredentialException(
        'Не удалось прочитать OAuth-токены (secure storage)',
      );
    }
  }

  /// Есть ли OAuth-набор с НЕпустым access token. Пустая строка не
  /// считается секретом (MAIL-01B r2 fix, блокер 3).
  Future<bool> hasOAuthTokens(String accountId) async {
    try {
      final access = await _store.read(_oauthKey(accountId, 'access'));
      return access != null && access.isNotEmpty;
    } on MissingPluginException {
      return false;
    } catch (_) {
      throw OrbitMailCredentialException(
        'Не удалось проверить наличие OAuth-токенов (secure storage)',
      );
    }
  }

  /// Удаляет весь OAuth-набор аккаунта (access/refresh/expiry/tokenType).
  Future<void> deleteOAuthTokens(String accountId) async {
    try {
      await _store.delete(_oauthKey(accountId, 'access'));
      await _store.delete(_oauthKey(accountId, 'refresh'));
      await _store.delete(_oauthKey(accountId, 'expiry'));
      await _store.delete(_oauthKey(accountId, 'tokenType'));
    } on MissingPluginException {
      return;
    } catch (_) {
      throw OrbitMailCredentialException(
        'Не удалось удалить OAuth-токены (secure storage)',
      );
    }
  }

  /// MAIL-01B: возвращает действующий access token; при истечении (с grace
  /// 30 секунд) обновляет через [refreshCallback]. Семантика (ТЗ §7):
  /// - валидный access — без refresh;
  /// - успешный refresh — новые access/expiry сохраняются; rotation: новый
  ///   refresh token сохраняется при наличии, иначе прежний остаётся;
  /// - transient failure — null, refresh и metadata сохранены для retry;
  /// - invalid_grant — access/refresh/expiry удалены, metadata переводится
  ///   вызывающей стороной в notConfigured, null;
  /// - токены/ошибки не логируются.
  Future<String?> getValidAccessToken(
    String accountId, {
    required Future<OrbitAccessTokenRefreshOutcome> Function(
      String refreshToken,
    ) refreshCallback,
    DateTime? nowUtc,
  }) async {
    final tokens = await readOAuthTokens(accountId);
    if (tokens == null) return null;
    final now = nowUtc ?? DateTime.now().toUtc();
    final grace = const Duration(seconds: 30);
    if (tokens.expiryUtc.isAfter(now.add(grace))) {
      return tokens.accessToken;
    }
    final refresh = tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      // Обновить нечем: набор недействителен — удаляем (повторный OAuth
      // обязателен); metadata ведёт вызывающая сторона.
      await deleteOAuthTokens(accountId);
      return null;
    }
    final outcome = await refreshCallback(refresh);
    switch (outcome) {
      case OrbitAccessTokenRefreshed(:final tokens):
        await saveOAuthTokens(accountId: accountId, tokens: tokens);
        return tokens.accessToken;
      case OrbitAccessTokenRefreshTransient():
        // Refresh и metadata сохранены — retry возможен.
        return null;
      case OrbitAccessTokenRefreshInvalidGrant():
        await deleteOAuthTokens(accountId);
        return null;
    }
  }

  /// Есть ли у аккаунта ЛЮБОЙ секрет (app password ИЛИ OAuth-набор) —
  /// используется reconciliation'ом load() для консистентности metadata.
  Future<bool> hasAccountSecret(String accountId) async {
    try {
      final hasAppPassword = await this.hasAppPassword(accountId);
      if (hasAppPassword) return true;
      return await hasOAuthTokens(accountId);
    } on OrbitMailCredentialException {
      rethrow;
    }
  }
}

/// Результат refresh-вызова (классификация в клиенте AppAuth).
sealed class OrbitAccessTokenRefreshOutcome {
  const OrbitAccessTokenRefreshOutcome();
}

/// Успешный refresh: новые access/expiry; refresh token при rotation.
final class OrbitAccessTokenRefreshed extends OrbitAccessTokenRefreshOutcome {
  const OrbitAccessTokenRefreshed(this.tokens);

  final OrbitOAuthTokenSet tokens;
}

/// Временная ошибка (сеть/сервер): retry возможен.
final class OrbitAccessTokenRefreshTransient
    extends OrbitAccessTokenRefreshOutcome {
  const OrbitAccessTokenRefreshTransient();
}

/// `invalid_grant`: refresh token отозван/истёк — требуется повторный OAuth.
final class OrbitAccessTokenRefreshInvalidGrant
    extends OrbitAccessTokenRefreshOutcome {
  const OrbitAccessTokenRefreshInvalidGrant();
}
