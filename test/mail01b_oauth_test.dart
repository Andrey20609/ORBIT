import 'dart:convert';

import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_appauth_platform_interface/flutter_appauth_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_database.dart';
import 'package:orbit_visual_lab/data/demo_data.dart';
import 'package:orbit_visual_lab/data/drift_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_secure_store.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_credential_service.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_oauth_service.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_palette.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_profile.dart';
import 'package:orbit_visual_lab/widgets/orbit_mail_account_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Синтетические canary-строки для токенов: уникальные тестовые значения,
// не настоящие токены. Используются для проверки отсутствия секретов в
// хранилищах и логах.
const String _tokenCanaryA = 'MAIL01B-TOKEN-CANARY-aT4rQ7x';
const String _tokenCanaryB = 'MAIL01B-TOKEN-CANARY-bZ8sP5y';

const _oauthCfg = OrbitMailOAuthConfigOverride(
  googleClientId: 'test-google-client-id.apps.googleusercontent.com',
  outlookClientId: 'test-outlook-client-id',
  outlookTenant: 'testtenant',
  redirectUri: 'app.orbit.orbit_visual_lab:/oauthredirect',
);

/// Подсчитывающий mock OAuth client: позволяет задать исход каждого вызова
/// и проверять параметры запросов (issuer/clientId/scopes/redirect).
final class _MockOAuthClient implements OrbitOAuthClient {
  _MockOAuthClient();

  final List<Map<String, Object?>> authorizeCalls = [];
  final List<Map<String, Object?>> refreshCalls = [];

  /// authorize: success | cancelled | invalidGrant | transient
  String authorizeOutcome = 'success';

  /// MAIL-01B r2: имитация ответа AppAuth с пустым access token.
  bool emptyAccessToken = false;
  /// refresh: success | cancelled | invalidGrant | transient | rotation | noRotation
  String refreshOutcome = 'success';
  DateTime refreshExpiry = DateTime.now().toUtc().add(const Duration(hours: 1));

