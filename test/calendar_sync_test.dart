import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/models/event_record.dart';
import 'package:orbit_visual_lab/services/calendar/calendar_service.dart';
import 'package:orbit_visual_lab/services/calendar/calendar_transport.dart';

void main() {
  late MemoryOrbitDatabase db;
  late OrbitDataEngine dataEngine;
  late SimulatedCalendarTransport transport;
  late CalendarService service;

  setUp(() async {
    db = MemoryOrbitDatabase();
    dataEngine = OrbitDataEngine(db);
    await dataEngine.initialize();

    transport = SimulatedCalendarTransport();
    service = CalendarService(dataEngine: dataEngine, transport: transport);
  });

  group('[CAL-01] Calendar Sync and Management', () {
    test('syncs events from remote transport into local SQLite database', () async {
      final remoteEvent = EventRecord(
        id: 'remote-cal-1',
        workspaceId: 'workspace-work',
        title: 'Совет директоров',
        description: 'Годовой отчёт',
        startTime: DateTime.utc(2026, 11, 15, 11, 0),
        endTime: DateTime.utc(2026, 11, 15, 13, 0),
        location: 'Главный конференц-зал',
      );
      transport.addRemoteEvent(remoteEvent);

      final count = await service.syncRange(
        start: DateTime.utc(2026, 11, 1),
        end: DateTime.utc(2026, 11, 30),
      );
      expect(count, 1);

      final localEvents = await dataEngine.getEvents();
      expect(localEvents.length, 1);
      expect(localEvents.first.title, 'Совет директоров');
    });

    test('creates meeting and pushes to remote calendar', () async {
      final event = await service.createEvent(
        title: 'Синхронизация проекта',
        startTime: DateTime.utc(2026, 11, 12, 14, 0),
        endTime: DateTime.utc(2026, 11, 12, 15, 0),
        location: 'Teams',
        participants: ['alexey@orbit.app', 'maria@orbit.app'],
      );

      expect(event.title, 'Синхронизация проекта');

      // Local DB
      final local = await service.getEventsForDay(DateTime.utc(2026, 11, 12));
      expect(local.length, 1);
      expect(local.first.participants, contains('maria@orbit.app'));

      // Remote transport
      final remote = await transport.fetchEvents(
        start: DateTime.utc(2026, 11, 12),
        end: DateTime.utc(2026, 11, 13),
      );
      expect(remote.length, 1);
      expect(remote.first.id, event.id);

      // Deletion
      await service.deleteEvent(event.id);
      expect(await service.getEventsForDay(DateTime.utc(2026, 11, 12)), isEmpty);
      expect(
        await transport.fetchEvents(
          start: DateTime.utc(2026, 11, 12),
          end: DateTime.utc(2026, 11, 13),
        ),
        isEmpty,
      );
    });
  });
}
