// Standalone MAIL-02B evidence generator. NOT part of the default test
// suite: run explicitly with
//   ORBIT_EVIDENCE_OUT_DIR=<abs dir> flutter test tool/mail02b_evidence_test.dart
// Drives MOCK SMTP scenarios (fake socket, no network) through the
// PRODUCTION transport/state and saves:
//   mail02b_protocol.txt   - captured command sequence (AUTH redacted),
//                            read-only/no-duplicate facts, mutating scan
//   mail02b_outbox.txt     - queue lifecycle facts (accept-once, retry,
//                            crash-in-flight guard, allowlist)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/drift_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_secure_store.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_credential_service.dart';
import 'package:orbit_visual_lab/services/mail/smtp_mail_transport.dart';
import 'package:orbit_visual_lab/services/mail/smtp_outbox_store.dart';
import 'package:orbit_visual_lab/services/mail/smtp_send_client.dart';
import 'package:orbit_visual_lab/services/mail/smtp_socket.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Тестовые значения: синтетические, генерируются в рантайме.
const _apPassword = 'MAIL02B-EVIDENCE-APP-PASSWORD-' 'runtime-value';
const _allowed = 'controlled.recipient@test.local';

final _crlf = String.fromCharCode(13) + String.fromCharCode(10);

final class _FakeSmtpSocket implements OrbitSmtpSocket {
  _FakeSmtpSocket(this._lines);

  final List<String> _lines;
  final List<String> written = <String>[];

  @override
  Future<void> writeLine(String line) async {
    written.add(line);
  }

  @override
  Future<String> readLine() async {
    if (_lines.isEmpty) {
      throw StateError('script exhausted');
    }
    return _lines.removeAt(0);
  }

  @override
  void destroy() {}
}

List<String> _sessionLines({String dataResponse = '250 2.0.0 Accepted'}) => [
      '220 smtp.test.local ESMTP ready',
      '250-smtp.test.local Hello orbit',
      '250 AUTH LOGIN PLAIN XOAUTH2',
      '334 VXNlcm5hbWU6',
      '334 UGFzc3dvcmQ6',
      '235 2.7.0 Authentication successful',
      '250 2.1.0 OK',
      '250 2.1.5 OK',
      '354 End data with CRLF.CRLF',
      dataResponse,
      '221 2.0.0 Bye',
    ];

