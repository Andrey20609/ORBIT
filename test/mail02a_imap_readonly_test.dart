import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/core/module_interfaces.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/demo_data.dart';
import 'package:orbit_visual_lab/data/drift_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_secure_store.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/services/mail/imap_mail_transport.dart';
import 'package:orbit_visual_lab/services/mail/imap_readonly_client.dart';
import 'package:orbit_visual_lab/services/mail/imap_socket.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';
import 'package:orbit_visual_lab/services/mail/mail_models.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_credential_service.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_oauth_service.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_real_inbox_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Тестовые значения: синтетические, генерируются сценарием, не являются
// паттернами реальных паролей. В raw-логи тестов не выводятся (только
// assert-проверки).
const String _apPassword = 'MAIL02A-TEST-APP-PASSWORD-z8q1';
const String _oauthAccessToken = 'MAIL02A-TEST-ACCESS-t5n7';

// IMAP-спецсимволы строятся в рантайме: флаги сервера содержат backslash,
// literal-заголовки содержат CRLF, XOAUTH2 содержит NUL.
final String _bs = String.fromCharCode(92);
final String _nul = String.fromCharCode(0);
final String _crlf =
    String.fromCharCode(13) + String.fromCharCode(10);

OrbitMailAccount _apAccount() => const OrbitMailAccount(
      id: 'acc_ap',
      name: 'Тестовый ящик',
      email: 'unit.ap@test.local',
      providerType: OrbitMailProviderType.yandex,
      incomingHost: 'imap.yandex.ru',
      incomingPort: 993,
      outgoingHost: 'smtp.yandex.ru',
      outgoingPort: 465,
      credentialStatus: OrbitMailCredentialStatus.savedUnverified,
      authMethod: 'appPassword',
      isActive: true,
    );

OrbitMailAccount _oauthAccount() => const OrbitMailAccount(
      id: 'acc_oauth',
      name: 'OAuth ящик',
      email: 'unit.oauth@test.local',
      providerType: OrbitMailProviderType.gmail,
      incomingHost: 'imap.gmail.com',
      incomingPort: 993,
      outgoingHost: 'smtp.gmail.com',
      outgoingPort: 465,
      credentialStatus: OrbitMailCredentialStatus.savedUnverified,
      authMethod: 'oauth',
      isActive: true,
    );

String _headerLiteral({required String from, required String subject}) =>
    'From: $from$_crlf Subject: $subject$_crlf$_crlf';

/// Полный scripted-ответ сервера на EXAMINE/SEARCH/FETCH (read-only
/// последовательность), см. ImapReadOnlyClient._sendCommand.
List<String> _examineResponses({required int uidValidity, String tag = 'A2'}) => [
      '* FLAGS ($_bs' 'Answered $_bs' 'Flagged $_bs' 'Seen)',
      '* 2 EXISTS',
      '* OK [UIDVALIDITY $uidValidity] UIDs valid',
      '$tag OK [READ-ONLY] EXAMINE completed',
    ];

List<String> _fetchResponses({
  required int seq,
  required int uid,
  required bool seen,
  required String header,
  required String text,
}) {
  final flags = seen ? '($_bs' 'Seen)' : '()';
  final headerOctets = utf8.encode(header).length;
  final textOctets = utf8.encode(text).length;
  return [
    '* $seq FETCH (UID $uid FLAGS $flags INTERNALDATE '
        '"14-Nov-2026 10:00:00 +0300" '
        'BODY[HEADER.FIELDS (FROM SUBJECT DATE)] {$headerOctets}',
    header,
    ' BODY[TEXT]<0.512> {$textOctets}',
    text,
    ')',
  ];
}

/// Fake IMAP socket: scripted readLine/readUtf8Octets очереди + capture
/// всех записанных строк (raw). Credentials в capturedCommands клиента
/// redacted; raw writes используются ТОЛЬКО для assert-проверок.
final class _FakeImapSocket implements OrbitImapSocket {
  _FakeImapSocket({
    List<String> lines = const [],
    List<String> literals = const [],
  })  : _lines = List.of(lines),
        _literals = List.of(literals);

  final List<String> _lines;
  final List<String> _literals;
  final List<String> written = <String>[];
  final List<Completer<String>> _pendingReads = <Completer<String>>[];
  bool hangReads = false;
  bool hangWrites = false;
  bool destroyed = false;

  @override
  Future<void> writeLine(String line) async {
    written.add(line);
    if (hangWrites) {
      // Запись «залипает»: никогда не завершается (stalled write).
      await Completer<void>().future;
    }
  }

  @override
  Future<String> readLine() async {
    if (hangReads) {
      final completer = Completer<String>();
      _pendingReads.add(completer);
      return completer.future;
    }
    if (_lines.isEmpty) {
      throw const ImapConnectionException('Скрипт ответов исчерпан');
    }
    return _lines.removeAt(0);
  }

  @override
  Future<String> readUtf8Octets(int octets) async {
    if (_literals.isEmpty) {
      throw const ImapConnectionException('Нет literal-данных');
    }
    final blob = _literals.removeAt(0);
    if (utf8.encode(blob).length != octets) {
      throw const ImapConnectionException('Octets mismatch');
    }
    return blob;
  }

  @override
  void destroy() {
    destroyed = true;
  }

  /// Завершает зависшие чтения ошибкой (cleanup double-start теста).
  void failPending() {
    hangReads = false;
    for (final completer in _pendingReads) {
      completer.completeError(
        const ImapConnectionException('Тест завершён'),
      );
    }
    _pendingReads.clear();
  }
}

ImapReadOnlyClient _clientOver(_FakeImapSocket socket) {
  final client = ImapReadOnlyClient.forSocket(socket);
  return client;
}

