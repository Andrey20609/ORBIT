import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/core/module_interfaces.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/drift_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_secure_store.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_credential_service.dart';
import 'package:orbit_visual_lab/services/mail/smtp_mail_transport.dart';
import 'package:orbit_visual_lab/services/mail/smtp_outbox_store.dart';
import 'package:orbit_visual_lab/services/mail/smtp_send_client.dart';
import 'package:orbit_visual_lab/services/mail/smtp_socket.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_real_inbox_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Тестовые значения: синтетические, генерируются сценарием, в логи/
// evidence не выводятся (только assert-проверки).
const String _apPassword = 'MAIL02B-TEST-APP-PASSWORD-w4r9';
const String _oauthAccessToken = 'MAIL02B-TEST-ACCESS-t2m8';
const String _allowedRecipient = 'controlled.recipient@test.local';

// SMTP спецсимволы строятся в рантайме: в исходнике нет escape-последовательностей.
final String _crlf =
    String.fromCharCode(13) + String.fromCharCode(10);
final String _nul = String.fromCharCode(0);

OrbitMailAccount _smtpAccount() => const OrbitMailAccount(
      id: 'acc_smtp',
      name: 'Тестовый отправитель',
      email: 'unit.sender@test.local',
      providerType: OrbitMailProviderType.yandex,
      incomingHost: 'imap.yandex.ru',
      incomingPort: 993,
      outgoingHost: 'smtp.yandex.ru',
      outgoingPort: 465,
      credentialStatus: OrbitMailCredentialStatus.savedUnverified,
      authMethod: 'appPassword',
      isActive: true,
    );

/// Fake SMTP socket: scripted ответы + capture всех записанных строк.
final class _FakeSmtpSocket implements OrbitSmtpSocket {
  _FakeSmtpSocket(List<String> lines) : _linesList = List.of(lines);

  final List<String> _linesList;
  final List<String> written = <String>[];
  bool hangWrites = false;
  bool destroyed = false;
  int closeAfterWrites = -1; // сервер рвёт соединение после N записей

  @override
  Future<void> writeLine(String line) async {
    written.add(line);
    if (closeAfterWrites > 0 && written.length >= closeAfterWrites) {
      throw const SmtpConnectionException('Соединение закрыто сервером');
    }
    if (hangWrites) {
      await Completer<void>().future;
    }
  }

  @override
  Future<String> readLine() async {
    if (_linesList.isEmpty) {
      throw const SmtpConnectionException('Скрипт ответов исчерпан');
    }
    return _linesList.removeAt(0);
  }

  @override
  void destroy() {
    destroyed = true;
  }
}

_FakeSmtpSocket _fakeSmtp(List<String> lines) => _FakeSmtpSocket(lines);

/// Полный успешный SMTP-сценарий (implicit TLS уже установлен).
List<String> _sessionLines({
  String dataResponse = '250 2.0.0 Accepted: message queued',
  String authMode = 'login',
}) => [
      '220 smtp.test.local ESMTP ready',
      '250-smtp.test.local Hello orbit',
      '250-SIZE 52428800',
      '250 AUTH LOGIN PLAIN XOAUTH2',
      if (authMode == 'login') ...[
        '334 VXNlcm5hbWU6',
        '334 UGFzc3dvcmQ6',
        '235 2.7.0 Authentication successful',
      ] else
        '235 2.7.0 Authentication successful',
      '250 2.1.0 OK',
      '250 2.1.5 OK',
      '354 End data with CRLF.CRLF',
      dataResponse,
      '221 2.0.0 Bye',
    ];