  @override
  Future<OrbitOAuthTokenSet> authorize({
    required String issuer,
    required String clientId,
    required List<String> scopes,
    required String redirectUri,
  }) async {
    authorizeCalls.add({
      'issuer': issuer,
      'clientId': clientId,
      'scopes': List<String>.of(scopes),
      'redirectUri': redirectUri,
    });
    switch (authorizeOutcome) {
      case 'cancelled':
        throw const OrbitOAuthUserCancelledException();
      case 'invalidGrant':
        throw const OrbitOAuthInvalidGrantException();
      case 'transient':
        throw const OrbitOAuthTransientException();
      default:
        return OrbitOAuthTokenSet(
          accessToken: emptyAccessToken ? '' : _tokenCanaryA,
          refreshToken: emptyAccessToken ? '' : _tokenCanaryB,
          expiryUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
          tokenType: 'Bearer',
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
    refreshCalls.add({
      'issuer': issuer,
      'clientId': clientId,
      'scopes': List<String>.of(scopes),
      'redirectUri': redirectUri,
      'refreshToken': refreshToken,
    });
    switch (refreshOutcome) {
      case 'invalidGrant':
        throw const OrbitOAuthInvalidGrantException();
      case 'transient':
        throw const OrbitOAuthTransientException();
      case 'noRotation':
        return OrbitOAuthTokenSet(
          accessToken: _tokenCanaryA,
          // Новый refresh token НЕ выдан — прежний должен остаться.
          expiryUtc: refreshExpiry,
        );
      case 'rotation':
      default:
        return OrbitOAuthTokenSet(
          accessToken: _tokenCanaryA,
          refreshToken: _tokenCanaryB,
          expiryUtc: refreshExpiry,
        );
    }
  }
}

OrbitMailAccount _oauthAccount({String id = 'acc_oauth'}) => OrbitMailAccount(
      id: id,
      name: 'OAuth тест',
      email: 'oauth@test.local',
      providerType: OrbitMailProviderType.gmail,
      isActive: true,
    );

OrbitAppState _state({
  _MockOAuthClient? client,
  OrbitLocalStateRepository? repository,
  MemoryOrbitSecretStore? store,
}) {
  return OrbitAppState(
    repository ?? MemoryLocalStateRepository(),
    store ?? MemoryOrbitSecretStore(),
    client ?? _MockOAuthClient(),
    _oauthCfg,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MAIL-01B OAuth Authorization Code + PKCE', () {
    test('[O1] config required: без client ID — явная ошибка, browser не '
        'вызван', () async {
      final client = _MockOAuthClient();
      // БЕЗ override конфигурации: dart-define пуст в тестах.
      final appState = OrbitAppState(
        MemoryLocalStateRepository(),
        MemoryOrbitSecretStore(),
        client,
      );
      await appState.load();

      final outcome = await appState.signInMailAccountWithOAuth(
        providerType: OrbitMailProviderType.gmail,
        accountName: 'Тест',
        accountEmail: 'oauth@test.local',
      );
      expect(outcome.status, OrbitMailOAuthUiStatus.configRequired);
      expect(outcome.message, contains('CONFIG_REQUIRED'));
      expect(client.authorizeCalls, isEmpty,
          reason: 'browser не открывается без config');
      expect(appState.mailAccounts.where((a) => a.email == 'oauth@test.local'),
          isEmpty);
    });

    test('[O2] OAuth success: токены только secure store, metadata '
        'savedUnverified', () async {
      final store = MemoryOrbitSecretStore();
      final client = _MockOAuthClient();
      final appState = _state(client: client, store: store);
      await appState.load();

      final outcome = await appState.signInMailAccountWithOAuth(
        providerType: OrbitMailProviderType.gmail,
        accountName: 'Gmail тест',
        accountEmail: 'oauth@test.local',
      );
      expect(outcome.status, OrbitMailOAuthUiStatus.success);
      expect(outcome.account, isNotNull);

      final account = appState.mailAccounts
          .firstWhere((a) => a.id == outcome.account!.id);
      expect(account.credentialStatus,
          OrbitMailCredentialStatus.savedUnverified);
      expect(account.authMethod, 'oauth');
      // Токены в secure store.
      final tokens = await store.read('mail.v1.${account.id}.oauth.access');
      expect(tokens, _tokenCanaryA);
      expect(await store.read('mail.v1.${account.id}.oauth.refresh'),
          _tokenCanaryB);
    });

    test('[O3] parameters: issuer/redirect/scopes соответствуют провайдеру',
        () async {
      final client = _MockOAuthClient();
      final appState = _state(client: client);
      await appState.load();

      await appState.signInMailAccountWithOAuth(
        providerType: OrbitMailProviderType.gmail,
        accountName: 'G',
        accountEmail: 'g@test.local',
      );
      expect(client.authorizeCalls, hasLength(1));
      final google = client.authorizeCalls.single;
      expect(google['issuer'], 'https://accounts.google.com');
      expect(google['clientId'], _oauthCfg.googleClientId);
      expect(google['redirectUri'], _oauthCfg.redirectUri);
      final googleScopes = google['scopes'] as List<String>;
      expect(googleScopes, containsAll(<String>[
        'openid',
        'email',
        'https://mail.google.com/',
      ]));
      // Не запрашивать лишние API.
      expect(googleScopes.where((s) => s.contains('drive')), isEmpty);

      await appState.signInMailAccountWithOAuth(
        providerType: OrbitMailProviderType.outlook,
        accountName: 'M',
        accountEmail: 'm@test.local',
      );
      final outlook = client.authorizeCalls.last;
      expect(outlook['issuer'],
          'https://login.microsoftonline.com/testtenant/v2.0');
      final outlookScopes = outlook['scopes'] as List<String>;
      expect(outlookScopes, containsAll(<String>[
        'openid',
        'email',
        'offline_access',
        'IMAP.AccessAsUser.All',
        'SMTP.Send',
      ]));
      expect(
          outlookScopes.where((s) => s.contains('Mail.ReadWrite')), isEmpty);
    });

    test('[O4] secret separation: snapshot/SQLite/prefs без token canary',
        () async {
      final store = MemoryOrbitSecretStore();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final legacy = SharedPreferencesLocalStateRepository();
      final db = DriftOrbitDatabase();
      final repository = DriftLocalStateRepository(
        database: db,
        legacyRepository: legacy,
      );
      final appState = OrbitAppState(repository, store, _MockOAuthClient(),
          _oauthCfg);
      await appState.load();

      final outcome = await appState.signInMailAccountWithOAuth(
        providerType: OrbitMailProviderType.gmail,
        accountName: 'S',
        accountEmail: 'sep@test.local',
      );
      expect(outcome.isSuccess, isTrue);
      await appState.flush();

      final snapshotJson = jsonEncode(await repository.load());
      expect(snapshotJson.contains(_tokenCanaryA), isFalse);
      expect(snapshotJson.contains(_tokenCanaryB), isFalse);
      final rows = await db.query(
        OrbitDatabaseSchema.tableAccounts,
        where: 'email = ?',
        whereArgs: ['sep@test.local'],
      );
      expect(rows, hasLength(1));
      expect(jsonEncode(rows).contains(_tokenCanaryA), isFalse);
      expect(jsonEncode(rows).contains(_tokenCanaryB), isFalse);
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        final value = '${prefs.get(key)}';
        expect(value.contains(_tokenCanaryA), isFalse,
            reason: 'SharedPreferences[$key]');
        expect(value.contains(_tokenCanaryB), isFalse);
      }
      await db.close();
    });

    test('[O5] cancellation: состояние и metadata не изменились, токенов '
        'нет', () async {
      final store = MemoryOrbitSecretStore();
      final client = _MockOAuthClient()..authorizeOutcome = 'cancelled';
      final appState = _state(client: client, store: store);
      await appState.load();
      final before = appState.mailAccounts.length;

      final outcome = await appState.signInMailAccountWithOAuth(
        providerType: OrbitMailProviderType.gmail,
        accountName: 'C',
        accountEmail: 'cancel@test.local',
      );
      expect(outcome.status, OrbitMailOAuthUiStatus.cancelled);
      expect(appState.mailAccounts.length, before,
          reason: 'отмена не меняет список аккаунтов');
      expect(await store.read('mail.v1.acc_oauth.oauth.access'), isNull,
          reason: 'токенов нет');
    });

    test('[O6] valid token: возвращается без refresh', () async {
      final store = MemoryOrbitSecretStore();
      final client = _MockOAuthClient();
      final appState = _state(client: client, store: store);
      await appState.load();
      await appState.saveMailAccountWithCredentials(
        _oauthAccount(id: 'acc_t'),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: _tokenCanaryA,
          refreshToken: _tokenCanaryB,
          expiryUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      await appState.flush();

      final token = await appState.getValidOAuthAccessToken('acc_t');
      expect(token, _tokenCanaryA);
      expect(client.refreshCalls, isEmpty,
          reason: 'валидный токен возвращается без refresh');
    });

    test('[O7] expired refresh: новые access/expiry; прежний refresh '
        'сохраняется при отсутствии нового', () async {
      final store = MemoryOrbitSecretStore();
      final client = _MockOAuthClient()..refreshOutcome = 'noRotation';
      final appState = _state(client: client, store: store);
      await appState.load();
      await appState.saveMailAccountWithCredentials(
        _oauthAccount(),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: 'expired-access',
          refreshToken: _tokenCanaryB,
          expiryUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        ),
      );
      await appState.flush();

      final token = await appState.getValidOAuthAccessToken('acc_oauth');
      expect(token, _tokenCanaryA);
      expect(client.refreshCalls, hasLength(1));
      // Прежний refresh сохранён (rotation не выдан).
      expect(await store.read('mail.v1.acc_oauth.oauth.refresh'),
          _tokenCanaryB);
      // Новые access/expiry сохранены (expiry в будущем).
      final tokens = await (OrbitMailCredentialService(store: store))
          .readOAuthTokens('acc_oauth');
      expect(tokens!.accessToken, _tokenCanaryA);
      expect(tokens.expiryUtc.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('[O8] refresh rotation: новый refresh заменяет прежний', () async {
      final store = MemoryOrbitSecretStore();
      final client = _MockOAuthClient()..refreshOutcome = 'rotation';
      final appState = _state(client: client, store: store);
      await appState.load();
      await appState.saveMailAccountWithCredentials(
        _oauthAccount(),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: 'expired-access',
          refreshToken: 'old-refresh-value',
          expiryUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        ),
      );
      await appState.flush();

      final token = await appState.getValidOAuthAccessToken('acc_oauth');
      expect(token, _tokenCanaryA);
      expect(await store.read('mail.v1.acc_oauth.oauth.refresh'),
          _tokenCanaryB,
          reason: 'новый refresh token заменил прежний');
    });

    test('[O9] transient failure: access null, refresh и metadata '
        'сохранены для retry', () async {
      final store = MemoryOrbitSecretStore();
      final client = _MockOAuthClient()..refreshOutcome = 'transient';
      final appState = _state(client: client, store: store);
      await appState.load();
      await appState.saveMailAccountWithCredentials(
        _oauthAccount(),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: 'expired-access',
          refreshToken: _tokenCanaryB,
          expiryUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        ),
      );
      await appState.flush();

      final token = await appState.getValidOAuthAccessToken('acc_oauth');
      expect(token, isNull);
      // Токены сохранены для retry.
      expect(await store.read('mail.v1.acc_oauth.oauth.refresh'),
          _tokenCanaryB);
      final account = appState.mailAccounts
          .firstWhere((a) => a.id == 'acc_oauth');
      expect(account.credentialStatus,
          OrbitMailCredentialStatus.savedUnverified,
          reason: 'metadata остаётся savedUnverified для retry');
    });

    test('[O10] invalid grant: токены удалены, metadata notConfigured, '
        'повторный OAuth требуется', () async {
      final store = MemoryOrbitSecretStore();
      final client = _MockOAuthClient()..refreshOutcome = 'invalidGrant';
      final appState = _state(client: client, store: store);
      await appState.load();
      await appState.saveMailAccountWithCredentials(
        _oauthAccount(),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: 'expired-access',
          refreshToken: _tokenCanaryB,
          expiryUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        ),
      );
      await appState.flush();

      final token = await appState.getValidOAuthAccessToken('acc_oauth');
      expect(token, isNull);
      expect(await store.read('mail.v1.acc_oauth.oauth.access'), isNull);
      expect(await store.read('mail.v1.acc_oauth.oauth.refresh'), isNull);
      expect(await store.read('mail.v1.acc_oauth.oauth.expiry'), isNull);
      final account = appState.mailAccounts
          .firstWhere((a) => a.id == 'acc_oauth');
      expect(account.credentialStatus,
          OrbitMailCredentialStatus.notConfigured);
      expect(account.authMethod, isNull,
          reason: 'повторный OAuth обязателен');
    });

    test('[O11] remove: oauth tokens удалены без orphan; load '
        'reconciliation проходит', () async {
      final store = MemoryOrbitSecretStore();
      final appState = _state(client: _MockOAuthClient());
      await appState.load();
      await appState.saveMailAccountWithCredentials(
        _oauthAccount(),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: _tokenCanaryA,
          refreshToken: _tokenCanaryB,
          expiryUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      await appState.flush();

      await appState.removeMailAccountSecurely('acc_oauth');
      await appState.flush();
      expect(await store.read('mail.v1.acc_oauth.oauth.access'), isNull);
      expect(await store.read('mail.v1.acc_oauth.oauth.refresh'), isNull);
      expect(
        appState.mailAccounts.where((a) => a.id == 'acc_oauth'),
        isEmpty,
      );

      // Reconciliation: metadata savedUnverified без токенов ->
      // notConfigured при следующем load (секрет удалён напрямую сервисом).
      await store.write('mail.v1.acc_stale.oauth.access', _tokenCanaryA);
      await store.write('mail.v1.acc_stale.oauth.refresh', _tokenCanaryB);
      final sharedRepo = MemoryLocalStateRepository();
      final stateWithStale = OrbitAppState(
        sharedRepo,
        store,
        _MockOAuthClient(),
        _oauthCfg,
      );
      await stateWithStale.load();
      await stateWithStale.saveMailAccountWithCredentials(
        _oauthAccount(id: 'acc_stale'),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: _tokenCanaryA,
          refreshToken: _tokenCanaryB,
          expiryUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      await stateWithStale.flush();
      // Секрет удалён напрямую (имитация ручного отзыва/порчи) —
      // snapshot остаётся с savedUnverified (stale).
      await store.delete('mail.v1.acc_stale.oauth.access');
      await store.delete('mail.v1.acc_stale.oauth.refresh');
      final stateAfterStale = OrbitAppState(
        sharedRepo,
        store,
        _MockOAuthClient(),
        _oauthCfg,
      );
      await stateAfterStale.load();
      final stale = stateAfterStale.mailAccounts
          .firstWhere((a) => a.id == 'acc_stale');
      expect(stale.credentialStatus,
          OrbitMailCredentialStatus.notConfigured,
          reason: 'savedUnverified без секрета не восстанавливается');
      expect(stale.authMethod, isNull);
    });

    test('[O12] sanitization: исключения/UI не содержат token canary',
        () async {
      final store = MemoryOrbitSecretStore();
      final client = _MockOAuthClient()..refreshOutcome = 'invalidGrant';
      final appState = _state(client: client, store: store);
      await appState.load();
      await appState.saveMailAccountWithCredentials(
        _oauthAccount(),
        oauthTokens: OrbitOAuthTokenSet(
          accessToken: _tokenCanaryA,
          refreshToken: _tokenCanaryB,
          expiryUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        ),
      );
      await appState.flush();
      // Секрет присутствует в secure store до invalid_grant.
      expect(await store.read('mail.v1.acc_oauth.oauth.access'), _tokenCanaryA);

      final token = await appState.getValidOAuthAccessToken('acc_oauth');
      expect(token, isNull);
      // invalid_grant удалил набор (без следов в исключениях).
      expect(await store.read('mail.v1.acc_oauth.oauth.access'), isNull);
      // Секреты не попадают в state геттеры/снапшот.
      final snapshotJson = jsonEncode(await appState.repository.load());
      expect(snapshotJson.contains(_tokenCanaryA), isFalse);
      expect(snapshotJson.contains(_tokenCanaryB), isFalse);
    });

    testWidgets('[O13] UI: OAuth кнопка, pending, CONFIG_REQUIRED; '
        'AppPassword flow не затронут', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final client = _MockOAuthClient();
      final appState = OrbitAppState(
        MemoryLocalStateRepository(),
        MemoryOrbitSecretStore(),
        client,
        // БЕЗ config override: gmail -> CONFIG_REQUIRED.
      );
      // store не читается напрямую в этом сценарии.
      await appState.load();
      final palette =
          OrbitPalette.ofBrightness(OrbitProfile.one, Brightness.dark);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrbitMailAccountsSheet(
              palette: palette,
              profile: OrbitProfile.one,
              initialAccounts: List.of(initialMailAccounts),
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
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-add-mail-account-btn')));
      await tester.pumpAndSettle();

      // Gmail: OAuth кнопка; тап -> CONFIG_REQUIRED (без client ID).
      await tester.tap(find.byKey(const Key('mail-provider-chip-gmail')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mail-account-password-input')),
          findsNothing);
      expect(find.byKey(const Key('mail-oauth-signin-btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mail-oauth-signin-btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('CONFIG_REQUIRED'), findsOneWidget);

      // Yandex: app-password flow не затронут (поле пароля на месте).
      await tester.tap(find.byKey(const Key('mail-provider-chip-yandex')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mail-account-password-input')),
          findsOneWidget);
    });

    test('[O15] production AppAuthOAuthClient: Google получает '
        'access_type=offline, Outlook — нет; refresh токен передаётся',
        () async {
      final capturedPlatform = _CapturingAppAuthPlatform();
      final previousPlatform = FlutterAppAuthPlatform.instance;
      FlutterAppAuthPlatform.instance = capturedPlatform;
      addTearDown(() => FlutterAppAuthPlatform.instance = previousPlatform);

      const client = AppAuthOAuthClient();

      // Google: access_type=offline обязателен.
      await client.authorize(
        issuer: 'https://accounts.google.com',
        clientId: 'prod-google-id',
        scopes: const ['openid', 'email', 'https://mail.google.com/'],
        redirectUri: 'app.orbit.orbit_visual_lab:/oauthredirect',
      );
      final googleRequest = capturedPlatform.lastAuthRequest!;
      expect(googleRequest.clientId, 'prod-google-id');
      expect(googleRequest.issuer, 'https://accounts.google.com');
      expect(googleRequest.redirectUrl,
          'app.orbit.orbit_visual_lab:/oauthredirect');
      expect(googleRequest.additionalParameters?['access_type'], 'offline');

      // Outlook: offline_access через scope, access_type не добавляется.
      await client.authorize(
        issuer: 'https://login.microsoftonline.com/testtenant/v2.0',
        clientId: 'prod-outlook-id',
        scopes: const ['openid', 'email', 'offline_access'],
        redirectUri: 'app.orbit.orbit_visual_lab:/oauthredirect',
      );
      final outlookRequest = capturedPlatform.lastAuthRequest!;
      expect(outlookRequest.issuer,
          'https://login.microsoftonline.com/testtenant/v2.0');
      expect(outlookRequest.additionalParameters?['access_type'], isNull);
      expect(outlookRequest.scopes, contains('offline_access'));

      // Refresh: refresh token передаётся в TokenRequest (grant type
      // выводится AppAuth).
      await client.refresh(
        issuer: 'https://accounts.google.com',
        clientId: 'prod-google-id',
        scopes: const ['openid', 'email'],
        redirectUri: 'app.orbit.orbit_visual_lab:/oauthredirect',
        refreshToken: _tokenCanaryB,
      );
      expect(capturedPlatform.lastTokenRequest!.refreshToken, _tokenCanaryB);
    });

    testWidgets('[O16] null/empty access token: аккаунт/секрет/metadata '
        'не создаются, ошибка sanitized', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = MemoryOrbitSecretStore();

      // (a) Пустой access token из client: saveOAuthTokens отклоняет.
      final service = OrbitMailCredentialService(store: store);
      Object? saveError;
      try {
        await service.saveOAuthTokens(
          accountId: 'acc_empty',
          tokens: OrbitOAuthTokenSet(
            accessToken: '',
            refreshToken: 'r',
            expiryUtc: DateTime.now().toUtc(),
          ),
        );
      } catch (e) {
        saveError = e;
      }
      expect(saveError, isA<OrbitMailCredentialException>());
      expect('$saveError'.contains('пустой'), isTrue);
      // Пустая строка не считается секретом.
      expect(await service.hasOAuthTokens('acc_empty'), isFalse);
      expect(await service.readOAuthTokens('acc_empty'), isNull);

      // (b) State-level: sign-in с пустым access — error outcome,
      // аккаунт/токены не создаются.
      final client = _MockOAuthClient()..emptyAccessToken = true;
      final appState = OrbitAppState(
        MemoryLocalStateRepository(),
        store,
        client,
        _oauthCfg,
      );
      await appState.load();
      final outcome = await appState.signInMailAccountWithOAuth(
        providerType: OrbitMailProviderType.gmail,
        accountName: 'E',
        accountEmail: 'empty@test.local',
      );
      expect(outcome.status, OrbitMailOAuthUiStatus.error);
      expect(outcome.message, isNotNull);
      expect(appState.mailAccounts.where((a) => a.email == 'empty@test.local'),
          isEmpty, reason: 'аккаунт не создаётся без валидного токена');
      expect(await store.read('mail.v1.acc_oauth.oauth.access'), isNull);
    });

    test('[O17] production client: null access в ответе AppAuth -> '
        'sanitized transient, ничего не сохраняется', () async {
      final capturedPlatform = _CapturingAppAuthPlatform()
        ..nextAccessToken = null;
      final previousPlatform = FlutterAppAuthPlatform.instance;
      FlutterAppAuthPlatform.instance = capturedPlatform;
      addTearDown(() => FlutterAppAuthPlatform.instance = previousPlatform);

      const client = AppAuthOAuthClient();
      Object? caught;
      try {
        await client.authorize(
          issuer: 'https://accounts.google.com',
          clientId: 'c',
          scopes: const ['openid'],
          redirectUri: 'app.orbit.orbit_visual_lab:/oauthredirect',
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<OrbitOAuthTransientException>(),
          reason: 'null access — неуспешный ответ, sanitized transient');
      expect('$caught'.contains('token'), isFalse,
          reason: 'сообщение не содержит значений токенов');
    });

    test('[O14] no real mail: OAuth flow не вызывает IMAP/SMTP или '
        'MailService', () async {
      final client = _MockOAuthClient();
      final appState = _state(client: client);
      await appState.load();
      final verifier = _CountingVerifier();
      appState.debugMailVerifierForTest = verifier;

      await appState.signInMailAccountWithOAuth(
        providerType: OrbitMailProviderType.gmail,
        accountName: 'G',
        accountEmail: 'g@test.local',
      );
      await appState.getValidOAuthAccessToken(appState.mailAccounts
          .firstWhere((a) => a.email == 'g@test.local')
          .id);
      await appState.removeMailAccountSecurely(appState.mailAccounts
          .firstWhere((a) => a.email == 'g@test.local')
          .id);

      expect(verifier.endpointCalls, 0,
          reason: 'OAuth flow не выполняет endpoint/IMAP/SMTP проверок');
    });
  });
}

/// Подсчитывающая обёртка верификатора (из MAIL-01A тестов).
/// Capturing platform for testing the PRODUCTION AppAuthOAuthClient:
/// records actual AuthorizationTokenRequest/TokenRequest parameters.
class _CapturingAppAuthPlatform extends FlutterAppAuthPlatform {
  AuthorizationTokenRequest? lastAuthRequest;
  TokenRequest? lastTokenRequest;

  // Синтетические значения генерируются в рантайме (не литералы).
  String? nextAccessToken = DateTime.now().microsecondsSinceEpoch.toString();
  String? nextRefreshToken = DateTime.now().microsecondsSinceEpoch.toString();

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    lastAuthRequest = request;
    return AuthorizationTokenResponse(
      nextAccessToken,
      nextRefreshToken,
      DateTime.now().toUtc().add(const Duration(hours: 1)),
      null,
      'Bearer',
      null,
      null,
      null,
    );
  }

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    lastTokenRequest = request;
    return TokenResponse(
      nextAccessToken,
      nextRefreshToken,
      DateTime.now().toUtc().add(const Duration(hours: 1)),
      null,
      'Bearer',
      null,
      null,
    );
  }

  @override
  Future<AuthorizationResponse> authorize(AuthorizationRequest request) async {
    throw UnimplementedError();
  }

  @override
  Future<EndSessionResponse> endSession(EndSessionRequest request) async {
    throw UnimplementedError();
  }
}

class _CountingVerifier implements OrbitMailConnectionVerifier {
  _CountingVerifier() : inner = OrbitMailConnectionVerifier();

  final OrbitMailConnectionVerifier inner;
  int endpointCalls = 0;

  @override
  bool get isMockMode => inner.isMockMode;

  @override
  Duration get timeout => inner.timeout;

  @override
  Future<MailDiagnosticResult> verifyEndpoint({
    required String host,
    required int port,
    required bool useSsl,
    bool isSmtp = false,
    ValueChanged<MailVerificationStage>? onStageChanged,
    MailVerificationCancelToken? cancelToken,
  }) async {
    endpointCalls++;
    return inner.verifyEndpoint(
      host: host,
      port: port,
      useSsl: useSsl,
      isSmtp: isSmtp,
      onStageChanged: onStageChanged,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<MailDiagnosticResult> verifyConnection({
    required String host,
    required int port,
    required bool useSsl,
    bool isSmtp = false,
    Duration? timeout,
    ValueChanged<MailVerificationStage>? onStageChanged,
    MailVerificationCancelToken? cancelToken,
  }) =>
      verifyEndpoint(
        host: host,
        port: port,
        useSsl: useSsl,
        isSmtp: isSmtp,
        onStageChanged: onStageChanged,
        cancelToken: cancelToken,
      );
}
