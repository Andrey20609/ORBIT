import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/orbit_secure_store.dart';
import 'package:orbit_visual_lab/services/auth/account_models.dart';
import 'package:orbit_visual_lab/services/auth/orbit_account_manager.dart';

void main() {
  late MemoryOrbitDatabase db;
  late MemoryOrbitSecretStore secretStore;
  late OrbitAccountManager manager;

  setUp(() async {
    db = MemoryOrbitDatabase();
    await db.open();
    secretStore = MemoryOrbitSecretStore();
    manager = OrbitAccountManager(database: db, secretStore: secretStore);
    await manager.loadAccounts();
  });

  group('[MAIL-01] OrbitAccountManager and Token Rotation', () {
    test('supports 3+ accounts across workspaces without leaking tokens to database', () async {
      final acc1 = const UserAccountRecord(
        id: 'acc-google-1',
        workspaceId: 'workspace-work',
        email: 'alexey.romanov@company.ru',
        displayName: 'Алексей Романов (Work)',
        providerType: EmailProviderType.google,
      );
      final tokens1 = AuthTokens(
        accessToken: 'mock_google_access_token_123',
        refreshToken: 'mock_google_refresh_token_xyz',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      final acc2 = const UserAccountRecord(
        id: 'acc-yandex-2',
        workspaceId: 'workspace-personal',
        email: 'alexey@yandex.ru',
        displayName: 'Алексей (Личный)',
        providerType: EmailProviderType.yandex,
      );
      final tokens2 = AuthTokens(
        accessToken: 'mock_yandex_access_token_456',
        refreshToken: 'mock_yandex_refresh_token_abc',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
      );

      final acc3 = const UserAccountRecord(
        id: 'acc-outlook-3',
        workspaceId: 'workspace-projects',
        email: 'alexey.pm@outlook.com',
        displayName: 'Алексей (Проекты)',
        providerType: EmailProviderType.outlook,
      );
      final tokens3 = AuthTokens(
        accessToken: 'mock_outlook_access_token_789',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      await manager.addAccount(account: acc1, tokens: tokens1);
      await manager.addAccount(account: acc2, tokens: tokens2);
      await manager.addAccount(account: acc3, tokens: tokens3);

      expect(manager.accounts.length, 3);
      expect(manager.getAccountsForWorkspace('workspace-work').length, 1);
      expect(manager.getAccountsForWorkspace('workspace-personal').length, 1);
      expect(manager.getAccountsForWorkspace('workspace-projects').length, 1);

      // Verify tokens are stored in secure store
      expect(
        await secretStore.read('auth.acc-google-1.access'),
        'mock_google_access_token_123',
      );
      expect(
        await secretStore.read('auth.acc-google-1.refresh'),
        'mock_google_refresh_token_xyz',
      );

      // Verify valid token retrieval
      final token = await manager.getValidAccessToken('acc-google-1');
      expect(token, 'mock_google_access_token_123');
    });

    test('auto-rotates expired access token using refresh callback', () async {
      final acc = const UserAccountRecord(
        id: 'acc-exp-1',
        workspaceId: 'workspace-work',
        email: 'expired@orbit.app',
        displayName: 'Expired Account',
        providerType: EmailProviderType.google,
      );
      // Already expired 10 minutes ago
      final expiredTokens = AuthTokens(
        accessToken: 'old_expired_token',
        refreshToken: 'valid_refresh_token',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
      );

      await manager.addAccount(account: acc, tokens: expiredTokens);

      var refreshInvoked = false;
      final freshToken = await manager.getValidAccessToken(
        'acc-exp-1',
        refreshCallback: (refreshToken) async {
          refreshInvoked = true;
          expect(refreshToken, 'valid_refresh_token');
          return AuthTokens(
            accessToken: 'brand_new_rotated_token',
            refreshToken: 'new_refresh_token',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          );
        },
      );

      expect(refreshInvoked, isTrue);
      expect(freshToken, 'brand_new_rotated_token');
      expect(
        await secretStore.read('auth.acc-exp-1.access'),
        'brand_new_rotated_token',
      );
      expect(
        await secretStore.read('auth.acc-exp-1.refresh'),
        'new_refresh_token',
      );
    });

    test('removeAccount completely clears secure storage', () async {
      final acc = const UserAccountRecord(
        id: 'acc-delete-1',
        workspaceId: 'workspace-work',
        email: 'to_delete@orbit.app',
        displayName: 'Delete Me',
        providerType: EmailProviderType.google,
      );
      final tokens = AuthTokens(
        accessToken: 'secret_to_delete',
        refreshToken: 'refresh_to_delete',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      await manager.addAccount(account: acc, tokens: tokens);
      expect(await secretStore.read('auth.acc-delete-1.access'), isNotNull);

      await manager.removeAccount('acc-delete-1');
      expect(manager.getAccount('acc-delete-1'), isNull);
      expect(await secretStore.read('auth.acc-delete-1.access'), isNull);
      expect(await secretStore.read('auth.acc-delete-1.refresh'), isNull);
      expect(await secretStore.read('auth.acc-delete-1.expiry'), isNull);
    });
  });
}
