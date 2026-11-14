import 'dart:async';

import '../../data/models/email_record.dart';
import 'imap_readonly_client.dart';
import 'imap_socket.dart';
import 'mail_connection_verifier.dart';
import 'mail_models.dart';
import 'mail_transport.dart';
import 'orbit_mail_credential_service.dart';

/// Фабрика IMAP-клиента: production - ImapReadOnlyClient.connect
/// (implicit TLS 993), тесты - клиент над fake socket.
typedef OrbitImapClientFactory =
    Future<ImapReadOnlyClient> Function(OrbitMailAccount account);

/// Исключение IMAP-транспорта. Сообщение sanitized: без email, пароля,
/// токенов и сырых ответов сервера. [isAuthRelated] - СЕРВЕРНОЕ отклонение
/// аутентификации (NO на LOGIN/XOAUTH2) либо явно не настроенный
/// app password: по ТЗ MAIL-02A §5 вызывающая сторона переводит metadata
/// персистентно в notConfigured без автоматических повторов. Для
/// отсутствующего OAuth-токена флаг НЕ ставится: причина (transient
/// refresh / invalid_grant / нет набора) уже разрулена lifecycle'ем в
/// OrbitMailCredentialService.getValidAccessToken и отражена в metadata;
/// транспорт сообщает sanitized-факт, исход трактуется как transient
/// (savedUnverified, retry доступен).
class ImapTransportException implements Exception {
  const ImapTransportException(
    this.message, {
    this.isAuthRelated = false,
    this.cause,
  });

  final String message;
  final bool isAuthRelated;
  final Object? cause;

  @override
  String toString() => 'ImapTransportException: $message';
}

/// MAIL-02A: настоящий read-only IMAP транспорт.
///
/// - Аутентификация: app password (Yandex/Mail.ru/custom) или XOAUTH2
///   (Gmail/Outlook) через существующий refresh lifecycle
///   (OrbitMailCredentialService.getValidAccessToken).
/// - Только implicit TLS порт 993 с проверкой сертификата
///   (ImapReadOnlyClient.connect -> SecureImapSocket); insecure fallback
///   в коде отсутствует.
/// - EXAMINE + BODY.PEEK + UID FETCH, максимум [maxFetchLimit] писем за
///   синхронизацию; серверное состояние не изменяется.
/// - Cache только metadata (sender/subject/preview/timestamp/flags),
///   без тела, HTML и вложений; детерминированный id
///   accountId:folder:uidValidity:uid - синхронизация идемпотентна.
/// - [sendEmail] намеренно не реализуем: SMTP вне объёма MAIL-02A.
final class ImapMailTransport implements MailTransport {
  ImapMailTransport({
    required Future<OrbitMailAccount?> Function(String accountId)
    resolveAccount,
    required Future<String?> Function(OrbitMailAccount account)
    resolveAccessToken,
    required OrbitMailCredentialService credentialService,
    OrbitImapClientFactory? clientFactory,
    this.fetchLimit = maxFetchLimit,
  }) : _resolveAccount = resolveAccount,
       _resolveAccessToken = resolveAccessToken,
       _credentialService = credentialService,
       _clientFactory =
           clientFactory ??
           ((OrbitMailAccount account) => ImapReadOnlyClient.connect(
             account.incomingHost,
           ));

  /// ТЗ: максимум 20 писем за одну синхронизацию.
  static const int maxFetchLimit = 20;

  final int fetchLimit;
  final Future<OrbitMailAccount?> Function(String accountId) _resolveAccount;
  final Future<String?> Function(OrbitMailAccount account) _resolveAccessToken;
  final OrbitMailCredentialService _credentialService;
  final OrbitImapClientFactory _clientFactory;

  /// IMAP-флаги содержат backslash (Seen, Flagged); литерал строится в
  /// рантайме, чтобы исходник не содержал escape-последовательностей.
  static final String seenFlag = '${String.fromCharCode(92)}Seen';
  static final String flaggedFlag = '${String.fromCharCode(92)}Flagged';

