import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';
import 'package:orbit_visual_lab/state/app_state.dart';

void main() {
  // MAIL-01A: secure-flow тесты требуют test binding (platform channel).
  TestWidgetsFlutterBinding.ensureInitialized();
  group('OrbitMailConnectionVerifier', () {
    final verifier = OrbitMailConnectionVerifier();

    test('successful connection verification via simulator', () async {
      final stages = <MailVerificationStage>[];
      final result = await verifier.verifyConnection(
        host: 'imap.orbit.local',
        port: 993,
        useSsl: true,
        onStageChanged: stages.add,
      );

      expect(result.isSuccess, isTrue);
      expect(result.failedStage, MailVerificationStage.success);
      expect(result.latencyMs, greaterThan(0));
      expect(result.serverBanner, contains('IMAP4rev1'));
      expect(result.isSecure, isTrue);
      expect(stages, containsAllInOrder([
        MailVerificationStage.resolvingDns,
        MailVerificationStage.connectingTcp,
        MailVerificationStage.performingTlsHandshake,
        MailVerificationStage.readingGreeting,
        MailVerificationStage.success,
      ]));
    });

    test('DNS failure when host cannot be resolved', () async {
      final stages = <MailVerificationStage>[];
      final result = await verifier.verifyConnection(
        host: 'invalid.host.test',
        port: 993,
        useSsl: true,
        onStageChanged: stages.add,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failedStage, MailVerificationStage.resolvingDns);
      expect(result.errorMessage, contains('DNS'));
    });

    test('TCP connection refused failure on closed port', () async {
      final stages = <MailVerificationStage>[];
      final result = await verifier.verifyConnection(
        host: 'imap.orbit.local',
        port: 9999,
        useSsl: true,
        onStageChanged: stages.add,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failedStage, MailVerificationStage.connectingTcp);
      expect(result.errorMessage, contains('недоступен'));
    });

    test('invalid port boundaries are rejected immediately', () async {
      final result = await verifier.verifyConnection(
        host: 'imap.orbit.local',
        port: 70000,
        useSsl: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Некорректный номер'));
    });
  });

  group('OrbitAppState Mail Accounts Management and Persistence', () {
    test('default state has active verified demo account', () async {
      final appState = OrbitAppState();
      await appState.load();

      expect(appState.mailAccounts, isNotEmpty);
      final active = appState.activeMailAccount;
      expect(active.id, 'demo-default');
      expect(active.isActive, isTrue);
      expect(active.status, OrbitMailAccountStatus.verified);
    });

    test('addMailAccount sets new active account and persists to repository', () async {
      final repo = MemoryLocalStateRepository();
      final appState = OrbitAppState(repo);
      await appState.load();

      const newAccount = OrbitMailAccount(
        id: 'acc-work-yandex',
        name: 'Рабочий Яндекс',
        email: 'alexey.work@yandex.ru',
        provider: 'yandex',
        incomingHost: 'imap.yandex.ru',
        incomingPort: 993,
        useIncomingSsl: true,
        outgoingHost: 'smtp.yandex.ru',
        outgoingPort: 465,
        useOutgoingSsl: true,
        isActive: true,
        status: OrbitMailAccountStatus.verified,
        lastLatencyMs: 34,
      );

      appState.addMailAccount(newAccount);
      await appState.flush();

      expect(appState.mailAccounts.length, 2);
      expect(appState.activeMailAccount.id, 'acc-work-yandex');
      expect(appState.mailAccounts.firstWhere((a) => a.id == 'demo-default').isActive, isFalse);

      // Verify persistence by loading into a fresh OrbitAppState
      final restoredState = OrbitAppState(repo);
      await restoredState.load();

      expect(restoredState.mailAccounts.length, 2);
      final restoredActive = restoredState.activeMailAccount;
      expect(restoredActive.id, 'acc-work-yandex');
      expect(restoredActive.email, 'alexey.work@yandex.ru');
      expect(restoredActive.lastLatencyMs, 34);
      expect(restoredActive.status, OrbitMailAccountStatus.verified);
    });

    test('setActiveMailAccount switches active account', () async {
      final appState = OrbitAppState();
      await appState.load();

      const customAcc = OrbitMailAccount(
        id: 'acc-custom',
        name: 'Личный',
        email: 'user@custom.mail',
        isActive: false,
      );

      appState.addMailAccount(customAcc);
      expect(appState.activeMailAccount.id, 'demo-default');

      appState.setActiveMailAccount('acc-custom');
      expect(appState.activeMailAccount.id, 'acc-custom');
      expect(appState.mailAccounts.firstWhere((a) => a.id == 'demo-default').isActive, isFalse);
    });

    test('removeMailAccount removes account and keeps another active', () async {
      final appState = OrbitAppState();
      await appState.load();

      const acc2 = OrbitMailAccount(
        id: 'acc-to-delete',
        name: 'Удаляемый',
        email: 'delete@test.mail',
        isActive: true,
      );
      appState.addMailAccount(acc2);
      expect(appState.activeMailAccount.id, 'acc-to-delete');

      // MAIL-01A: metadata-only bypass удалён — secure flow.
      await appState.removeMailAccountSecurely('acc-to-delete');
      expect(appState.mailAccounts.any((a) => a.id == 'acc-to-delete'), isFalse);
      expect(appState.activeMailAccount.id, 'demo-default');
    });
  });
}
