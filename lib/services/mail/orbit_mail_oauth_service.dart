import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import 'mail_connection_verifier.dart' show OrbitMailAccount;

/// MAIL-01B: provider configuration из `--dart-define`. Никаких реальных
/// client IDs/secrets в source: отсутствующая конфигурация даёт явный
/// [OrbitOAuthConfigRequiredException] ДО открытия browser.
/// MAIL-01B: конфигурация OAuth. Production передаёт только из
/// dart-define (см. OrbitMailOAuthConfig); тестовая среда подставляет
/// значения напрямую (dart-define в тестах недоступен).
class OrbitMailOAuthConfigOverride {
  const OrbitMailOAuthConfigOverride({
    required this.googleClientId,
    required this.outlookClientId,
    this.outlookTenant = 'common',
    this.redirectUri = 'app.orbit.orbit_visual_lab:/oauthredirect',
  });

  final String googleClientId;
  final String outlookClientId;
  final String outlookTenant;
  final String redirectUri;
}

abstract final class OrbitMailOAuthConfig {
  static const String _googleClientId = String.fromEnvironment(
    'ORBIT_GOOGLE_CLIENT_ID',
  );
  static const String _outlookClientId = String.fromEnvironment(
    'ORBIT_OUTLOOK_CLIENT_ID',
  );
  static const String _outlookTenant = String.fromEnvironment(
    'ORBIT_OUTLOOK_TENANT',
    defaultValue: 'common',
  );
  static const String _redirectUri = String.fromEnvironment(
    'ORBIT_OAUTH_REDIRECT_URI',
    defaultValue: 'app.orbit.orbit_visual_lab:/oauthredirect',
  );

  /// Lowercase scheme, must match the Android `appAuthRedirectScheme`
  /// manifest placeholder and the provider console registration exactly.
  static String get redirectUri => _redirectUri;

  static bool get hasGoogleClientId => _googleClientId.isNotEmpty;
  static bool get hasOutlookClientId => _outlookClientId.isNotEmpty;

  static String get googleClientId => _googleClientId;
  static String get outlookClientId => _outlookClientId;
  static String get outlookTenant => _outlookTenant;
}

/// MAIL-01B: provider definition (issuer/scopes по ТЗ, минимально
/// необходимые для будущего IMAP/SMTP — без Drive/Calendar/Contacts).
enum OrbitOAuthProvider {
  google(
    issuer: 'https://accounts.google.com',
    scopes: <String>[
      'openid',
      'email',
      'https://mail.google.com/',
    ],
    requiresOfflineAccess: true,
  ),
  outlook(
    issuer: 'https://login.microsoftonline.com/common/v2.0',
    scopes: <String>[
      'openid',
      'email',
      'offline_access',
      'IMAP.AccessAsUser.All',
      'SMTP.Send',
    ],
    requiresOfflineAccess: true,
  );

  const OrbitOAuthProvider({
    required this.issuer,
    required this.scopes,
    required this.requiresOfflineAccess,
  });

  /// Базовый issuer (для Outlook tenant подставляется при сборке запроса).
  final String issuer;
  final List<String> scopes;
  final bool requiresOfflineAccess;

  /// Фактический issuer с учётом tenant (Outlook: `/common/v2.0` или
  /// конкретный tenant из config).
  String issuerFor(String outlookTenant) => switch (this) {
        OrbitOAuthProvider.outlook =>
          'https://login.microsoftonline.com/$outlookTenant/v2.0',
        _ => issuer,
      };
}

/// Набор OAuth-токенов. Никогда не сериализуется в model/JSON/snapshot —
/// только secure storage через OrbitMailCredentialService.
@immutable
final class OrbitOAuthTokenSet {
  const OrbitOAuthTokenSet({
    required this.accessToken,
    required this.expiryUtc,
    this.refreshToken,
    this.tokenType = 'Bearer',
  });

  final String accessToken;

  /// Может отсутствовать: provider не выдал новый refresh token (тогда
  /// прежний сохраняется — rotation по факту наличия).
  final String? refreshToken;

  /// UTC expiry access token'а.
  final DateTime expiryUtc;
  final String tokenType;
}

/// Конфигурация OAuth не предоставлена (`--dart-define` без client ID) —
/// browser не открывается.
class OrbitOAuthConfigRequiredException implements Exception {
  const OrbitOAuthConfigRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Пользователь закрыл browser — прежнее состояние без ошибки и токенов.
class OrbitOAuthUserCancelledException implements Exception {
  const OrbitOAuthUserCancelledException();
}

/// Сервер вернул `invalid_grant` — refresh token больше недействителен,
/// требуется повторный OAuth.
class OrbitOAuthInvalidGrantException implements Exception {
  const OrbitOAuthInvalidGrantException();
}

/// Временная ошибка (сеть/сервер) — retry возможен с сохранённым refresh.
class OrbitOAuthTransientException implements Exception {
  const OrbitOAuthTransientException();
}

/// Узкая абстракция вокруг AppAuth: production использует системный
/// browser/Custom Tabs (НЕ embedded WebView); PKCE, state и nonce
/// генерирует сам AppAuth. Тесты подставляют mock double.
abstract interface class OrbitOAuthClient {
  Future<OrbitOAuthTokenSet> authorize({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
  });

