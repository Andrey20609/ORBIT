import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/models/email_record.dart';
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

  group('[MAIL-02] MailService Sync', () {
    test('fetches remote emails and persists them into local SQLite database', () async {
      final remoteEmail1 = EmailRecord(
        id: 'remote-1',
        workspaceId: 'workspace-work',
        folder: 'inbox',
        sender: 'Maria Sokolova',
        recipient: 'alexey@orbit.app',
        subject: 'Weekly Review',
        preview: 'Attached weekly plan',
        body: 'Hello Alexey! Here is the updated plan.',
        timestamp: DateTime.utc(2026, 11, 11, 9, 30),
      );

      final remoteEmail2 = EmailRecord(
        id: 'remote-2',
        workspaceId: 'workspace-work',
        folder: 'inbox',
        sender: 'Figma',
        recipient: 'alexey@orbit.app',
        subject: 'New Comments',
        preview: '3 new comments on ORBIT design',
        body: 'Team left feedback on the canvas.',
        timestamp: DateTime.utc(2026, 11, 11, 10, 15),
      );

      transport.addRemoteEmail(remoteEmail1);
      transport.addRemoteEmail(remoteEmail2);

      final syncedCount = await mailService.syncFolder(
        folder: 'inbox',
        workspaceId: 'workspace-work',
      );
      expect(syncedCount, 2);

      final cachedEmails = await dataEngine.getEmails(
        workspaceId: 'workspace-work',
        folder: 'inbox',
      );
      expect(cachedEmails.length, 2);
      expect(cachedEmails.map((e) => e.id), containsAll(['remote-1', 'remote-2']));
    });

    test('updates read status locally in SQLite without network call', () async {
      final email = EmailRecord(
        id: 'local-msg-1',
        workspaceId: 'workspace-work',
        folder: 'inbox',
        sender: 'Booking.com',
        recipient: 'alexey@orbit.app',
        subject: 'Reservation Confirmed',
        preview: 'Hotel in Tynda confirmed',
        body: 'Check-in on Nov 12.',
        timestamp: DateTime.utc(2026, 11, 11, 8, 0),
        isRead: false,
      );

      await dataEngine.saveEmail(email);
      var list = await dataEngine.getEmails(folder: 'inbox');
      expect(list.first.isRead, isFalse);

      await dataEngine.setEmailRead('local-msg-1', true);
      list = await dataEngine.getEmails(folder: 'inbox');
      expect(list.first.isRead, isTrue);
    });
  });
}
