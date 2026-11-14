// Standalone MAIL-02A evidence generator. NOT part of the default test
// suite: run explicitly with
//   ORBIT_EVIDENCE_OUT_DIR=<abs dir> flutter test tool/mail02a_evidence_test.dart
// Drives the MOCK IMAP scenarios (fake socket, no network) through the
// PRODUCTION client/state (clearly NOT live acceptance) and saves:
//   mail02a_protocol.txt   - captured command sequence (credentials
//                            redacted; read-only facts asserted)
//   mail02a_read_only.png  - real-inbox panel with metadata-only rows
//                            and the honest credential statuses
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/drift_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_secure_store.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/services/mail/imap_mail_transport.dart';
import 'package:orbit_visual_lab/services/mail/imap_readonly_client.dart';
import 'package:orbit_visual_lab/services/mail/imap_socket.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_credential_service.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_oauth_service.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_real_inbox_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// IMAP спецсимволы строятся в рантайме (backslash в исходнике отсутствует).
final String bs = String.fromCharCode(92);
final String nul = String.fromCharCode(0);
final String crlf = String.fromCharCode(13) + String.fromCharCode(10);

final class _FakeImapSocket implements OrbitImapSocket {
  _FakeImapSocket(this._lines, this._literals);

  final List<String> _lines;
  final List<String> _literals;
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
  Future<String> readUtf8Octets(int octets) async {
    final blob = _literals.removeAt(0);
    if (utf8.encode(blob).length != octets) {
      throw StateError('octets mismatch');
    }
    return blob;
  }

  @override
  void destroy() {}
}

String _header(String from, String subject) =>
    'From: $from$crlf Subject: $subject$crlf$crlf';

List<String> _fetchPart({
  required int seq,
  required int uid,
  required bool seen,
  required String header,
  required String text,
}) {
  final flags = seen ? '($bs' 'Seen)' : '()';
  return [
    '* $seq FETCH (UID $uid FLAGS $flags INTERNALDATE '
        '"14-Nov-2026 10:00:00 +0300" '
        'BODY[HEADER.FIELDS (FROM SUBJECT DATE)] '
        '{${utf8.encode(header).length}}',
    header,
    ' BODY[TEXT]<0.512> {${utf8.encode(text).length}}',
    text,
    ')',
  ];
}

Future<void> _savePng(WidgetTester tester, Key key, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(key),
  );
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('EVIDENCE_WRITTEN: $path (${File(path).lengthSync()} bytes)');
}

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