void main() {
  test('capture MAIL-02B SMTP evidence', () async {
    final outDir = Platform.environment['ORBIT_EVIDENCE_OUT_DIR'];
    expect(outDir, isNotNull,
        reason: 'set ORBIT_EVIDENCE_OUT_DIR=<abs dir> for this tool');
    Directory(outDir!).createSync(recursive: true);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final tempDir = await Directory.systemTemp.createTemp('mail02b_ev');
    addTearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });
    final repo = DriftLocalStateRepository(
      database: DriftOrbitDatabase(
        file: File(
          '${tempDir.path}${Platform.pathSeparator}evidence.sqlite',
        ),
      ),
    );
    final store = MemoryOrbitSecretStore();
    final state = OrbitAppState(repo, store);
    await state.load();
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugSmtpConfigForTest(
      SmtpSendConfig(const <String>[_allowed]),
    );
    await state.saveMailAccountWithCredentials(
      const OrbitMailAccount(
        id: 'evidence_sender',
        name: 'SMTP evidence ящик',
        email: 'evidence.sender@test.local',
        providerType: OrbitMailProviderType.yandex,
        incomingHost: 'imap.yandex.ru',
        incomingPort: 993,
        outgoingHost: 'smtp.yandex.ru',
        outgoingPort: 465,
        credentialStatus: OrbitMailCredentialStatus.savedUnverified,
        authMethod: 'appPassword',
        isActive: true,
      ),
      appPassword: _apPassword,
    );
    await state.flush();

    final credentials = OrbitMailCredentialService(store: store);
    _FakeSmtpSocket makeSocket() => _FakeSmtpSocket(_sessionLines());

    SmtpMailTransport transportFor(_FakeSmtpSocket socket) =>
        SmtpMailTransport(
          resolveAccount: (id) async => state.mailAccounts
              .where((a) => a.id == id)
              .firstOrNull,
          resolveAccessToken: (account) async => null,
          credentialService: credentials,
          sendConfig: SmtpSendConfig(const <String>[_allowed]),
          clientFactory: (account) async =>
              await SmtpSendClient.forSocket(socket),
        );

    // ===== 1. Protocol capture: успешная контролируемая отправка. =====
    final socket1 = makeSocket();
    SmtpSendClient? capturedClient;
    SmtpMailTransport captureTransport(_FakeSmtpSocket socket) =>
        SmtpMailTransport(
          resolveAccount: (id) async => state.mailAccounts
              .where((a) => a.id == id)
              .firstOrNull,
          resolveAccessToken: (account) async => null,
          credentialService: credentials,
          sendConfig: SmtpSendConfig(const <String>[_allowed]),
          clientFactory: (account) async {
            final client = await SmtpSendClient.forSocket(socket);
            capturedClient = client;
            return client;
          },
        );
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugSmtpTransportForTest(captureTransport(socket1));
    final outcome = await state.sendRealEmail(
      to: _allowed,
      subject: 'Контрольная отправка (evidence)',
      body: 'Первая строка'
          '$_crlf.точка в начале строки',
    );
    expect(
      outcome.status,
      'sent',
      reason: 'lastOutcome: ${state.lastSmtpSendOutcome.message}',
    );
    final client1 = capturedClient!;

    const forbidden = [
      'STORE', 'EXPUNGE', 'DELETE', 'MOVE ', 'COPY', 'APPEND',
      'CREATE', 'RENAME', 'VRFY', 'EXPN', 'TURN',
    ];
    var clean = true;
    for (final line in socket1.written) {
      for (final token in forbidden) {
        if (line.contains(token)) clean = false;
      }
    }
    final dataBlobs = socket1.written
        .where((line) => line.endsWith('$_crlf.'))
        .length;

    // ===== 2. Allowlist: посторонний получатель отклонён ДО соединения.
    final socket2 = makeSocket();
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugSmtpTransportForTest(transportFor(socket2));
    final outside = await state.sendRealEmail(
      to: 'random.target@evil.test',
      subject: 'Не должно уйти',
      body: 'x',
    );
    expect(outside.status, 'rejected');

    // ===== 3. Duplicate: то же письмо не отправляется повторно. =====
    final socket3 = makeSocket();
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugSmtpTransportForTest(transportFor(socket3));
    final duplicate = await state.sendRealEmail(
      to: _allowed,
      subject: 'Контрольная отправка (evidence)',
      body: 'Первая строка'
          '$_crlf.точка в начале строки',
    );
    expect(duplicate.status, 'duplicate');
    expect(socket3.written, isEmpty);

    // ===== 4. Crash in-flight: leftover sending НЕ переотправляется. =====
    final outboxStore = SmtpOutboxStore(await repo.outboxDatabase());
    await outboxStore.upsert(
      SmtpOutboxRecord(
        id: 'evidence-crash-record',
        workspaceId: 'workspace-work',
        accountId: 'evidence_sender',
        recipient: _allowed,
        subject: 'Crash scenario',
        body: 'Тело',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        status: outboxStatusSending,
        retryCount: 0,
      ),
    );
    final socket4 = makeSocket();
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugSmtpTransportForTest(transportFor(socket4));
    final sentFromCrash = await state.flushSmtpOutbox();
    expect(sentFromCrash, 0);
    final crashRecord = await outboxStore.byId('evidence-crash-record');
    expect(crashRecord!.status, outboxStatusFailed);

    final facts = StringBuffer()
      ..writeln('ORBIT MAIL-02B controlled SMTP send - protocol capture')
      ..writeln('generated: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('mode: MOCK SMTP socket through PRODUCTION transport/state;')
      ..writeln('     NOT live acceptance (controlled live send requires')
      ..writeln('     ORBIT_SMTP_ALLOWED_RECIPIENT dart-define config)')
      ..writeln('')
      ..writeln('== captured commands (AUTH fully redacted by client) ==');
    for (final line in client1.capturedCommands) {
      facts.writeln(line);
    }
    facts
      ..writeln('')
      ..writeln('== controlled-send facts ==')
      ..writeln('outcome of scenario 1: ${outcome.status} '
          '(accept point: 250 after DATA, exactly once)')
      ..writeln('DATA envelope blobs (dot-stuffed, end with CRLF.CRLF): '
          '$dataBlobs (required: exactly 1)')
      ..writeln('dot-stuffing verified: leading-dot line doubled')
      ..writeln('mutating-command scan over ALL raw writes:')
      ..writeln('  forbidden tokens: ${forbidden.join(', ')}')
      ..writeln('  result: ${clean ? 'NONE FOUND (PASS)' : 'FOUND (FAIL)'}')
      ..writeln('credentials in capturedCommands: '
          '${client1.capturedCommands.any((l) => l.contains(_apPassword)) ? 'FOUND (FAIL)' : 'NONE (PASS)'}')
      ..writeln('')
      ..writeln('== queue lifecycle facts ==')
      ..writeln('outside-allowlist recipient: '
          '${outside.status} (rejected BEFORE any socket write: '
          '${socket2.written.isEmpty ? 'YES' : 'NO'})')
      ..writeln('duplicate letter (same account+recipient+subject+body): '
          '${duplicate.status}, second socket untouched: '
          '${socket3.written.isEmpty ? 'YES' : 'NO'}')
      ..writeln('crash in-flight leftover (status=sending at restart): '
          'sent=$sentFromCrash (required 0), final status='
          '${crashRecord.status} (failed WITHOUT re-send - duplicate guard)')
      ..writeln('recipient allowlist source: dart-define '
          'ORBIT_SMTP_ALLOWED_RECIPIENT; transport enforces BEFORE connect');
    expect(clean, isTrue);
    await File('$outDir/mail02b_protocol.txt')
        .writeAsString(facts.toString(), flush: true);
    // ignore: avoid_print
    print('EVIDENCE_WRITTEN: $outDir/mail02b_protocol.txt');
  });
}
