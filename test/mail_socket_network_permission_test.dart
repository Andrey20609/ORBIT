import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';

void main() {
  group('Release Android Internet Permission & Real Socket Verification', () {
    test('1. AndroidManifest.xml (main) содержит разрешение android.permission.INTERNET', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();
      expect(
        content,
        contains('<uses-permission android:name="android.permission.INTERNET" />'),
        reason: 'Main AndroidManifest.xml must include INTERNET permission for release APK',
      );
      expect(
        content,
        contains('<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />'),
        reason: 'Main AndroidManifest.xml must include ACCESS_NETWORK_STATE permission',
      );
    });

    test('2. OrbitMailConnectionVerifier выполняет 4-фазную диагностику сокетов', () async {
      final verifier = OrbitMailConnectionVerifier(isMockMode: true);
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
  });
}