  Future<OrbitOAuthTokenSet> refresh({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
    required String refreshToken,
  });
}

/// Production-реализация поверх `flutter_appauth`.
final class AppAuthOAuthClient implements OrbitOAuthClient {
  const AppAuthOAuthClient();

  static const FlutterAppAuth _appAuth = FlutterAppAuth();

  /// MAIL-01B r2 fix (блокер 3): null/пустой access token — неуспешный
  /// ответ: ничего не сохраняется, sanitized transient-ошибка.
  OrbitOAuthTokenSet _mapAuthorizationTokenResponse(
    AuthorizationTokenResponse response,
  ) {
    final access = response.accessToken;
    if (access == null || access.isEmpty) {
      throw const OrbitOAuthTransientException();
    }
    return OrbitOAuthTokenSet(
      accessToken: access,
      refreshToken: response.refreshToken,
      expiryUtc:
          response.accessTokenExpirationDateTime ?? DateTime.now().toUtc(),
      tokenType: response.tokenType ?? 'Bearer',
    );
  }

  /// MAIL-01B r2 fix (блокер 3): null/пустой access token — неуспешный
  /// ответ: прежний набор не перезаписывается, sanitized transient-ошибка.
  OrbitOAuthTokenSet _mapTokenResponse(TokenResponse response) {
    final access = response.accessToken;
    if (access == null || access.isEmpty) {
      throw const OrbitOAuthTransientException();
    }
    return OrbitOAuthTokenSet(
      accessToken: access,
      refreshToken: response.refreshToken,
      expiryUtc:
          response.accessTokenExpirationDateTime ?? DateTime.now().toUtc(),
      tokenType: response.tokenType ?? 'Bearer',
    );
  }

  /// Классификация ошибок AppAuth: cancel / invalid_grant / transient.
  /// Сообщения исключений НЕ включают токены/код/callback URL.
  Never _mapError(Object error) {
    if (error is FlutterAppAuthUserCancelledException) {
      throw OrbitOAuthUserCancelledException();
    }
    if (error is FlutterAppAuthPlatformException) {
      final oauthError = error.platformErrorDetails.error;
      if (oauthError == FlutterAppAuthOAuthError.invalidGrant) {
        throw const OrbitOAuthInvalidGrantException();
      }
      throw const OrbitOAuthTransientException();
    }
    if (error is PlatformException) {
      // Часть ошибок token-endpoint приходит как PlatformException без
      // Platform wrapper: классифицируем по коду.
      if (error.code == FlutterAppAuthOAuthError.invalidGrant ||
          (error.message ?? '').contains('invalid_grant')) {
        throw const OrbitOAuthInvalidGrantException();
      }
      throw const OrbitOAuthTransientException();
    }
    throw const OrbitOAuthTransientException();
  }

  @override
  Future<OrbitOAuthTokenSet> authorize({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
  }) async {
    try {
      // MAIL-01B r2 fix (блокер 2): Google выдаёт refresh token только при
      // access_type=offline в authorization request. Outlook получает
      // offline_access через scope и дополнительный параметр не требует.
      final additionalParameters =
          issuer == 'https://accounts.google.com'
              ? const <String, String>{'access_type': 'offline'}
              : null;
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUri,
          scopes: scopes,
          issuer: issuer,
          additionalParameters: additionalParameters,
        ),
      );
      return _mapAuthorizationTokenResponse(response);
    } catch (error) {
      _mapError(error);
    }
  }

  @override
  Future<OrbitOAuthTokenSet> refresh({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
    required String refreshToken,
  }) async {
    try {
      final response = await _appAuth.token(
        TokenRequest(
          clientId,
          redirectUri,
          scopes: scopes,
          issuer: issuer,
          refreshToken: refreshToken,
          // grantType выводится из refreshToken (refresh_token grant).
        ),
      );
      return _mapTokenResponse(response);
    } catch (error) {
      _mapError(error);
    }
  }
}


/// Итог OAuth-входа для UI: sanitized-сообщение (без токенов/кода) и
/// созданный аккаунт при успехе.
enum OrbitMailOAuthUiStatus { success, cancelled, configRequired, invalidGrant, error }

final class OrbitMailOAuthUiOutcome {
  const OrbitMailOAuthUiOutcome.success(this.account)
    : status = OrbitMailOAuthUiStatus.success,
      message = null;

  const OrbitMailOAuthUiOutcome.cancelled()
    : status = OrbitMailOAuthUiStatus.cancelled,
      message = null,
      account = null;

  const OrbitMailOAuthUiOutcome.configRequired(this.message)
    : status = OrbitMailOAuthUiStatus.configRequired,
      account = null;

  const OrbitMailOAuthUiOutcome.invalidGrant(this.message)
    : status = OrbitMailOAuthUiStatus.invalidGrant,
      account = null;

  const OrbitMailOAuthUiOutcome.error(this.message)
    : status = OrbitMailOAuthUiStatus.error,
      account = null;

  final OrbitMailOAuthUiStatus status;
  final String? message;
  final OrbitMailAccount? account;

  bool get isSuccess => status == OrbitMailOAuthUiStatus.success;
}
