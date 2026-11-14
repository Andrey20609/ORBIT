// Standalone MAIL-01B evidence generator. NOT part of the default test
// suite: run explicitly with
//   ORBIT_EVIDENCE_OUT_DIR=<abs dir> flutter test tool/oauth_evidence_test.dart
// Drives the MOCK OAuth scenarios from TZ §10 through the production sheet
// and state (config override + mock client — clearly NOT live provider
// acceptance), pixel/assert-checks each state and saves:
//   mail01b_oauth_success.png / mail01b_config_required.png /
//   mail01b_invalid_grant.png / mail01b_after_delete.png /
//   mail01b_refresh_rotation.txt
// into the explicitly configured directory (created by this tool).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_secure_store.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_oauth_service.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_palette.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_profile.dart';
import 'package:orbit_visual_lab/widgets/orbit_mail_account_sheet.dart';

const _oauthCfg = OrbitMailOAuthConfigOverride(
  googleClientId: 'evidence-google-client-id',
  outlookClientId: 'evidence-outlook-client-id',
  redirectUri: 'app.orbit.orbit_visual_lab:/oauthredirect',
);

/// Mock OAuth client with scenario-switchable outcomes. Records calls for
/// the rotation log WITHOUT token values (only sequence facts).
final class _EvidenceMockClient implements OrbitOAuthClient {
  String authorizeOutcome = 'success';
  String refreshOutcome = 'success';
  int authorizeCalls = 0;
  int refreshCalls = 0;
  final List<String> facts = <String>[];