  @override
  Future<List<EmailRecord>> fetchEmails({
    required String folder,
    int limit = 50,
    String? accountId,
  }) async {
    if (accountId == null || accountId.isEmpty) {
      throw const ImapTransportException(
        'Не указан аккаунт для IMAP-синхронизации',
      );
    }
    final account = await _resolveAccount(accountId);
    if (account == null) {
      throw const ImapTransportException('Аккаунт не найден');
    }
    if (account.isDemo) {
      throw const ImapTransportException(
        'Демо-аккаунт не синхронизируется по IMAP',
      );
    }
    final effectiveLimit = limit.clamp(1, maxFetchLimit);
    ImapReadOnlyClient? client;
    try {
      client = await _clientFactory(account);
      await _authenticate(client, account);
      final uidValidity = await client.examineInbox();
      final uids = await client.uidSearchAll();
      final metadata = await client.fetchRecentMetadata(
        uidValidity: uidValidity,
        uids: uids,
        limit: effectiveLimit < fetchLimit ? effectiveLimit : fetchLimit,
      );
      try {
        await client.logout();
      } catch (_) {
        // LOGOUT не влияет на результат синхронизации.
      }
      return metadata
          .map((message) => _toRecord(message, account))
          .toList();
    } on ImapAuthException {
      client?.destroy();
      throw const ImapTransportException(
        'Сервер отклонил аутентификацию: проверьте учётные данные',
        isAuthRelated: true,
      );
    } on ImapProtocolException catch (error) {
      client?.destroy();
      throw ImapTransportException('Ошибка протокола IMAP', cause: error);
    } on ImapConnectionException catch (error) {
      client?.destroy();
      throw ImapTransportException(
        'Ошибка соединения с IMAP-сервером',
        cause: error,
      );
    } on ImapTransportException {
      client?.destroy();
      rethrow;
    } catch (error) {
      client?.destroy();
      throw ImapTransportException('Синхронизация не выполнена', cause: error);
    }
  }

  /// SMTP не входит в MAIL-02A: отправка писем через этот транспорт
  /// невозможна по построению.
  @override
  Future<bool> sendEmail(QueuedOutgoingEmail outgoing) async {
    throw UnsupportedError('Отправка писем недоступна: read-only IMAP');
  }

  Future<void> _authenticate(
    ImapReadOnlyClient client,
    OrbitMailAccount account,
  ) async {
    final isOAuth =
        account.providerType == OrbitMailProviderType.gmail ||
        account.providerType == OrbitMailProviderType.outlook ||
        account.authMethod == 'oauth';
    if (isOAuth) {
      final token = await _resolveAccessToken(account);
      if (token == null || token.isEmpty) {
        // Причина (transient refresh / invalid_grant / нет набора)
        // уже отражена в metadata lifecycle'ем (getValidAccessToken):
        // транспорт НЕ маркирует это как auth rejection.
        throw const ImapTransportException(
          'OAuth-токен недоступен: повторите вход через браузер',
        );
      }
      await client.authenticateXoauth2(account.email, token);
    } else {
      final password = await _credentialService.readAppPasswordForTransport(
        account.id,
      );
      if (password == null || password.isEmpty) {
        throw const ImapTransportException(
          'Пароль приложения не настроен',
          isAuthRelated: true,
        );
      }
      await client.login(account.email, password);
    }
  }

  /// Metadata -> EmailRecord: детерминированный id, folder inbox,
  /// recipient - адрес аккаунта (INBOX владельца), тело НЕ сохраняется
  /// (metadata-only cache по ТЗ).
  EmailRecord _toRecord(ImapMessageMetadata message, OrbitMailAccount account) {
    const folder = 'inbox';
    return EmailRecord(
      id: message.deterministicId(account.id, folder),
      workspaceId: '',
      accountId: account.id,
      folder: folder,
      sender: message.from.isEmpty ? account.email : message.from,
      recipient: account.email,
      subject: message.subject,
      preview: message.preview,
      // Metadata-only: тело не запрашивается и не кэшируется.
      body: '',
      timestamp: parseInternalDate(message.internalDateIso),
      // Флаги отражают состояние сервера на момент чтения; изменение
      // флагов на сервере этим клиентом невозможно (нет STORE).
      isRead: message.flags.contains(seenFlag),
      isFlagged: message.flags.contains(flaggedFlag),
      hasAttachments: false,
    );
  }

  /// Парсинг INTERNALDATE вида "14-Nov-2026 12:00:00 +0300" в UTC.
  /// Неразбираемое значение -> epoch (детерминированность синхронизации).
  static DateTime parseInternalDate(String raw) {
    final parts = raw
        .trim()
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) return DateTime.utc(1970);
    final dateParts = parts[0].split('-');
    if (dateParts.length != 3) return DateTime.utc(1970);
    final day = int.tryParse(dateParts[0]);
    final month = _monthNames.indexOf(dateParts[1]) + 1;
    final year = int.tryParse(dateParts[2]);
    final timeParts = parts[1].split(':');
    if (day == null || month < 1 || year == null || timeParts.length < 3) {
      return DateTime.utc(1970);
    }
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;
    final second = int.tryParse(timeParts[2]) ?? 0;
    var value = DateTime.utc(year, month, day, hour, minute, second);
    if (parts.length >= 3 && parts[2].length == 5) {
      final tz = parts[2];
      final isNegative = tz.startsWith('-');
      final body = isNegative || tz.startsWith('+') ? tz.substring(1) : tz;
      final tzHours = int.tryParse(body.substring(0, 2)) ?? 0;
      final tzMinutes = int.tryParse(body.substring(2)) ?? 0;
      final offset = Duration(hours: tzHours, minutes: tzMinutes);
      value = isNegative ? value.add(offset) : value.subtract(offset);
    }
    return value;
  }

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