/// Сценарий успешной read-only сессии (app password): LOGIN, EXAMINE,
/// UID SEARCH, UID FETCH 101:102, LOGOUT.
List<String> _apSessionLines({
  required String header1,
  required String text1,
  required String header2,
  required String text2,
}) => [
      'A1 OK LOGIN completed',
      ..._examineResponses(uidValidity: 424242),
      '* SEARCH 101 102',
      'A3 OK SEARCH completed',
      ..._fetchResponses(
        seq: 1,
        uid: 102,
        seen: true,
        header: header1,
        text: text1,
      ),
      ..._fetchResponses(
        seq: 2,
        uid: 101,
        seen: false,
        header: header2,
        text: text2,
      ),
      'A4 OK FETCH completed',
      '* BYE IMAP4rev1 Server logging out',
      'A5 OK LOGOUT completed',
    ];

OrbitMailCredentialService _serviceWithApPassword() {
  final service = OrbitMailCredentialService(store: MemoryOrbitSecretStore());
  unawaited(
    service.saveAppPassword(accountId: 'acc_ap', appPassword: _apPassword),
  );
  return service;
}

/// Counting OAuth double для end-to-end lifecycle-регрессий MAIL-02A
/// (refresh не более 1 раза, retry не более 1 раза, rotation, исходы).
final class _CountingOAuthClient implements OrbitOAuthClient {
  _CountingOAuthClient(this.refreshOutcome);

  /// 'success' | 'transient' | 'invalidGrant'
  final String refreshOutcome;
  int refreshCalls = 0;

  @override
  Future<OrbitOAuthTokenSet> authorize({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
  }) async {
    throw UnimplementedError('authorize не участвует в MAIL-02A регрессиях');
  }

  @override
  Future<OrbitOAuthTokenSet> refresh({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
    required String refreshToken,
  }) async {
    refreshCalls++;
    switch (refreshOutcome) {
      case 'transient':
        throw const OrbitOAuthTransientException();
      case 'invalidGrant':
        throw const OrbitOAuthInvalidGrantException();
    }
    // Успешный refresh с rotation: новый refresh token выдаётся.
    return OrbitOAuthTokenSet(
      accessToken: 'refreshed-access-$refreshCalls-'
          '${DateTime.now().microsecondsSinceEpoch}',
      refreshToken: 'r2-refreshed-$refreshCalls',
      expiryUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MAIL-02A read-only IMAP (TLS mandatory)', () {
    test('[M1] implicit TLS only: подключение к plain-порту невозможно',
        () async {
      // Plain TCP-сервер: TLS-handshake клиента против него обязан
      // провалиться — insecure/STARTTLS fallback в коде отсутствует.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) {
        socket.destroy();
      });
      await expectLater(
        SecureImapSocket.connect(
          '127.0.0.1',
          server.port,
          readTimeout: const Duration(seconds: 3),
          writeTimeout: const Duration(seconds: 3),
          connectTimeout: const Duration(seconds: 3),
        ),
        throwsA(anything),
      );
    });

