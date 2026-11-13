import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';

void main() {
  group('OrbitMailConnectionVerifier (4-Stage Diagnostic Tests)', () {
    final verifier = OrbitMailConnectionVerifier(isMockMode: true);

    test('1. Успешная 4-этапная верификация валидного IMAP/SSL сервера', () async {
      final stages = <MailVerificationStage>[];
      final result = await verifier.verifyEndpoint(
        host: 'imap.yandex.ru',
        port: 993,
        useSsl: true,
        onStageChanged: stages.add,
      );

      expect(result.isSuccess, isTrue);
      expect(result.latencyMs, greaterThan(0));
      expect(result.serverBanner, contains('* OK'));
      expect(
        stages,
        containsAllInOrder(<MailVerificationStage>[
          MailVerificationStage.resolvingDns,
          MailVerificationStage.connectingTcp,
          MailVerificationStage.performingTlsHandshake,
          MailVerificationStage.readingGreeting,
          MailVerificationStage.success,
        ]),
      );
    });

    test('2. Ошибка DNS-резолвинга возвращает стадию resolvingDns и рекомендацию', () async {
      final result = await verifier.verifyEndpoint(
        host: 'invalid-host-without-dot',
        port: 993,
        useSsl: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failedStage, MailVerificationStage.resolvingDns);
      expect(result.recommendation, contains('разрешить имя хоста'));
    });

    test('3. Таймаут TCP-порта возвращает стадию connectingTcp и рекомендацию по портам 993/465', () async {
      final result = await verifier.verifyEndpoint(
        host: 'timeout.mail.ru',
        port: 9999,
        useSsl: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failedStage, MailVerificationStage.connectingTcp);
      expect(result.recommendation, contains('993/465'));
    });

    test('4. Ошибка TLS/SSL рукопожатия возвращает стадию performingTlsHandshake', () async {
      final result = await verifier.verifyEndpoint(
        host: 'badssl.example.com',
        port: 143,
        useSsl: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failedStage, MailVerificationStage.performingTlsHandshake);
      expect(result.recommendation, contains('STARTTLS'));
    });

    test('5. Сериализация и десериализация OrbitMailAccount сохраняет пинг и статус', () {
      const account = OrbitMailAccount(
        id: 'acc_1',
        name: 'Yandex Work',
        email: 'dev@yandex.ru',
        providerType: OrbitMailProviderType.yandex,
        incomingHost: 'imap.yandex.ru',
        incomingPort: 993,
        outgoingHost: 'smtp.yandex.ru',
        outgoingPort: 465,
        lastLatencyMs: 31,
        isActive: true,
        status: OrbitMailAccountStatus.verified,
      );

      final restored = OrbitMailAccount.fromJson(account.toJson());
      expect(restored.id, 'acc_1');
      expect(restored.lastLatencyMs, 31);
      expect(restored.status, OrbitMailAccountStatus.verified);
      expect(restored.isActive, isTrue);
    });
  });
}
