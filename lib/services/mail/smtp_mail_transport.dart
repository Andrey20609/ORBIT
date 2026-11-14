import 'dart:async';

import '../../data/models/email_record.dart';
import 'mail_connection_verifier.dart';
import 'mail_models.dart';
import 'mail_transport.dart';
import 'orbit_mail_credential_service.dart';
import 'smtp_send_client.dart';
import 'smtp_socket.dart';

/// MAIL-02B: конфигурация контролируемой отправки.
///
/// Разрешённые получатели берутся из dart-define
/// ORBIT_SMTP_ALLOWED_RECIPIENT (один или несколько адресов через
/// запятую). Без конфигурации реальная отправка недоступна — честный
/// CONFIG_REQUIRED (никакой имитации отправки).
class SmtpSendConfig {
  const SmtpSendConfig(this.allowedRecipients);

  final List<String> allowedRecipients;

  bool get isConfigured => allowedRecipients.isNotEmpty;

  static const SmtpSendConfig empty = SmtpSendConfig(<String>[]);

  static SmtpSendConfig fromEnvironment() {
    const raw = String.fromEnvironment('ORBIT_SMTP_ALLOWED_RECIPIENT');
    final recipients = raw
        .split(',')
        .map((address) => address.trim().toLowerCase())
        .where((address) => address.isNotEmpty)
        .toList();
    return SmtpSendConfig(recipients);
  }

  bool allows(String recipient) =>
      allowedRecipients.contains(recipient.trim().toLowerCase());
}

/// MAIL-02B: sanitized итог контролируемой отправки для UI/логов
/// (без секретов; failure message уже sanitized транспортом/очередью).
final class SmtpSendOutcome {
  const SmtpSendOutcome.rejected(this.message)
    : status = 'rejected',
      recordId = null,
      recordStatus = null;

  const SmtpSendOutcome.duplicate(this.message, this.recordId, this.recordStatus)
    : status = 'duplicate';

  SmtpSendOutcome.delivered({
    required this.status,
    required this.message,
    required this.recordId,
  }) : recordStatus = status;

  final String status; // rejected | duplicate | sent | queued | failed
  final String message;
  final String? recordId;
  final String? recordStatus;

  @override
  String toString() => 'SmtpSendOutcome($status): $message';
}

/// Исключение SMTP-транспорта. Сообщение sanitized: без паролей/токенов
/// и сырых ответов сервера.
/// - [isAuthRelated]: серверное отклонение аутентификации -> персистентно
///   notConfigured вызывающей стороной (как MAIL-02A), без retry.
/// - [isTransient]: сетевые/временные ошибки -> retry допустим.
/// - оба false: постоянный отказ (5xx без аутентификации, получатель вне
///   allowlist, неподдерживаемый порт) -> failed без retry.
class SmtpTransportException implements Exception {
  const SmtpTransportException(
    this.message, {
    this.isAuthRelated = false,
    this.isTransient = false,
    this.cause,
  });

  final String message;
  final bool isAuthRelated;
  final bool isTransient;
  final Object? cause;

  @override
  String toString() => 'SmtpTransportException: $message';
}

/// Фабрика SMTP-клиента: production - SmtpSendClient.connect (implicit
/// TLS), тесты - клиент над fake socket.
typedef OrbitSmtpClientFactory =
    Future<SmtpSendClient> Function(OrbitMailAccount account);

/// MAIL-02B: контролируемый SMTP-транспорт.
///
/// - Только implicit TLS (SecureSmtpSocket, onBadCertificate => false);
///   порт только 465 - 587/STARTTLS не поддерживаются в MAIL-02B
///   (честный постоянный отказ, никакой insecure-отправки).
/// - Получатель строго из allowlist [SmtpSendConfig]; проверка выполняется
///   ДО установки соединения (вход в очередь тоже, но транспорт - вторая,
///   глубинная линия защиты).
/// - fetchEmails невозможен: чтение почты - только read-only IMAP
///   (MAIL-02A); SMTP транспорт не читает письма.
final class SmtpMailTransport implements MailTransport {
  SmtpMailTransport({
    required Future<OrbitMailAccount?> Function(String accountId)
    resolveAccount,
    required Future<String?> Function(OrbitMailAccount account)
    resolveAccessToken,
    required OrbitMailCredentialService credentialService,
    required SmtpSendConfig sendConfig,
    OrbitSmtpClientFactory? clientFactory,
  }) : _resolveAccount = resolveAccount,
       _resolveAccessToken = resolveAccessToken,
       _credentialService = credentialService,
       _sendConfig = sendConfig,
       _clientFactory =
           clientFactory ??
           ((OrbitMailAccount account) => SmtpSendClient.connect(
             account.outgoingHost,
             account.outgoingPort,
           ));