    test('[M2] bad certificate: самоподписанный сертификат отвергается',
        () async {
      // onBadCertificate => false: неверифицируемый сертификат -> отказ
      // handshake ДО отправки каких-либо команд.
      final context = SecurityContext()
        ..useCertificateChain('test/fixtures/imap_tls/server.crt')
        ..usePrivateKey('test/fixtures/imap_tls/server.key');
      final server = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      addTearDown(server.close);
      server.listen((socket) {
        socket.destroy();
      });
      await expectLater(
        SecureImapSocket.connect(
          '127.0.0.1',
          server.port,
          readTimeout: const Duration(seconds: 3),
          writeTimeout: const Duration(seconds: 3),
          connectTimeout: const Duration(seconds: 3),
        ),
        throwsA(isA<HandshakeException>()),
      );
    });
  });

  group('MAIL-02A read-only protocol (app password)', () {
    test('[M3] protocol capture: LOGIN/EXAMINE/SEARCH/FETCH/LOGOUT, '
        'credentials redacted', () async {
      final header1 = _headerLiteral(
        from: 'Alice <alice@example.test>',
        subject: 'Weekly report',
      );
      final header2 = _headerLiteral(
        from: 'bob@example.test',
        subject: 'Тестовое письмо',
      );
      final text1 =
          'Hello$_nul${String.fromCharCode(7)} world body fragment';
      final text2 = 'Second message preview text';
      final socket = _FakeImapSocket(
        lines: _apSessionLines(
          header1: header1,
          text1: text1,
          header2: header2,
          text2: text2,
        ),
        literals: [header1, text1, header2, text2],
      );
      final client = _clientOver(socket);
      final transport = ImapMailTransport(
        resolveAccount: (id) async => id == 'acc_ap' ? _apAccount() : null,
        resolveAccessToken: (account) async => _oauthAccessToken,
        credentialService: _serviceWithApPassword(),
        clientFactory: (account) async => client,
      );

      final emails = await transport.fetchEmails(
        folder: 'inbox',
        accountId: 'acc_ap',
      );
      expect(emails.length, 2);

      // Последовательность команд строго read-only.
      final verbs = socket.written
          .map((line) => line.split(' ')[1])
          .toList();
      expect(verbs, ['LOGIN', 'EXAMINE', 'UID', 'UID', 'LOGOUT']);
      // EXAMINE (не SELECT): read-only выбор папки.
      expect(socket.written[1], 'A2 EXAMINE "INBOX"');
      // UID SEARCH ALL.
      expect(socket.written[2], 'A3 UID SEARCH ALL');
      // Точная команда FETCH: только metadata, BODY.PEEK (тело не
      // помечается прочитанным), максимум октетов preview.
      expect(
        socket.written[3],
        'A4 UID FETCH 101:102 (UID FLAGS INTERNALDATE '
        'BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)] '
        'BODY.PEEK[TEXT]<0.512>)',
      );
      // LOGOUT завершает сессию.
      expect(socket.written[4], 'A5 LOGOUT');

      // capturedCommands: credentials redacted, пароль не попадает.
      final captured = client.capturedCommands;
      expect(captured.first, 'A1 LOGIN [credentials redacted]');
      for (final line in captured) {
        expect(line.contains(_apPassword), isFalse);
      }
    });

    test('[M4] XOAUTH2: base64(user NUL auth=Bearer NUL NUL), redacted',
        () async {
      final header = _headerLiteral(
        from: 'alice@example.test',
        subject: 'OAuth letter',
      );
      final text = 'OAuth preview';
      final socket = _FakeImapSocket(
        lines: [
          'A1 OK AUTHENTICATE completed',
          ..._examineResponses(uidValidity: 777),
          '* SEARCH 500',
          'A3 OK SEARCH completed',
          ..._fetchResponses(
            seq: 1,
            uid: 500,
            seen: false,
            header: header,
            text: text,
          ),
          'A4 OK FETCH completed',
          'A5 OK LOGOUT completed',
        ],
        literals: [header, text],
      );
      final client = _clientOver(socket);
      final transport = ImapMailTransport(
        resolveAccount: (id) async =>
            id == 'acc_oauth' ? _oauthAccount() : null,
        resolveAccessToken: (account) async => _oauthAccessToken,
        credentialService: _serviceWithApPassword(),
        clientFactory: (account) async => client,
      );

      final emails = await transport.fetchEmails(
        folder: 'inbox',
        accountId: 'acc_oauth',
      );
      expect(emails.length, 1);

      final firstWrite = socket.written.first;
      const prefix = 'A1 AUTHENTICATE XOAUTH2 ';
      expect(firstWrite.startsWith(prefix), isTrue);
      final decoded = utf8.decode(
        base64.decode(firstWrite.substring(prefix.length)),
      );
      expect(
        decoded,
        'user=unit.oauth@test.local$_nul'
        'auth=Bearer $_oauthAccessToken$_nul$_nul',
      );
      // Redaction покрывает AUTHENTICATE тоже: токен не в captured.
      for (final line in client.capturedCommands) {
        expect(line.contains(_oauthAccessToken), isFalse);
      }
      expect(client.capturedCommands.first, 'A1 LOGIN [credentials redacted]');
    });

    test('[M5] нет mutating-команд: только LOGIN/EXAMINE/UID SEARCH/'
        'UID FETCH(BODY.PEEK)/LOGOUT', () async {
      final header = _headerLiteral(
        from: 'carol@example.test',
        subject: 'Any subject',
      );
      final text = 'Preview body';
      final socket = _FakeImapSocket(
        lines: _apSessionLines(
          header1: header,
          text1: text,
          header2: header,
          text2: text,
        ),
        literals: [header, text, header, text],
      );
      final transport = ImapMailTransport(
        resolveAccount: (id) async => id == 'acc_ap' ? _apAccount() : null,
        resolveAccessToken: (account) async => _oauthAccessToken,
        credentialService: _serviceWithApPassword(),
        clientFactory: (account) async => _clientOver(socket),
      );

      await transport.fetchEmails(folder: 'inbox', accountId: 'acc_ap');

      const forbidden = [
        'STORE',
        'EXPUNGE',
        'DELETE',
        'MOVE ',
        'COPY',
        'APPEND',
        'CREATE',
        'RENAME',
        'SETACL',
        'SUBSCRIBE',
        'SMTP',
        'RFC822',
      ];
      for (final line in socket.written) {
        for (final token in forbidden) {
          expect(
            line.contains(token),
            isFalse,
            reason: 'Mutating/запрещённая команда в raw-записи: $line',
          );
        }
      }
      // EXAMINE вместо SELECT; TEXT только через BODY.PEEK.
      expect(socket.written[1], 'A2 EXAMINE "INBOX"');
      expect(socket.written[3].contains('BODY.PEEK[TEXT]<'), isTrue);
    });
  });

  group('MAIL-02A mapping и ограничения', () {
    test('[M6] mapping: детерминированный id, metadata-only, флаги, UTC',
        () async {
      final header1 = _headerLiteral(
        from: 'Alice <alice@example.test>',
        subject: 'Weekly report',
      );
      final header2 = _headerLiteral(
        from: 'bob@example.test',
        subject: 'Тестовое письмо',
      );
      final text1 = 'Hello world body fragment';
      final text2 = 'Second message preview text';
      final socket = _FakeImapSocket(
        lines: _apSessionLines(
          header1: header1,
          text1: text1,
          header2: header2,
          text2: text2,
        ),
        literals: [header1, text1, header2, text2],
      );
      final transport = ImapMailTransport(
        resolveAccount: (id) async => id == 'acc_ap' ? _apAccount() : null,
        resolveAccessToken: (account) async => _oauthAccessToken,
        credentialService: _serviceWithApPassword(),
        clientFactory: (account) async => _clientOver(socket),
      );

      final emails = await transport.fetchEmails(
        folder: 'inbox',
        accountId: 'acc_ap',
      );
      expect(emails.length, 2);

      final first = emails[0]; // uid 102 (сервер отдаёт в порядке ответа)
      expect(first.id, 'acc_ap:inbox:424242:102');
      expect(first.accountId, 'acc_ap');
      expect(first.folder, 'inbox');
      expect(first.sender, 'Alice <alice@example.test>');
      expect(first.subject, 'Weekly report');
      // Metadata-only: тела нет.
      expect(first.body, isEmpty);
      expect(first.recipient, 'unit.ap@test.local');
      // Флаг из серверного ответа (чтение, не запись).
      expect(first.isRead, isTrue);
      // INTERNALDATE с +0300 -> UTC 07:00.
      expect(first.timestamp, DateTime.utc(2026, 11, 14, 7, 0, 0));

      final second = emails[1]; // uid 101, не прочитано, UTF-8 subject
      expect(second.id, 'acc_ap:inbox:424242:101');
      expect(second.isRead, isFalse);
      expect(second.subject, 'Тестовое письмо');
      expect(second.hasAttachments, isFalse);
    });

    test('[M6b] INTERNALDATE parser: +ZZZZ/-ZZZZ и мусор -> epoch',
        () async {
      expect(
        ImapMailTransport.parseInternalDate('14-Nov-2026 10:00:00 +0300'),
        DateTime.utc(2026, 11, 14, 7, 0, 0),
      );
      expect(
        ImapMailTransport.parseInternalDate('01-Jan-2027 00:30:00 -0500'),
        DateTime.utc(2027, 1, 1, 5, 30, 0),
      );
      expect(
        ImapMailTransport.parseInternalDate('мусор без формата'),
        DateTime.utc(1970),
      );
    });

    test('[M7] preview: управляющие символы чистятся, длина ограничена',
        () async {
      final header = _headerLiteral(
        from: 'dan@example.test',
        subject: 'Controls',
      );
      final dirty = 'Hello$_nul${String.fromCharCode(7)}'
          '${String.fromCharCode(127)}   world${String.fromCharCode(9)}';
      final long = List.filled(600, 'a').join();
      final socket = _FakeImapSocket(
        lines: [
          'A1 OK LOGIN completed',
          ..._examineResponses(uidValidity: 9),
          '* SEARCH 10 11',
          'A3 OK SEARCH completed',
          ..._fetchResponses(
            seq: 1,
            uid: 10,
            seen: false,
            header: header,
            text: dirty,
          ),
          ..._fetchResponses(
            seq: 2,
            uid: 11,
            seen: false,
            header: header,
            text: long,
          ),
          'A4 OK FETCH completed',
          'A5 OK LOGOUT completed',
        ],
        literals: [header, dirty, header, long],
      );
      final transport = ImapMailTransport(
        resolveAccount: (id) async => id == 'acc_ap' ? _apAccount() : null,
        resolveAccessToken: (account) async => _oauthAccessToken,
        credentialService: _serviceWithApPassword(),
        clientFactory: (account) async => _clientOver(socket),
      );

      final emails = await transport.fetchEmails(
        folder: 'inbox',
        accountId: 'acc_ap',
      );
      expect(emails[0].preview, 'Hello world');
      expect(emails[1].preview.length, 512);
    });

    test('[M8] максимум 20 писем за синхронизацию (clamp сверху и снизу)',
        () async {
      Future<String> fetchRangeFor({required int uids, int? limit}) async {
        final allUids = List.generate(uids, (i) => i + 1);
        final header = _headerLiteral(
          from: 'e@example.test',
          subject: 'Range',
        );
        final text = 'Body';
        final responses = <String>[
          'A1 OK LOGIN completed',
          ..._examineResponses(uidValidity: 5),
          '* SEARCH ${allUids.join(' ')}',
          'A3 OK SEARCH completed',
        ];
        final literals = <String>[];
        for (var i = 0; i < allUids.length; i++) {
          final chunk = _fetchResponses(
            seq: i + 1,
            uid: allUids[i],
            seen: false,
            header: header,
            text: text,
          );
          responses.addAll(chunk);
          literals.addAll([header, text]);
        }
        responses.add('A4 OK FETCH completed');
        responses.add('A5 OK LOGOUT completed');
        final socket = _FakeImapSocket(
          lines: responses,
          literals: literals,
        );
        final transport = ImapMailTransport(
          resolveAccount: (id) async =>
              id == 'acc_ap' ? _apAccount() : null,
          resolveAccessToken: (account) async => _oauthAccessToken,
          credentialService: _serviceWithApPassword(),
          clientFactory: (account) async => _clientOver(socket),
        );
        await transport.fetchEmails(
          folder: 'inbox',
          accountId: 'acc_ap',
          limit: limit ?? 50,
        );
        return socket.written[3];
      }

      // 25 UID, лимит по умолчанию (50) -> clamp до 20: последние 20.
      expect(
        await fetchRangeFor(uids: 25),
        contains('A4 UID FETCH 6:25'),
      );
      // Явный лимит больше 20 тоже clamped до 20.
      expect(
        await fetchRangeFor(uids: 25, limit: 100),
        contains('A4 UID FETCH 6:25'),
      );
      // Меньший лимит уважается.
      expect(
        await fetchRangeFor(uids: 25, limit: 5),
        contains('A4 UID FETCH 21:25'),
      );
    });
  });

  group('MAIL-02A timeout и закрытие socket (ТЗ §3)', () {
    test('[M15] stalled write: write timeout -> соединение закрыто', () async {
      final socket = _FakeImapSocket(
        lines: ['A1 OK LOGIN completed'],
      )..hangWrites = true;
      final transport = ImapMailTransport(
        resolveAccount: (id) async => id == 'acc_ap' ? _apAccount() : null,
        resolveAccessToken: (account) async => _oauthAccessToken,
        credentialService: _serviceWithApPassword(),
        clientFactory: (account) async => ImapReadOnlyClient.forSocket(
          socket,
          writeTimeout: const Duration(milliseconds: 150),
        ),
      );

      await expectLater(
        transport.fetchEmails(folder: 'inbox', accountId: 'acc_ap'),
        throwsA(
          isA<ImapTransportException>().having(
            (error) => error.message,
            'message',
            'Ошибка соединения с IMAP-сервером',
          ),
        ),
      );
      // Фактическое закрытие socket после write timeout.
      expect(socket.destroyed, isTrue);
      // Sanitized: сообщение об ошибке не содержит credential-значений
      // (пароль присутствует только в raw LOGIN-записи сокета, которая
      // не попадает в исключения и capturedCommands).
      expect(
        'Ошибка соединения с IMAP-сервером'.contains(_apPassword),
        isFalse,
      );
    });

    test('[M16] greeting failure: destroy вызывается, ошибка sanitized',
        () async {
      // Чтение приветствия падает по таймауту соединения: клиент обязан
      // закрыть socket на ЛЮБОМ failed-connect пути.
      final socket = _FakeImapSocket(lines: const []);
      await expectLater(
        ImapReadOnlyClient.connect(
          'imap.test.local',
          socketFactory: (host, port) async => socket,
        ),
        throwsA(isA<ImapConnectionException>()),
      );
      expect(socket.destroyed, isTrue);
    });
  });

  group('MAIL-02A OAuth lifecycle end-to-end (ТЗ §5/§9.4)', () {
    Future<OrbitAppState> stateWithOAuth(
      DriftLocalStateRepository repo,
      OrbitSecretStore store,
      _CountingOAuthClient oauthClient,
    ) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      // Config override: refresh-путь требует конфигурацию провайдера
      // (без неё refresh вернул бы transient CONFIG_REQUIRED).
      final state = OrbitAppState(
        repo,
        store,
        oauthClient,
        const OrbitMailOAuthConfigOverride(
          googleClientId: 'mail02a-test-google-client-id',
          outlookClientId: 'mail02a-test-outlook-client-id',
          redirectUri: 'app.orbit.orbit_visual_lab:/oauthredirect',
        ),
      );
      await state.load();
      await state.saveMailAccountWithCredentials(
        _oauthAccount(),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: 'expired-access-token',
          refreshToken: 'r1',
          // Истёкший access: без grace 30c refresh обязателен.
          expiryUtc: DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          ),
        ),
      );
      await state.flush();
      return state;
    }

    ImapMailTransport transportFor(
      OrbitAppState state,
      OrbitMailCredentialService credentials,
      _FakeImapSocket socket,
    ) =>
        ImapMailTransport(
          resolveAccount: (id) async =>
              id == 'acc_oauth' ? _oauthAccount() : null,
          // PRODUCTION wiring: токен через state-lifecycle.
          resolveAccessToken: (account) =>
              state.getValidOAuthAccessToken(account.id),
          credentialService: credentials,
          clientFactory: (account) async => _clientOver(socket),
        );

    test('[M17] expired access -> ровно один refresh -> ровно один '
        'retry -> успех + rotation', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02a_m17');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}m17.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      final oauthClient = _CountingOAuthClient('success');
      final state = await stateWithOAuth(repo, store, oauthClient);

      final header = _headerLiteral(
        from: 'oauth@example.test',
        subject: 'After refresh',
      );
      final text = 'Fresh preview';
      final socket = _FakeImapSocket(
        lines: [
          'A1 OK AUTHENTICATE completed',
          ..._examineResponses(uidValidity: 31337),
          '* SEARCH 700',
          'A3 OK SEARCH completed',
          ..._fetchResponses(
            seq: 1,
            uid: 700,
            seen: false,
            header: header,
            text: text,
          ),
          'A4 OK FETCH completed',
          'A5 OK LOGOUT completed',
        ],
        literals: [header, text],
      );
      state.debugImapTransportForTest(
        transportFor(state, _serviceWithApPassword(), socket),
      );

      expect(await state.syncRealInbox('acc_oauth'), isTrue);
      // Refresh не более одного раза.
      expect(oauthClient.refreshCalls, 1);
      // Аутентификация выполнена ровно один раз (retry не более 1).
      expect(
        socket.written
            .where((line) => line.startsWith('A1 AUTHENTICATE XOAUTH2 '))
            .length,
        1,
      );
      // Rotation: новый refresh token сохранён в secure store.
      final rotatedRefresh =
          await store.read('mail.v1.acc_oauth.oauth.refresh');
      expect(rotatedRefresh, 'r2-refreshed-1');
      // Успех -> verified.
      expect(
        state.mailAccounts
            .firstWhere((a) => a.id == 'acc_oauth')
            .credentialStatus,
        OrbitMailCredentialStatus.verified,
      );
    });

    test('[M18] refresh transient: без цикла, credentials сохранены, '
        'savedUnverified для retry', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02a_m18');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}m18.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      final oauthClient = _CountingOAuthClient('transient');
      final state = await stateWithOAuth(repo, store, oauthClient);

      final socket = _FakeImapSocket(lines: const []);
      state.debugImapTransportForTest(
        transportFor(state, _serviceWithApPassword(), socket),
      );

      expect(await state.syncRealInbox('acc_oauth'), isFalse);
      // Refresh ровно один раз: цикла нет.
      expect(oauthClient.refreshCalls, 1);
      // До аутентификации не дошло: команд в сокет не отправлено.
      expect(socket.written, isEmpty);
      // Transient: OAuth keys сохранены (retry возможен), metadata
      // остаётся savedUnverified.
      expect(
        await store.read('mail.v1.acc_oauth.oauth.access'),
        'expired-access-token',
      );
      expect(
        await store.read('mail.v1.acc_oauth.oauth.refresh'),
        'r1',
      );
      final account = state.mailAccounts
          .firstWhere((a) => a.id == 'acc_oauth');
      expect(
        account.credentialStatus,
        OrbitMailCredentialStatus.savedUnverified,
      );
      expect(account.authMethod, 'oauth');
      expect(
        state.lastRealInboxSyncError,
        'OAuth-токен недоступен: повторите вход через браузер',
      );
    });

    test('[M19] refresh invalid_grant: OAuth keys удалены, персистентно '
        'notConfigured, без цикла', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02a_m19');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}m19.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      final oauthClient = _CountingOAuthClient('invalidGrant');
      final state = await stateWithOAuth(repo, store, oauthClient);

      final socket = _FakeImapSocket(lines: const []);
      state.debugImapTransportForTest(
        transportFor(state, _serviceWithApPassword(), socket),
      );

      expect(await state.syncRealInbox('acc_oauth'), isFalse);
      // Refresh ровно один раз: цикла нет.
      expect(oauthClient.refreshCalls, 1);
      // invalid_grant: весь OAuth-набор удалён из secure store.
      expect(await store.read('mail.v1.acc_oauth.oauth.access'), isNull);
      expect(await store.read('mail.v1.acc_oauth.oauth.refresh'), isNull);
      expect(await store.read('mail.v1.acc_oauth.oauth.expiry'), isNull);
      // Персистентно notConfigured без authMethod.
      final account = state.mailAccounts
          .firstWhere((a) => a.id == 'acc_oauth');
      expect(
        account.credentialStatus,
        OrbitMailCredentialStatus.notConfigured,
      );
      expect(account.authMethod, isNull);
      final snapshot = await repo.load();
      final accountsJson = snapshot['mailAccounts'] as List<dynamic>;
      final oauthEntry = accountsJson
          .whereType<Map<String, Object?>>()
          .firstWhere((map) => map['id'] == 'acc_oauth');
      expect(oauthEntry['credentialStatus'], 'notConfigured');
      expect(oauthEntry.containsKey('authMethod'), isFalse);
      // Повторный sync заблокирован guard'ом notConfigured (без цикла).
      expect(await state.syncRealInbox('acc_oauth'), isFalse);
      expect(oauthClient.refreshCalls, 1);
      expect(
        state.lastRealInboxSyncError,
        'Учётные данные не настроены',
      );
    });
  });

  group('MAIL-02A production data path (file SQLite)', () {
    Future<OrbitAppState> stateOnFileSQLite(
      DriftLocalStateRepository repo, [
      OrbitSecretStore? store,
      OrbitOAuthClient? oauthClient,
    ]) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final state = OrbitAppState(
        repo,
        store ?? MemoryOrbitSecretStore(),
        oauthClient,
      );
      await state.load();
      return state;
    }

    test('[M9] идемпотентная синхронизация: дублей нет, DEMO не '
        'перемешивается (source_type)', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02a_m9');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}m9.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final state = await stateOnFileSQLite(repo);
      await state.saveMailAccountWithCredentials(
        _apAccount(),
        appPassword: _apPassword,
      );
      await state.flush();

      // После load() DEMO-письма засеяны, но user-строк нет.
      final engine = await repo.mailDataEngine();
      final userRowsBefore = await engine.getUserMailRows(folder: 'inbox');
      expect(userRowsBefore, isEmpty);

      final header = _headerLiteral(
        from: 'sync@example.test',
        subject: 'Sync letter',
      );
      final text = 'Stable preview';
      _FakeImapSocket makeSocket() => _FakeImapSocket(
            lines: _apSessionLines(
              header1: header,
              text1: text,
              header2: header,
              text2: text,
            ),
            literals: [header, text, header, text],
          );
      ImapMailTransport makeTransport() => ImapMailTransport(
            resolveAccount: (id) async =>
                id == 'acc_ap' ? _apAccount() : null,
            resolveAccessToken: (account) async => _oauthAccessToken,
            credentialService: _serviceWithApPassword(),
            clientFactory: (account) async => _clientOver(makeSocket()),
          );

      state.debugImapTransportForTest(makeTransport());
      expect(await state.syncRealInbox('acc_ap'), isTrue);
      final firstCount = state.userInboxEntries.length;
      expect(firstCount, 2);

      // Повторная синхронизация с тем же сервером: идемпотентно.
      state.debugImapTransportForTest(makeTransport());
      expect(await state.syncRealInbox('acc_ap'), isTrue);
      expect(state.userInboxEntries.length, firstCount);

      final userRows = await engine.getUserMailRows(folder: 'inbox');
      expect(userRows.length, 2);
      final ids = userRows.map((row) => row['id']).toSet();
      expect(
        ids,
        {'acc_ap:inbox:424242:102', 'acc_ap:inbox:424242:101'},
      );
      // DEMO-письма не попали в user-выборку.
      for (final row in userRows) {
        expect(demoEmails.any((demo) => demo.id == row['id']), isFalse);
      }
    });

    test('[M10] отклонение аутентификации: персистентно notConfigured, '
        'authMethod очищен, БЕЗ цикла повторов', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02a_m10');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}m10.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      // Секрет в secure storage переживает «перезапуск» — общий store.
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);
      await state.saveMailAccountWithCredentials(
        _apAccount(),
        appPassword: _apPassword,
      );
      await state.flush();

      final socket = _FakeImapSocket(
        lines: ['A1 NO [AUTHENTICATIONFAILED] Authentication failed'],
      );
      state.debugImapTransportForTest(
        ImapMailTransport(
          resolveAccount: (id) async =>
              id == 'acc_ap' ? _apAccount() : null,
          resolveAccessToken: (account) async => _oauthAccessToken,
          credentialService: _serviceWithApPassword(),
          clientFactory: (account) async => _clientOver(socket),
        ),
      );

      expect(await state.syncRealInbox('acc_ap'), isFalse);
      expect(
        state.lastRealInboxSyncError,
        'Сервер отклонил аутентификацию: проверьте учётные данные',
      );
      // ТЗ §5/§9.9: auth rejection -> персистентно notConfigured,
      // authMethod очищен.
      final account = state.mailAccounts
          .firstWhere((a) => a.id == 'acc_ap');
      expect(
        account.credentialStatus,
        OrbitMailCredentialStatus.notConfigured,
      );
      expect(account.authMethod, isNull);
      // Персистентность: snapshot на диске содержит notConfigured и БЕЗ
      // authMethod (проверка после перечитывания из repository).
      final snapshot = await repo.load();
      final accountsJson = snapshot['mailAccounts'] as List<dynamic>;
      final apEntry = accountsJson
          .whereType<Map<String, Object?>>()
          .firstWhere((map) => map['id'] == 'acc_ap');
      expect(apEntry['credentialStatus'], 'notConfigured');
      expect(apEntry.containsKey('authMethod'), isFalse);
      // Секрет не удаляется (обновление credentials через форму
      // перезапишет его); metadata честно показывает «не настроено».
      expect(
        await state.mailCredentialService.hasAppPassword('acc_ap'),
        isTrue,
      );
      // БЕЗ цикла повторов: повторный sync блокируется guard'ом
      // notConfigured — ни одной новой команды в сокет.
      final writesBefore = socket.written.length;
      expect(await state.syncRealInbox('acc_ap'), isFalse);
      expect(
        state.lastRealInboxSyncError,
        'Учётные данные не настроены',
      );
      expect(socket.written.length, writesBefore);
      // user-строк нет.
      final engine = await repo.mailDataEngine();
      expect(await engine.getUserMailRows(folder: 'inbox'), isEmpty);
    });

    test('[M11] verified ТОЛЬКО после фактического IMAP-успеха и '
        'переживает перезапуск (snapshot)', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02a_m11');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}m11.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      // Один store на «перезапуск»: секрет живёт в secure storage,
      // который переживает перезапуск приложения.
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);
      await state.saveMailAccountWithCredentials(
        _apAccount(),
        appPassword: _apPassword,
      );
      await state.flush();
      // До синхронизации: savedUnverified, verified никем не присвоен.
      expect(
        state.mailAccounts
            .firstWhere((a) => a.id == 'acc_ap')
            .credentialStatus,
        OrbitMailCredentialStatus.savedUnverified,
      );

      final header = _headerLiteral(
        from: 'verified@example.test',
        subject: 'Verified letter',
      );
      final text = 'Verified preview';
      state.debugImapTransportForTest(
        ImapMailTransport(
          resolveAccount: (id) async =>
              id == 'acc_ap' ? _apAccount() : null,
          resolveAccessToken: (account) async => _oauthAccessToken,
          credentialService: _serviceWithApPassword(),
          clientFactory: (account) async => _clientOver(
            _FakeImapSocket(
              lines: _apSessionLines(
                header1: header,
                text1: text,
                header2: header,
                text2: text,
              ),
              literals: [header, text, header, text],
            ),
          ),
        ),
      );
      expect(await state.syncRealInbox('acc_ap'), isTrue);
      expect(
        state.mailAccounts
            .firstWhere((a) => a.id == 'acc_ap')
            .credentialStatus,
        OrbitMailCredentialStatus.verified,
      );

      // Перезапуск: новый state поверх того же файла и того же store.
      final reloaded = await stateOnFileSQLite(repo, sharedStore);
      final snapshot = await reloaded.repository.load();
      final accountsJson = snapshot['mailAccounts'] as List<dynamic>;
      final apEntry = accountsJson
          .whereType<Map<String, Object?>>()
          .firstWhere((map) => map['id'] == 'acc_ap');
      expect(apEntry['credentialStatus'], 'verified');
    });

    test('[M12] transient-ошибка соединения: sanitized, savedUnverified '
        'сохраняется, секреты живы (retry доступен)', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02a_m12');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}m12.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);
      await state.saveMailAccountWithCredentials(
        _apAccount(),
        appPassword: _apPassword,
      );
      await state.flush();

      // Сокет без ответов: чтение падает по соединению (не auth).
      final socket = _FakeImapSocket(lines: const []);
      state.debugImapTransportForTest(
        ImapMailTransport(
          resolveAccount: (id) async =>
              id == 'acc_ap' ? _apAccount() : null,
          resolveAccessToken: (account) async => _oauthAccessToken,
          credentialService: _serviceWithApPassword(),
          clientFactory: (account) async => _clientOver(socket),
        ),
      );

      expect(await state.syncRealInbox('acc_ap'), isFalse);
      expect(
        state.lastRealInboxSyncError,
        'Ошибка соединения с IMAP-сервером',
      );
      // ТЗ §5: transient -> savedUnverified, retry доступен.
      final account = state.mailAccounts
          .firstWhere((a) => a.id == 'acc_ap');
      expect(
        account.credentialStatus,
        OrbitMailCredentialStatus.savedUnverified,
      );
      expect(account.authMethod, 'appPassword');
      expect(
        await state.mailCredentialService.hasAppPassword('acc_ap'),
        isTrue,
      );
      // Персистентность metadata.
      final snapshot = await repo.load();
      final accountsJson = snapshot['mailAccounts'] as List<dynamic>;
      final apEntry = accountsJson
          .whereType<Map<String, Object?>>()
          .firstWhere((map) => map['id'] == 'acc_ap');
      expect(apEntry['credentialStatus'], 'savedUnverified');
    });

    test('[M12c] verified -> transient -> персистентно savedUnverified',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02a_m12c');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}m12c.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);
      await state.saveMailAccountWithCredentials(
        _apAccount(),
        appPassword: _apPassword,
      );
      await state.flush();

      final header = _headerLiteral(
        from: 'ok@example.test',
        subject: 'First sync ok',
      );
      final text = 'Body fragment';
      ImapMailTransport transportFor(_FakeImapSocket socket) =>
          ImapMailTransport(
            resolveAccount: (id) async =>
                id == 'acc_ap' ? _apAccount() : null,
            resolveAccessToken: (account) async => _oauthAccessToken,
            credentialService: _serviceWithApPassword(),
            clientFactory: (account) async => _clientOver(socket),
          );

      // 1) Успешная синхронизация -> verified.
      state.debugImapTransportForTest(
        transportFor(
          _FakeImapSocket(
            lines: _apSessionLines(
              header1: header,
              text1: text,
              header2: header,
              text2: text,
            ),
            literals: [header, text, header, text],
          ),
        ),
      );
      expect(await state.syncRealInbox('acc_ap'), isTrue);
      expect(
        state.mailAccounts
            .firstWhere((a) => a.id == 'acc_ap')
            .credentialStatus,
        OrbitMailCredentialStatus.verified,
      );

      // 2) Следующая синхронизация падает transient -> понижение до
      //    savedUnverified, персистентно.
      state.debugImapTransportForTest(
        transportFor(_FakeImapSocket(lines: const [])),
      );
      expect(await state.syncRealInbox('acc_ap'), isFalse);
      expect(
        state.lastRealInboxSyncError,
        'Ошибка соединения с IMAP-сервером',
      );
      expect(
        state.mailAccounts
            .firstWhere((a) => a.id == 'acc_ap')
            .credentialStatus,
        OrbitMailCredentialStatus.savedUnverified,
      );
      final snapshot = await repo.load();
      final accountsJson = snapshot['mailAccounts'] as List<dynamic>;
      final apEntry = accountsJson
          .whereType<Map<String, Object?>>()
          .firstWhere((map) => map['id'] == 'acc_ap');
      expect(apEntry['credentialStatus'], 'savedUnverified');
      // Письма первой (успешной) синхронизации остались в SQLite.
      final engine = await repo.mailDataEngine();
      expect((await engine.getUserMailRows(folder: 'inbox')).length, 2);
    });

    test('[M12b] защита от двойного запуска синхронизации', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02a_m12b');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}m12b.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final state = await stateOnFileSQLite(repo);
      await state.saveMailAccountWithCredentials(
        _apAccount(),
        appPassword: _apPassword,
      );
      await state.flush();

      final socket = _FakeImapSocket(lines: const [])..hangReads = true;
      state.debugImapTransportForTest(
        ImapMailTransport(
          resolveAccount: (id) async =>
              id == 'acc_ap' ? _apAccount() : null,
          resolveAccessToken: (account) async => _oauthAccessToken,
          credentialService: _serviceWithApPassword(),
          clientFactory: (account) async => _clientOver(socket),
        ),
      );

      final first = state.syncRealInbox('acc_ap');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Второй запуск отклоняется, пока первый в полёте.
      expect(await state.syncRealInbox('acc_ap'), isFalse);
      expect(
        state.lastRealInboxSyncError,
        'Синхронизация уже выполняется',
      );

      // Cleanup: первый запуск завершается ошибкой соединения.
      socket.failPending();
      expect(await first, isFalse);
    });
  });

  group('MAIL-02A no-send и UI (read-only surface)', () {
    test('[M13] sendEmail невозможен: SMTP вне объёма MAIL-02A', () async {
      final socket = _FakeImapSocket();
      final transport = ImapMailTransport(
        resolveAccount: (id) async => id == 'acc_ap' ? _apAccount() : null,
        resolveAccessToken: (account) async => _oauthAccessToken,
        credentialService: _serviceWithApPassword(),
        clientFactory: (account) async => _clientOver(socket),
      );
      final outgoing = QueuedOutgoingEmail(
        id: 'out-1',
        workspaceId: 'workspace-work',
        accountId: 'acc_ap',
        to: 'someone@example.test',
        subject: 'Should not send',
        body: 'Nope',
        createdAt: DateTime.now().toUtc(),
      );
      await expectLater(
        transport.sendEmail(outgoing),
        throwsA(isA<UnsupportedError>()),
      );
      // Ни одной команды не отправлено.
      expect(socket.written, isEmpty);
    });

    testWidgets('[M14] UI: реальный ящик отдельно от DEMO, «Только '
        'чтение», mutating actions отсутствуют', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = OrbitAppState(
        MemoryLocalStateRepository(),
        MemoryOrbitSecretStore(),
      );
      await state.load();
      await state.saveMailAccountWithCredentials(
        _apAccount(),
        appPassword: _apPassword,
      );
      await state.flush();

      final style = OrbitStyleManager(
        MemoryAppearanceRepository(
          const AppearanceSettings(
            profile: OrbitProfile.one,
            atmosphereMode: AtmosphereMode.automatic,
            quality: OrbitQuality.eco,
            motionEnabled: false,
          ),
        ),
      );
      final quality = OrbitQualityManager();
      final palette = OrbitPalette.ofBrightness(
        OrbitProfile.one,
        Brightness.dark,
      );

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: state,
          builder: (context, _) => OrbitEnvironment(
            style: style,
            quality: quality,
            appState: state,
            appearanceSettings: style.settings,
            resolvedQuality: quality.resolve(style.settings),
            dataRevision: state.dataRevision,
            graphicsFallbackReason: null,
            appearancePersistenceError: null,
            appearanceLoadError: null,
            platformBrightness: Brightness.dark,
            child: MaterialApp(
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: palette.themeData(palette.accent),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: OrbitRealInboxPanel(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Панель присутствует в свёрнутом виде.
      expect(
        find.text('Реальный ящик — только чтение (IMAP)'),
        findsOneWidget,
      );
      // Раскрываем: карточка аккаунта с честной пометкой «Только чтение».
      await tester.tap(find.byKey(const Key('real-inbox-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Только чтение'), findsOneWidget);
      // Кнопка синхронизации существует для реального аккаунта.
      expect(
        find.byKey(const Key('real-inbox-sync-acc_ap')),
        findsOneWidget,
      );
      // Реальных писем пока нет; DEMO-письма в панели отсутствуют.
      expect(state.userInboxEntries, isEmpty);
      expect(find.text('Weekly report'), findsNothing);

      // Tap: без production-хранилища — честный sanitized отказ.
      await tester.tap(find.byKey(const Key('real-inbox-sync-acc_ap')));
      await tester.pumpAndSettle();
      expect(
        find.text('Реальная почта требует production-хранилища'),
        findsOneWidget,
      );
      // DEMO-состояние не изменилось (никаких мутаций).
      expect(state.sentEmails, isEmpty);
    });
  });
}