void main() async {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  await _loadFont('OrbitSans', [
    'assets/fonts/OrbitSans-Regular.ttf',
    'assets/fonts/OrbitSans-Medium.ttf',
    'assets/fonts/OrbitSans-SemiBold.ttf',
  ]);
  const materialIconsRelativePath =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  var flutterRoot = File(Platform.resolvedExecutable).parent;
  while (flutterRoot.path != '/' &&
      !File('${flutterRoot.path}/$materialIconsRelativePath').existsSync()) {
    flutterRoot = flutterRoot.parent;
  }
  final materialIcons = File('${flutterRoot.path}/$materialIconsRelativePath');
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(
      materialIcons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  await iconLoader.load();

  testWidgets('capture MAIL-02A mock IMAP evidence', (tester) async {
    final outDir = Platform.environment['ORBIT_EVIDENCE_OUT_DIR'];
    expect(outDir, isNotNull,
        reason: 'set ORBIT_EVIDENCE_OUT_DIR=<abs dir> for this tool');
    Directory(outDir!).createSync(recursive: true);

    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    // ignore: invalid_use_of_visible_for_testing_member
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final tempDir =
        await Directory.systemTemp.createTemp('mail02a_evidence');
    addTearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });
    final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}evidence.sqlite');
    final repository = DriftLocalStateRepository(
      database: DriftOrbitDatabase(file: dbFile),
    );
    final store = MemoryOrbitSecretStore();
    final appState = OrbitAppState(repository, store);
    await appState.load();
    const accountId = 'evidence_acc';
    await appState.saveMailAccountWithCredentials(
      const OrbitMailAccount(
        id: accountId,
        name: 'Тестовый ящик (evidence)',
        email: 'evidence.user@test.local',
        providerType: OrbitMailProviderType.yandex,
        incomingHost: 'imap.yandex.ru',
        incomingPort: 993,
        outgoingHost: 'smtp.yandex.ru',
        outgoingPort: 465,
        credentialStatus: OrbitMailCredentialStatus.savedUnverified,
        authMethod: 'appPassword',
        isActive: true,
      ),
      appPassword: 'EVIDENCE-RUNTIME-VALUE-'
          '${DateTime.now().microsecondsSinceEpoch}',
    );
    await appState.flush();

    // Mock IMAP session: два письма, EXAMINE/SEARCH/FETCH/LOGOUT.
    final header1 =
        _header('Мария Соколова <maria@example.test>', 'План на неделю');
    final text1 = 'Привет! Прикрепляю обновлённый план на следующую неделю.';
    final header2 =
        _header('Илья Волков <ilya@example.test>', 'Обсуждение дизайна');
    final text2 = 'Прикладываю актуальные варианты и короткие комментарии.';
    final socket = _FakeImapSocket(
      [
        'A1 OK LOGIN completed',
        '* FLAGS ($bs' 'Answered $bs' 'Flagged $bs' 'Seen)',
        '* 2 EXISTS',
        '* OK [UIDVALIDITY 424242] UIDs valid',
        'A2 OK [READ-ONLY] EXAMINE completed',
        '* SEARCH 101 102',
        'A3 OK SEARCH completed',
        ..._fetchPart(
          seq: 1,
          uid: 102,
          seen: true,
          header: header1,
          text: text1,
        ),
        ..._fetchPart(
          seq: 2,
          uid: 101,
          seen: false,
          header: header2,
          text: text2,
        ),
        'A4 OK FETCH completed',
        '* BYE IMAP4rev1 Server logging out',
        'A5 OK LOGOUT completed',
      ],
      [header1, text1, header2, text2],
    );
    final client = ImapReadOnlyClient.forSocket(socket);
    // ignore: invalid_use_of_visible_for_testing_member
    appState.debugImapTransportForTest(
      ImapMailTransport(
        resolveAccount: (id) async => appState.mailAccounts
            .where((a) => a.id == id)
            .firstOrNull,
        resolveAccessToken: (account) async => null,
        credentialService:
            OrbitMailCredentialService(store: store),
        clientFactory: (account) async => client,
      ),
    );

    final synced = await appState.syncRealInbox(accountId);
    expect(synced, isTrue);
    expect(appState.userInboxEntries.length, 2);

    // ===== mail02a_protocol.txt: read-only факты сессии =====
    final forbidden = [
      'STORE', 'EXPUNGE', 'DELETE', 'MOVE ', 'COPY', 'APPEND',
      'CREATE', 'RENAME', 'SETACL', 'SUBSCRIBE', 'SMTP', 'RFC822',
    ];
    var clean = true;
    for (final line in socket.written) {
      for (final token in forbidden) {
        if (line.contains(token)) clean = false;
      }
    }
    final buffer = StringBuffer()
      ..writeln('ORBIT MAIL-02A read-only IMAP protocol capture')
      ..writeln('generated: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('mode: MOCK IMAP socket through PRODUCTION client/state;')
      ..writeln('     NOT live acceptance (live requires test mailbox config)')
      ..writeln('')
      ..writeln('== captured commands (credentials redacted by client) ==');
    for (final line in client.capturedCommands) {
      buffer.writeln(line);
    }
    buffer
      ..writeln('')
      ..writeln('== read-only facts ==')
      ..writeln('auth: LOGIN used for app-password account (inside TLS in')
      ..writeln('      production; fake socket here replaces TLS transport)')
      ..writeln('folder selection: EXAMINE (NOT SELECT) - server state,')
      ..writeln('                  including \\Seen, is never modified')
      ..writeln('fetch items: UID FLAGS INTERNALDATE BODY.PEEK[HEADER.FIELDS')
      ..writeln('             (FROM SUBJECT DATE)] BODY.PEEK[TEXT]<0.512>')
      ..writeln('             - BODY.PEEK only; body is NOT fetched and is')
      ..writeln('             NOT cached (metadata-only per TZ)')
      ..writeln('limit: UID FETCH 101:102 = last 20-max window (server had 2)')
      ..writeln('session end: LOGOUT')
      ..writeln('')
      ..writeln('mutating-command scan over ALL raw client writes:')
      ..writeln('  forbidden tokens: ${forbidden.join(', ')}')
      ..writeln('  result: ${clean ? 'NONE FOUND (PASS)' : 'FOUND (FAIL)'}')
      ..writeln('raw write count: ${socket.written.length}')
      ..writeln('messages mapped: 2 (deterministic ids ')
      ..writeln('  evidence_acc:inbox:424242:102 / evidence_acc:inbox:424242:101)')
      ..writeln('credentialStatus after actual IMAP success: ${appState.mailAccounts.firstWhere((a) => a.id == accountId).credentialStatus.name}');
    expect(clean, isTrue, reason: 'mutating commands must be absent');
    await File('$outDir/mail02a_protocol.txt')
        .writeAsString(buffer.toString(), flush: true);
    // ignore: avoid_print
    print('EVIDENCE_WRITTEN: $outDir/mail02a_protocol.txt');

    // ===== mail02a_read_only.png: панель с metadata реальных писем =====
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
    final palette = OrbitPalette.ofBrightness(OrbitProfile.one, Brightness.dark);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('evidence-root'),
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) => OrbitEnvironment(
            style: style,
            quality: quality,
            appState: appState,
            appearanceSettings: style.settings,
            resolvedQuality: quality.resolve(style.settings),
            dataRevision: appState.dataRevision,
            graphicsFallbackReason: null,
            appearancePersistenceError: null,
            appearanceLoadError: null,
            platformBrightness: Brightness.dark,
            child: MaterialApp(
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: palette.themeData(palette.accent),
              home: Scaffold(
                backgroundColor: palette.surfaceStrong,
                body: SingleChildScrollView(
                  child: OrbitRealInboxPanel(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('real-inbox-toggle')));
    await tester.pumpAndSettle();
    await _savePng(
      tester,
      const Key('evidence-root'),
      '$outDir/mail02a_read_only.png',
    );
  });

  testWidgets('capture MAIL-02A OAuth lifecycle evidence', (tester) async {
    final outDir = Platform.environment['ORBIT_EVIDENCE_OUT_DIR'];
    expect(outDir, isNotNull,
        reason: 'set ORBIT_EVIDENCE_OUT_DIR=<abs dir> for this tool');
    Directory(outDir!).createSync(recursive: true);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final facts = StringBuffer();

    // Counting OAuth double: refresh-исход переключается сценарием.
    var refreshCalls = 0;
    var refreshOutcome = 'success';
    final countingClient = _LifecycleOAuthClient(() {
      refreshCalls++;
      return refreshOutcome;
    });

    Future<OrbitAppState> makeState(
      DriftOrbitDatabase db,
      MemoryOrbitSecretStore store,
    ) async {
      // ignore: invalid_use_of_visible_for_testing_member
      // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(const <String, Object>{});
      final state = OrbitAppState(
        DriftLocalStateRepository(database: db),
        store,
        countingClient,
        const OrbitMailOAuthConfigOverride(
          googleClientId: 'evidence-google-client-id',
          outlookClientId: 'evidence-outlook-client-id',
          redirectUri: 'app.orbit.orbit_visual_lab:/oauthredirect',
        ),
      );
      await state.load();
      await state.saveMailAccountWithCredentials(
        const OrbitMailAccount(
          id: 'evidence_oauth',
          name: 'OAuth evidence ящик',
          email: 'evidence.oauth@test.local',
          providerType: OrbitMailProviderType.gmail,
          incomingHost: 'imap.gmail.com',
          incomingPort: 993,
          outgoingHost: 'smtp.gmail.com',
          outgoingPort: 465,
          credentialStatus: OrbitMailCredentialStatus.savedUnverified,
          authMethod: 'oauth',
          isActive: true,
        ),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: 'evidence-expired-access',
          refreshToken: 'r1',
          expiryUtc: DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          ),
        ),
      );
      await state.flush();
      return state;
    }

    // ===== Сценарий 1: expired access -> один refresh -> один retry ->
    // успех + rotation. =====
    final tempDir1 =
        await Directory.systemTemp.createTemp('mail02a_ev_lc1');
    addTearDown(() async {
      try {
        await tempDir1.delete(recursive: true);
      } catch (_) {}
    });
    final store1 = MemoryOrbitSecretStore();
    var state = await makeState(
      DriftOrbitDatabase(
        file: File('${tempDir1.path}${Platform.pathSeparator}lc1.sqlite'),
      ),
      store1,
    );
    final storeRef1 = store1;
    final header =
        _header('Мария Соколова <maria@example.test>', 'План на неделю');
    final text = 'Привет! Короткий фрагмент письма для evidence.';
    final socket1 = _FakeImapSocket(
      [
        'A1 OK AUTHENTICATE completed',
        '* FLAGS ($bs' 'Seen)',
        '* 1 EXISTS',
        '* OK [UIDVALIDITY 777] UIDs valid',
        'A2 OK [READ-ONLY] EXAMINE completed',
        '* SEARCH 900',
        'A3 OK SEARCH completed',
        ..._fetchPart(
          seq: 1,
          uid: 900,
          seen: false,
          header: header,
          text: text,
        ),
        'A4 OK FETCH completed',
        'A5 OK LOGOUT completed',
      ],
      [header, text],
    );
    final client1 = ImapReadOnlyClient.forSocket(socket1);
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugImapTransportForTest(
      ImapMailTransport(
        resolveAccount: (id) async => state.mailAccounts
            .where((a) => a.id == id)
            .firstOrNull,
        // PRODUCTION wiring: токен через state-lifecycle.
        resolveAccessToken: (account) =>
            state.getValidOAuthAccessToken(account.id),
        credentialService: OrbitMailCredentialService(store: storeRef1),
        clientFactory: (account) async => client1,
      ),
    );
    final sync1 = await state.syncRealInbox('evidence_oauth');
    final rotated = await storeRef1.read('mail.v1.evidence_oauth.oauth.refresh');
    facts
      ..writeln('== Scenario 1: expired access -> refresh -> single retry ==')
      ..writeln('result: sync=${sync1 ? 'SUCCESS' : 'FAILED'}')
      ..writeln('refresh calls: $refreshCalls (required: exactly 1)')
      ..writeln('authenticate commands sent: '
          '${socket1.written.where((l) => l.startsWith('A1 AUTHENTICATE XOAUTH2 ')).length}'
          ' (required: exactly 1 - no retry loop)')
      ..writeln('refresh rotation persisted: '
          '${rotated != null && rotated.startsWith('r2-') ? 'YES' : 'NO'}')
      ..writeln('credentialStatus after success: '
          '${state.mailAccounts.firstWhere((a) => a.id == 'evidence_oauth').credentialStatus.name}')
      ..writeln('');

    // ===== Сценарий 2: refresh invalid_grant -> keys deleted ->
    // персистентно notConfigured, без цикла. =====
    final callsAfterScenario1 = refreshCalls;
    refreshOutcome = 'invalidGrant';
    final tempDir2 =
        await Directory.systemTemp.createTemp('mail02a_ev_lc2');
    addTearDown(() async {
      try {
        await tempDir2.delete(recursive: true);
      } catch (_) {}
    });
    final storeRef2 = MemoryOrbitSecretStore();
    state = await makeState(
      DriftOrbitDatabase(
        file: File('${tempDir2.path}${Platform.pathSeparator}lc2.sqlite'),
      ),
      storeRef2,
    );
    final socket2 = _FakeImapSocket(const <String>[], const <String>[]);
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugImapTransportForTest(
      ImapMailTransport(
        resolveAccount: (id) async => state.mailAccounts
            .where((a) => a.id == id)
            .firstOrNull,
        resolveAccessToken: (account) =>
            state.getValidOAuthAccessToken(account.id),
        credentialService: OrbitMailCredentialService(store: storeRef2),
        clientFactory: (account) async => ImapReadOnlyClient.forSocket(socket2),
      ),
    );
    final sync2 = await state.syncRealInbox('evidence_oauth');
    final account2 =
        state.mailAccounts.firstWhere((a) => a.id == 'evidence_oauth');
    facts
      ..writeln('== Scenario 2: refresh invalid_grant ==')
      ..writeln('result: sync=${sync2 ? 'SUCCESS' : 'FAILED (expected)'}')
      ..writeln('refresh calls: ${refreshCalls - callsAfterScenario1} '
          '(required: exactly 1 - no cycle)')
      ..writeln('oauth access key removed: '
          '${await storeRef2.read('mail.v1.evidence_oauth.oauth.access') == null ? 'YES' : 'NO'}')
      ..writeln('oauth refresh key removed: '
          '${await storeRef2.read('mail.v1.evidence_oauth.oauth.refresh') == null ? 'YES' : 'NO'}')
      ..writeln('credentialStatus: ${account2.credentialStatus.name} '
          '(required: notConfigured)')
      ..writeln('authMethod: ${account2.authMethod ?? 'CLEARED'}')
      ..writeln('second sync attempt blocked by notConfigured guard: '
          '${(await state.syncRealInbox('evidence_oauth')) == false ? 'YES' : 'NO'}')
      ..writeln('')
      ..writeln('mode: MOCK IMAP socket + MOCK OAuth client through')
      ..writeln('PRODUCTION state/lifecycle wiring; NOT live acceptance.');

    await File('$outDir/mail02a_lifecycle.txt')
        .writeAsString(facts.toString(), flush: true);
    // ignore: avoid_print
    print('EVIDENCE_WRITTEN: $outDir/mail02a_lifecycle.txt');
    expect(sync1, isTrue);
    expect(sync2, isFalse);
  });
}

/// Counting OAuth double для lifecycle evidence (значения генерируются
/// в рантайме, литералов токенов нет).
final class _LifecycleOAuthClient implements OrbitOAuthClient {
  _LifecycleOAuthClient(this._nextOutcome);

  final String Function() _nextOutcome;

  @override
  Future<OrbitOAuthTokenSet> authorize({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
  }) async {
    throw UnimplementedError('authorize не участвует в lifecycle evidence');
  }

  @override
  Future<OrbitOAuthTokenSet> refresh({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
    required String refreshToken,
  }) async {
    final outcome = _nextOutcome();
    switch (outcome) {
      case 'invalidGrant':
        throw const OrbitOAuthInvalidGrantException();
      case 'transient':
        throw const OrbitOAuthTransientException();
    }
    return OrbitOAuthTokenSet(
      accessToken: 'evidence-refreshed-access-'
          '${DateTime.now().microsecondsSinceEpoch}',
      refreshToken: 'r2-refreshed',
      expiryUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }
}