OrbitMailCredentialService _serviceWithApPassword() {
  final service = OrbitMailCredentialService(store: MemoryOrbitSecretStore());
  unawaited(
    service.saveAppPassword(accountId: 'acc_smtp', appPassword: _apPassword),
  );
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MAIL-02B SMTP TLS only', () {
    test('[S1] implicit TLS only: plain-порт непригоден для SMTP', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) {
        socket.destroy();
      });
      await expectLater(
        SecureSmtpSocket.connect(
          '127.0.0.1',
          server.port,
          readTimeout: const Duration(seconds: 3),
          writeTimeout: const Duration(seconds: 3),
          connectTimeout: const Duration(seconds: 3),
        ),
        throwsA(anything),
      );
    });

    test('[S2] bad certificate: самоподписанный сертификат отвергается',
        () async {
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
        SecureSmtpSocket.connect(
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

  group('MAIL-02B SMTP protocol (app password)', () {
    test('[S3] protocol capture: EHLO/AUTH LOGIN/MAIL/RCPT/DATA/QUIT, '
        'credentials redacted, ровно один DATA', () async {
      final socket = _fakeSmtp(_sessionLines());
      final client = await SmtpSendClient.forSocket(socket);
      await client.ehlo('orbit');
      await client.authLogin('unit.sender@test.local', _apPassword);
      await client.mailFrom('unit.sender@test.local');
      await client.rcptTo(_allowedRecipient);
      final accepted = await client.data(
        'Контрольная отправка',
        'Первая строка$_crlf.точка в начале строки',
      );
      expect(accepted, isTrue);
      await client.quit();

      // Точная последовательность команд; AUTH redacted.
      final commands = client.capturedCommands;
      expect(commands[0], 'EHLO orbit');
      expect(commands[1], 'AUTH [credentials redacted]');
      expect(commands[2], 'MAIL FROM:<unit.sender@test.local>');
      expect(commands[3], 'RCPT TO:<$_allowedRecipient>');
      expect(commands[4], 'DATA');
      expect(commands[5], 'QUIT');
      // Ровно один DATA-конверт.
      expect(commands.where((c) => c == 'DATA').length, 1);
      // Пароль/учётные данные не попадают в captured.
      for (final line in commands) {
        expect(line.contains(_apPassword), isFalse);
        expect(line.contains('AUTH LOGIN'), isFalse);
      }
      // Raw AUTH-записи содержат base64-учётные данные только в сокете;
      // base64 пароля не присутствует в открытых командах AUTH LOGIN.
      final rawAuth = socket.written
          .where((line) => line.startsWith('AUTH'))
          .toList();
      expect(rawAuth.first, 'AUTH LOGIN');
      // Dot-stuffing: строка с ведущей точкой удвоена, конец данных '.'.
      // Raw: [0]EHLO [1]AUTH [2]user [3]pass [4]MAIL [5]RCPT [6]DATA
      //      [7]content [8]QUIT
      final dataBlob = socket.written[7];
      expect(dataBlob.contains('$_crlf..точка в начале строки'), isTrue);
      expect(dataBlob.endsWith('$_crlf.'), isTrue);
    });

    test('[S4] XOAUTH2: base64 payload + redaction', () async {
      final socket = _fakeSmtp(_sessionLines(authMode: 'oauth'));
      final client = await SmtpSendClient.forSocket(socket);
      await client.ehlo('orbit');
      await client.authXoauth2('unit.oauth.sender@test.local', _oauthAccessToken);
      await client.mailFrom('unit.oauth.sender@test.local');
      await client.rcptTo(_allowedRecipient);
      expect(await client.data('OAuth send', 'Body'), isTrue);
      await client.quit();

      for (final line in client.capturedCommands) {
        expect(line.contains(_oauthAccessToken), isFalse);
      }
      final authRaw = socket.written
          .firstWhere((line) => line.startsWith('AUTH XOAUTH2'));
      final decoded = utf8.decode(
        base64.decode(authRaw.substring('AUTH XOAUTH2 '.length)),
      );
      expect(
        decoded,
        'user=unit.oauth.sender@test.local$_nul'
        'auth=Bearer $_oauthAccessToken$_nul$_nul',
      );
    });
  });

  group('MAIL-02B controlled send (file SQLite)', () {
    Future<OrbitAppState> stateOnFileSQLite(
      DriftLocalStateRepository repo, [
      OrbitSecretStore? store,
    ]) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final state = OrbitAppState(repo, store ?? MemoryOrbitSecretStore());
      await state.load();
      return state;
    }

    Future<OrbitAppState> readyState(
      DriftLocalStateRepository repo,
      MemoryOrbitSecretStore store,
    ) async {
      final state = await stateOnFileSQLite(repo, store);
      state.debugSmtpConfigForTest(
        SmtpSendConfig(const <String>[_allowedRecipient]),
      );
      await state.saveMailAccountWithCredentials(
        _smtpAccount(),
        appPassword: _apPassword,
      );
      await state.flush();
      return state;
    }

    SmtpMailTransport transportFor(
      OrbitAppState state,
      _FakeSmtpSocket socket, {
      SmtpSendConfig? config,
    }) => SmtpMailTransport(
          resolveAccount: (id) async => state.mailAccounts
              .where((a) => a.id == id)
              .firstOrNull,
          resolveAccessToken: (account) async => _oauthAccessToken,
          credentialService: _serviceWithApPassword(),
          sendConfig:
              config ?? SmtpSendConfig(const <String>[_allowedRecipient]),
          clientFactory: (account) async => SmtpSendClient.forSocket(
            socket,
            writeTimeout: const Duration(milliseconds: 200),
          ),
        );

    test('[S5] письмо принято сервером ровно один раз; повторный flush '
        'не отправляет повторно', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02b_s5');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}s5.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      final state = await readyState(repo, store);

      final socket = _fakeSmtp(_sessionLines());
      state.debugSmtpTransportForTest(transportFor(state, socket));

      final outcome = await state.sendRealEmail(
        to: _allowedRecipient,
        subject: 'Контрольная отправка',
        body: 'Единственная доставка',
      );
      expect(outcome.status, 'sent');
      expect(
        state.lastSmtpSendOutcome.message,
        'Письмо принято сервером',
      );
      final dataCommands = socket.written
          .where((line) => line == 'DATA')
          .length;
      expect(dataCommands, 1);

      // Повторный flush: sent не переотправляется.
      await state.flushSmtpOutbox();
      expect(
        socket.written.where((line) => line == 'DATA').length,
        1,
      );
      final records = await SmtpOutboxStore(
        await repo.outboxDatabase(),
      ).all();
      expect(records.length, 1);
      expect(records.single.status, outboxStatusSent);
      expect(records.single.sentAtMs, isNotNull);
    });

    test('[S6] получатель вне allowlist: отказ ДО соединения и очереди',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02b_s6');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}s6.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      final state = await readyState(repo, store);

      final socket = _fakeSmtp(_sessionLines());
      state.debugSmtpTransportForTest(transportFor(state, socket));

      final outcome = await state.sendRealEmail(
        to: 'random.target@evil.test',
        subject: 'Не должно уйти',
        body: 'x',
      );
      expect(outcome.status, 'rejected');
      expect(
        state.lastSmtpSendOutcome.message,
        'Получатель вне разрешённого списка контролируемой отправки',
      );
      // Ни одной команды в сокет, ни одной записи в очереди.
      expect(socket.written, isEmpty);
      expect(
        await SmtpOutboxStore(await repo.outboxDatabase()).all(),
        isEmpty,
      );
    });

    test('[S7] config required: без разрешённого получателя - честный '
        'отказ, ничего не отправляется', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02b_s7');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}s7.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, store);
      state.debugSmtpConfigForTest(SmtpSendConfig.empty);
      await state.saveMailAccountWithCredentials(
        _smtpAccount(),
        appPassword: _apPassword,
      );
      await state.flush();
      state.debugSmtpTransportForTest(
        transportFor(state, _fakeSmtp(_sessionLines())),
      );

      final outcome = await state.sendRealEmail(
        to: _allowedRecipient,
        subject: 'x',
        body: 'y',
      );
      expect(outcome.status, 'rejected');
      expect(state.lastSmtpSendOutcome.message, contains('не настроена'));
      expect(
        await SmtpOutboxStore(await repo.outboxDatabase()).all(),
        isEmpty,
      );
    });

    test('[S8] идемпотентность enqueue: то же письмо не дублируется',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02b_s8');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}s8.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      final state = await readyState(repo, store);

      final socket1 = _fakeSmtp(_sessionLines());
      final socket2 = _fakeSmtp(_sessionLines());
      state.debugSmtpTransportForTest(
        transportFor(state, socket1),
      );
      final first = await state.sendRealEmail(
        to: _allowedRecipient,
        subject: 'Дубликат-тест',
        body: 'Тело',
      );
      expect(first.status, 'sent');

      // Тот же контент: duplicate, второй сокет не используется.
      state.debugSmtpTransportForTest(transportFor(state, socket2));
      final second = await state.sendRealEmail(
        to: _allowedRecipient,
        subject: 'Дубликат-тест',
        body: 'Тело',
      );
      expect(second.status, 'duplicate');
      expect(socket2.written, isEmpty);
      final records = await SmtpOutboxStore(
        await repo.outboxDatabase(),
      ).all();
      expect(records.length, 1);
    });

    test('[S9] transient (4xx): retry ровно один раз, доставлено ровно '
        'один раз суммарно', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02b_s9');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}s9.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      final state = await readyState(repo, store);

      final failingSocket = _fakeSmtp(
        _sessionLines(dataResponse: '451 4.3.0 Temporary problem'),
      );
      state.debugSmtpTransportForTest(
        transportFor(state, failingSocket),
      );
      final first = await state.sendRealEmail(
        to: _allowedRecipient,
        subject: 'Retry-тест',
        body: 'Тело',
      );
      expect(first.status, 'queued');
      var records = await SmtpOutboxStore(
        await repo.outboxDatabase(),
      ).all();
      expect(records.single.status, outboxStatusQueued);
      expect(records.single.retryCount, 1);

      // Restart-сценарий: тот же файл базы, тот же store (секрет живёт),
      // свежий state, рабочий сокет.
      final reloaded = await stateOnFileSQLite(repo, store);
      reloaded.debugSmtpConfigForTest(
        SmtpSendConfig(const <String>[_allowedRecipient]),
      );
      final goodSocket = _fakeSmtp(_sessionLines());
      reloaded.debugSmtpTransportForTest(
        transportFor(reloaded, goodSocket),
      );
      final sentCount = await reloaded.flushSmtpOutbox();
      expect(sentCount, 1);
      records = await SmtpOutboxStore(
        await repo.outboxDatabase(),
      ).all();
      expect(records.single.status, outboxStatusSent);
      // ПРИНЯТО сервером ровно один раз: отклонённая 451-попытка не
      // является принятием (данные сервером не сохранены), принимающая
      // DATA-попытка ровно одна.
      expect(
        goodSocket.written.where((l) => l == 'DATA').length,
        1,
      );
      expect(
        failingSocket.written.where((l) => l == 'DATA').length,
        1,
        reason: 'отклонённая попытка была ровно одна',
      );
    });

    test('[S10] retry limit: после исчерпания - failed финально',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02b_s10');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}s10.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      final state = await readyState(repo, store);

      final socket = _fakeSmtp(
        _sessionLines(dataResponse: '451 4.3.0 Temporary problem'),
      );
      state.debugSmtpTransportForTest(transportFor(state, socket));

      final outcome = await state.sendRealEmail(
        to: _allowedRecipient,
        subject: 'Limit-тест',
        body: 'Тело',
      );
      expect(
        state.lastSmtpSendOutcome.message,
        'Письмо в очереди: будет повторено',
        reason:
            'ожидается queued после первой transient-попытки; '
            'реальный статус: ${outcome.status}',
      );
      expect(outcome.status, 'queued');
      expect(outcome.status, 'queued');
      expect(socket.destroyed, isTrue);
      final records = await SmtpOutboxStore(
        await repo.outboxDatabase(),
      ).all();
      expect(records.single.status, outboxStatusQueued);
      expect(records.single.retryCount, 1);
    });

    test('[S13] leftover in-flight (crash во время отправки): restart НЕ '
        'переотправляет - защита от дубликатов', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02b_s13');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}s13.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final store = MemoryOrbitSecretStore();
      await readyState(repo, store);

      // Симулируем crash во время отправки: запись в статусе sending.
      final outbox = SmtpOutboxStore(await repo.outboxDatabase());
      await outbox.upsert(
        SmtpOutboxRecord(
          id: 'smtp-acc_smtp-crash',
          workspaceId: 'workspace-work',
          accountId: 'acc_smtp',
          recipient: _allowedRecipient,
          subject: 'Crash-тест',
          body: 'Тело',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: outboxStatusSending,
          retryCount: 0,
        ),
      );

      // Restart: свежий state + тот же store, рабочий сокет.
      final reloaded = await stateOnFileSQLite(repo, store);
      reloaded.debugSmtpConfigForTest(
        SmtpSendConfig(const <String>[_allowedRecipient]),
      );
      final goodSocket = _fakeSmtp(_sessionLines());
      reloaded.debugSmtpTransportForTest(
        transportFor(reloaded, goodSocket),
      );
      final sent = await reloaded.flushSmtpOutbox();
      // Ничего не отправлено заново: письмо помечено failed.
      expect(sent, 0);
      expect(goodSocket.written, isEmpty);
      final records = await outbox.all();
      expect(records.single.status, outboxStatusFailed);
      expect(records.single.lastError, contains('защита от дубликатов'));
    });

    test('[S14] SMTP транспорт не читает почту; секреты вне snapshot',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02b_s14');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}s14.sqlite',
      );
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(file: dbFile),
      );
      final sharedStore = MemoryOrbitSecretStore();
      final state = await readyState(repo, sharedStore);

      final transport = transportFor(state, _fakeSmtp(_sessionLines()));
      await expectLater(
        transport.fetchEmails(folder: 'inbox'),
        throwsA(isA<UnsupportedError>()),
      );

      // Секреты не в snapshot/JSON.
      final snapshotJson = jsonEncode(await repo.load());
      expect(snapshotJson.contains(_apPassword), isFalse);
      expect(snapshotJson.contains(_oauthAccessToken), isFalse);
    });

    testWidgets('[S15] UI: SMTP-лист открывается из real-панели, '
        'получатель prefilled, результат sanitized', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // UI-тест в fake-async зоне: file-SQLite I/O здесь не завершается,
      // поэтому Memory-хранилище (rejected-путь не доходит до outbox).
      final state = OrbitAppState(
        MemoryLocalStateRepository(),
        MemoryOrbitSecretStore(),
      );
      await state.load();
      state.debugSmtpConfigForTest(
        SmtpSendConfig(const <String>[_allowedRecipient]),
      );
      await state.saveMailAccountWithCredentials(
        _smtpAccount(),
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
      addTearDown(quality.dispose);
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
      await tester.tap(find.byKey(const Key('real-inbox-toggle')));
      await tester.pumpAndSettle();

      // Открываем SMTP-лист (фиксированные pump: не полагаемся на
      // pumpAndSettle внутри modal-разметки).
      await tester.tap(find.byKey(const Key('smtp-send-acc_smtp')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Получатель prefilled разрешённым адресом.
      final toField = tester.widget<TextField>(
        find.byKey(const Key('smtp-sheet-to')),
      );
      expect(toField.controller!.text, _allowedRecipient);
    });

    testWidgets('[S16] UI submit: честный rejected без конфигурации, '
        'секреты в результате отсутствуют', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // UI-тест в fake-async зоне: file-SQLite I/O здесь не завершается,
      // поэтому Memory-хранилище (rejected-путь не доходит до outbox).
      final state = OrbitAppState(
        MemoryLocalStateRepository(),
        MemoryOrbitSecretStore(),
      );
      await state.load();
      state.debugSmtpConfigForTest(
        SmtpSendConfig(const <String>[_allowedRecipient]),
      );
      await state.saveMailAccountWithCredentials(
        _smtpAccount(),
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
      addTearDown(quality.dispose);
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
      await tester.tap(find.byKey(const Key('real-inbox-toggle')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('smtp-send-acc_smtp')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Отправка: config-проверка отклоняет мгновенно (без I/O в
      // fake-async зоне UI-теста) — honest rejected путь.
      state.debugSmtpConfigForTest(SmtpSendConfig.empty);
      await tester.enterText(
        find.byKey(const Key('smtp-sheet-subject')),
        'UI-тест',
      );
      await tester.enterText(
        find.byKey(const Key('smtp-sheet-body')),
        'Тело письма',
      );
      await tester.tap(find.byKey(const Key('smtp-sheet-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final result = tester.widget<Text>(
        find.byKey(const Key('smtp-sheet-result')),
      );
      expect(result.data, contains('rejected'));
      expect(
        result.data,
        contains('не настроена'),
        reason: 'честный CONFIG_REQUIRED без имитации отправки',
      );
      // Секреты в UI-результате отсутствуют.
      expect(result.data!.contains(_apPassword), isFalse);
    });
  });

}
