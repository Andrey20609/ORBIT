import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/services/mail/mail_models.dart';
import 'package:orbit_visual_lab/services/mail/mail_service.dart';
import 'package:orbit_visual_lab/services/mail/mail_transport.dart';

void main() {
  late MemoryOrbitDatabase db;
  late OrbitDataEngine dataEngine;
  late SimulatedMailTransport transport;
  late MailService mailService;

  setUp(() async {
    db = MemoryOrbitDatabase();
    dataEngine = OrbitDataEngine(db);
    await dataEngine.initialize();

    transport = SimulatedMailTransport();
    mailService = MailService(dataEngine: dataEngine, transport: transport);
  });

  group('[MAIL-02] Mail Offline Queue and Resilient Delivery', () {
    test('queues outgoing email when offline and preserves it for retry', () async {
      // Set device offline
      transport.isOnline = false;

      final outgoing = await mailService.sendEmail(
        to: 'team@company.ru',
        subject: 'Обновления по проекту',
        body: 'Привет, команда! Мы завершили дизайн.',
      );

      // Should be queued, not sent yet
      expect(mailService.queue.pendingCount, 1);
      final queuedItem = mailService.queue.queue.first;
      expect(queuedItem.id, outgoing.id);
      expect(queuedItem.status, MailSendStatus.queued);
      expect(queuedItem.retryCount, 1);
      expect(queuedItem.lastError, contains('network offline'));
      expect(transport.sentDeliveries, isEmpty);

      // Sent folder in local SQLite should not have it yet
      var sentEmails = await dataEngine.getEmails(folder: 'sent');
      expect(sentEmails, isEmpty);

      // Network comes back online!
      transport.isOnline = true;

      // Process the queue
      final flushedCount = await mailService.flushOfflineQueue();
      expect(flushedCount, 1);
      expect(mailService.queue.pendingCount, 0);
      expect(mailService.queue.queue.first.status, MailSendStatus.sent);
      expect(transport.sentDeliveries.length, 1);
      expect(transport.sentDeliveries.first.to, 'team@company.ru');

      // Now it's recorded in the local SQLite sent folder
      sentEmails = await dataEngine.getEmails(folder: 'sent');
      expect(sentEmails.length, 1);
      expect(sentEmails.first.subject, 'Обновления по проекту');
      expect(sentEmails.first.recipient, 'team@company.ru');
    });

    test('immediate delivery when online without waiting in queue', () async {
      transport.isOnline = true;

      final outgoing = await mailService.sendEmail(
        to: 'manager@orbit.app',
        subject: 'Отчёт готов',
        body: 'Все задачи на сегодня выполнены.',
      );

      expect(mailService.queue.pendingCount, 0);
      expect(mailService.queue.queue.first.status, MailSendStatus.sent);
      expect(transport.sentDeliveries.length, 1);

      final sentEmails = await dataEngine.getEmails(folder: 'sent');
      expect(sentEmails.length, 1);
      expect(sentEmails.first.id, outgoing.id);
    });
  });
}