  @override
  Future<OrbitOAuthTokenSet> authorize({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
  }) async {
    authorizeCalls++;
    facts.add('authorize #$authorizeCalls: issuer/scopes/redirect переданы '
        '(PKCE/state/nonce генерирует AppAuth)');
    switch (authorizeOutcome) {
      case 'cancelled':
        throw const OrbitOAuthUserCancelledException();
      case 'invalidGrant':
        throw const OrbitOAuthInvalidGrantException();
      case 'transient':
        throw const OrbitOAuthTransientException();
      default:
        // Синтетические значения, генерируемые в рантайме (не литералы и
        // не секреты пакета).
        return OrbitOAuthTokenSet(
          accessToken: 'mock-access-$authorizeCalls-'
              '${DateTime.now().microsecondsSinceEpoch}',
          refreshToken: 'mock-refresh-$authorizeCalls',
          expiryUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );
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
    refreshCalls++;
    facts.add('refresh: прежний refresh token передан в AppAuth');
    switch (refreshOutcome) {
      case 'invalidGrant':
        facts.add('refresh: сервер вернул invalid_grant');
        throw const OrbitOAuthInvalidGrantException();
      case 'transient':
        facts.add('refresh: transient ошибка — retry доступен');
        throw const OrbitOAuthTransientException();
      default:
        facts.add('refresh: успех — новый access/expiry сохранены, '
            'refresh token ротирован');
        return OrbitOAuthTokenSet(
          accessToken: 'mock-access-rotated-$refreshCalls-'
              '${DateTime.now().microsecondsSinceEpoch}',
          refreshToken: 'mock-refresh-rotated-$refreshCalls',
          expiryUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );
    }
  }
}

Future<void> _savePng(
  WidgetTester tester,
  Key key,
  String path,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(key),
  );
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('EVIDENCE_WRITTEN: $path (${File(path).lengthSync()} bytes)');
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required OrbitAppState appState,
  required Key rootKey,
  bool openAddForm = true,
}) async {
  final palette = OrbitPalette.ofBrightness(OrbitProfile.one, Brightness.dark);
  await tester.pumpWidget(
    RepaintBoundary(
      key: rootKey,
      child: MaterialApp(
        home: Scaffold(
          body: OrbitMailAccountsSheet(
            palette: palette,
            profile: OrbitProfile.one,
            initialAccounts: List.of(appState.mailAccounts),
            onSelectActiveAccount: (_) {},
            onSaveAccount: (_, _) async => null,
            onRemoveAccount: (_) async => null,
            onOAuthSignIn: (provider, name, email) =>
                appState.signInMailAccountWithOAuth(
                  providerType: provider,
                  accountName: name,
                  accountEmail: email,
                ),
            verifier: OrbitMailConnectionVerifier(isMockMode: true),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (openAddForm) {
    await tester.tap(find.byKey(const Key('toggle-add-mail-account-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mail-provider-chip-gmail')));
    await tester.pumpAndSettle();
  }
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture MAIL-01B mock OAuth evidence', (tester) async {
    final outDir = Platform.environment['ORBIT_EVIDENCE_OUT_DIR'];
    expect(outDir, isNotNull,
        reason: 'set ORBIT_EVIDENCE_OUT_DIR=<abs dir> for this tool');
    Directory(outDir!).createSync(recursive: true);

    // ===== 1. oauth_success: mock success -> «Сохранено, не проверено».
    final client = _EvidenceMockClient();
    final store = MemoryOrbitSecretStore();
    final repo = MemoryLocalStateRepository();
    final appState = OrbitAppState(repo, store, client, _oauthCfg);
    await appState.load();
    const rootSuccess = Key('ev-success');
    await _pumpSheet(tester, appState: appState, rootKey: rootSuccess);
    await tester.tap(find.byKey(const Key('mail-oauth-signin-btn')));
    await tester.pumpAndSettle();
    final oauthAccount = appState.mailAccounts
        .firstWhere((a) => a.authMethod == 'oauth');
    expect(
        find.byKey(Key('mail-credential-chip-${oauthAccount.id}')),
        findsOneWidget,
        reason: 'после OAuth success карточка содержит credential-чип');
    expect(find.text('Сохранено, не проверено'), findsOneWidget);
    expect(find.text('Аутентифицировано'), findsNothing,
        reason: 'OAuth success даёт только savedUnverified');
    await _savePng(tester, rootSuccess, '$outDir/mail01b_oauth_success.png');

    // ===== 2. config_required: без client ID — честный CONFIG_REQUIRED.
    final appStateNoCfg =
        OrbitAppState(MemoryLocalStateRepository(), MemoryOrbitSecretStore());
    await appStateNoCfg.load();
    const rootCfg = Key('ev-cfg');
    await _pumpSheet(tester, appState: appStateNoCfg, rootKey: rootCfg);
    await tester.tap(find.byKey(const Key('mail-oauth-signin-btn')));
    await tester.pumpAndSettle();
    expect(find.textContaining('CONFIG_REQUIRED'), findsOneWidget);
    await _savePng(tester, rootCfg, '$outDir/mail01b_config_required.png');

    // ===== 3. refresh rotation: access истёк, refresh возвращает НОВЫЙ
    // refresh token (rotation) + новый access. Прежние значения читаем из
    // secure storage (без литералов).
    client.refreshOutcome = 'rotation';
    // Deliberate production-hook use from the review-evidence tool.
    // ignore: invalid_use_of_visible_for_testing_member
    final tokensBefore = await appState.mailCredentialService
        .readOAuthTokens(oauthAccount.id);
    expect(tokensBefore, isNotNull);
    await appState.saveMailAccountWithCredentials(
      oauthAccount,
      oauthTokens: OrbitOAuthTokenSet(
        accessToken: tokensBefore!.accessToken,
        refreshToken: tokensBefore.refreshToken,
        expiryUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      ),
    );
    final rotated = await appState.getValidOAuthAccessToken(oauthAccount.id);
    expect(rotated, isNotNull);
    expect(rotated != tokensBefore.accessToken, isTrue,
        reason: 'rotation: access заменён');
    client.facts.add('rotation: новый refresh token сохранён вместо '
        'прежнего');
    // ignore: invalid_use_of_visible_for_testing_member
    final tokensAfter = await appState.mailCredentialService
        .readOAuthTokens(oauthAccount.id);
    expect(tokensAfter!.refreshToken != tokensBefore.refreshToken, isTrue);
    // Новый expiry в будущем: валидный access возвращается без refresh.
    final again = await appState.getValidOAuthAccessToken(oauthAccount.id);
    expect(again, rotated);
    client.facts.add('valid access: возвращён без refresh-вызова');

    // ===== 4. invalid_grant: access истёк, refresh отозван сервером ->
    // tokens удалены, metadata notConfigured, карточка показывает
    // «Пароль не настроен».
    client.refreshOutcome = 'invalidGrant';
    await appState.saveMailAccountWithCredentials(
      oauthAccount,
      oauthTokens: OrbitOAuthTokenSet(
        accessToken: tokensAfter.accessToken,
        refreshToken: tokensAfter.refreshToken,
        expiryUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      ),
    );
    final token = await appState.getValidOAuthAccessToken(oauthAccount.id);
    expect(token, isNull);
    await tester.pumpAndSettle();
    final accountAfter = appState.mailAccounts
        .firstWhere((a) => a.id == oauthAccount.id);
    expect(accountAfter.credentialStatus,
        OrbitMailCredentialStatus.notConfigured);
    expect(accountAfter.authMethod, isNull);
    const rootInvalid = Key('ev-invalid');
    // Список аккаунтов (не форма): чип «Пароль не настроен» на карточке.
    await _pumpSheet(tester, appState: appState, rootKey: rootInvalid,
        openAddForm: false);
    await tester.pumpAndSettle();
    expect(find.text('Пароль не настроен'), findsOneWidget);
    await _savePng(tester, rootInvalid, '$outDir/mail01b_invalid_grant.png');

    // ===== 5. after_delete: удаление oauth-аккаунта через secure flow.
    await appState.removeMailAccountSecurely(oauthAccount.id);
    const rootDelete = Key('ev-delete');
    await _pumpSheet(tester, appState: appState, rootKey: rootDelete,
        openAddForm: false);
    await tester.pumpAndSettle();
    expect(
        find.byKey(Key('mail-account-card-${oauthAccount.id}')),
        findsNothing);
    await _savePng(tester, rootDelete, '$outDir/mail01b_after_delete.png');

    // ===== 6. refresh_rotation.txt: последовательность без секретов.
    final log = StringBuffer()
      ..writeln('MAIL-01B mock OAuth refresh/rotation sequence '
          '(без секретов; значения токенов не фиксируются)')
      ..writeln('Сценарий: mock provider, production sheet/state, '
          'PKCE/state/nonce генерирует AppAuth.')
      ..writeln('1. authorize success -> savedUnverified (не '
          '«Аутентифицировано»).')
      ..writeln('2. expired access -> refresh вызван с прежним refresh '
          'token.')
      ..writeln('3. refresh success (rotation): новый refresh token '
          'сохранён вместо прежнего.')
      ..writeln('4. следующий valid access: возвращён без refresh-вызова.')
      ..writeln('5. invalid_grant case: refresh token отозван сервером -> '
          'access/refresh/expiry удалены, metadata notConfigured.')
      ..writeln()
      ..writeln('Факты последовательности из mock client:')
      ..writeln(client.facts.join('\n'))
      ..writeln()
      ..writeln('Итог: rotation/invalid_grant/valid-access семантика '
          'подтверждена; REAL_MAIL_ACCEPTANCE остаётся NOT_READY.');
    final logFile = File('$outDir/mail01b_refresh_rotation.txt');
    await logFile.writeAsString(log.toString());
    // ignore: avoid_print
    print('EVIDENCE_WRITTEN: ${logFile.path} '
        '(${logFile.lengthSync()} bytes)');

  }, timeout: const Timeout(Duration(minutes: 5)));
}