  final Future<OrbitMailAccount?> Function(String accountId) _resolveAccount;
  final Future<String?> Function(OrbitMailAccount account) _resolveAccessToken;
  final OrbitMailCredentialService _credentialService;
  final SmtpSendConfig _sendConfig;
  final OrbitSmtpClientFactory _clientFactory;

  /// SMTP не читает почту (read-only чтение - MAIL-02A IMAP).
  @override
  Future<List<EmailRecord>> fetchEmails({
    required String folder,
    int limit = 50,
    String? accountId,
  }) async {
    throw UnsupportedError('Чтение почты недоступно через SMTP-транспорт');
  }

  /// Контролируемая отправка одного письма. Возвращает true ТОЛЬКО после
  /// 250 на DATA (точка принятия сервером). Любой отказ - sanitized
  /// [SmtpTransportException] с классификацией.
  @override
  Future<bool> sendEmail(QueuedOutgoingEmail outgoing) async {
    final recipient = outgoing.to.trim().toLowerCase();
    if (!_sendConfig.allows(recipient)) {
      throw const SmtpTransportException(
        'Получатель вне разрешённого списка контролируемой отправки',
      );
    }
    final account = await _resolveAccount(outgoing.accountId ?? '');
    if (account == null) {
      throw const SmtpTransportException('Аккаунт не найден');
    }
    if (account.isDemo) {
      throw const SmtpTransportException(
        'Демо-аккаунт не отправляет письма через SMTP',
      );
    }
    if (account.outgoingPort != 465) {
      throw const SmtpTransportException(
        'Поддерживается только implicit TLS порт 465',
      );
    }
    SmtpSendClient? client;
    try {
      client = await _clientFactory(account);
      await client.ehlo('orbit');
      await _authenticate(client, account);
      await client.mailFrom(account.email);
      await client.rcptTo(recipient);
      final accepted = await client.data(outgoing.subject, outgoing.body);
      try {
        await client.quit();
      } catch (_) {
        // QUIT не влияет на факт принятия письма.
      }
      return accepted;
    } on SmtpAuthException {
      client?.destroy();
      throw const SmtpTransportException(
        'Сервер отклонил аутентификацию: проверьте учётные данные',
        isAuthRelated: true,
      );
    } on SmtpRejectException catch (error) {
      client?.destroy();
      throw SmtpTransportException(
        'Сервер отклонил письмо',
        cause: error,
      );
    } on SmtpConnectionException catch (error) {
      client?.destroy();
      throw SmtpTransportException(
        'Ошибка соединения с SMTP-сервером',
        isTransient: true,
        cause: error,
      );
    } on SmtpTransportException {
      client?.destroy();
      rethrow;
    } catch (error) {
      client?.destroy();
      throw SmtpTransportException(
        'Отправка не выполнена',
        isTransient: true,
        cause: error,
      );
    }
  }

  Future<void> _authenticate(
    SmtpSendClient client,
    OrbitMailAccount account,
  ) async {
    final isOAuth =
        account.providerType == OrbitMailProviderType.gmail ||
        account.providerType == OrbitMailProviderType.outlook ||
        account.authMethod == 'oauth';
    if (isOAuth) {
      final token = await _resolveAccessToken(account);
      if (token == null || token.isEmpty) {
        // Причина уже отражена в metadata lifecycle'ем (как MAIL-02A):
        // транспорт не маркирует это как auth rejection.
        throw const SmtpTransportException(
          'OAuth-токен недоступен: повторите вход через браузер',
          isTransient: true,
        );
      }
      await client.authXoauth2(account.email, token);
    } else {
      final password = await _credentialService.readAppPasswordForTransport(
        account.id,
      );
      if (password == null || password.isEmpty) {
        throw const SmtpTransportException(
          'Пароль приложения не настроен',
          isAuthRelated: true,
        );
      }
      await client.authLogin(account.email, password);
    }
  }
}
