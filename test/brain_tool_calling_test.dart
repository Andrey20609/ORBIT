import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/services/brain/brain_tool_caller.dart';

void main() {
  late MemoryOrbitDatabase db;
  late OrbitDataEngine dataEngine;

  setUp(() async {
    db = MemoryOrbitDatabase();
    dataEngine = OrbitDataEngine(db);
    await dataEngine.initialize();
  });

  group('[BRN-02] Brain Tool Calling & Action Approval Safety', () {
    test('unapproved action proposal rejects execution without mutating database', () async {
      const proposal = BrainActionProposal(
        id: 'prop-1',
        toolName: 'createTask',
        arguments: {
          'title': 'Несогласованная задача',
          'project': 'AI',
        },
        isApproved: false,
      );

      expect(
        () => proposal.execute(dataEngine),
        throwsA(isA<StateError>()),
      );

      final tasks = await dataEngine.getTasks();
      expect(tasks, isEmpty);
    });

    test('approved action proposal executes mutation successfully', () async {
      final proposal = const BrainActionProposal(
        id: 'prop-2',
        toolName: 'createTask',
        arguments: {
          'title': 'Согласованная задача от ИИ',
          'project': 'Стратегия',
          'due': 'Завтра',
        },
        isApproved: false,
      ).copyWith(isApproved: true);

      final success = await proposal.execute(dataEngine);
      expect(success, isTrue);

      final tasks = await dataEngine.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Согласованная задача от ИИ');
      expect(tasks.first.project, 'Стратегия');
    });

    test('executes approved scheduleMeeting proposal', () async {
      final meetingProposal = const BrainActionProposal(
        id: 'prop-meeting-1',
        toolName: 'scheduleMeeting',
        arguments: {
          'title': 'Консультация с архитектором',
          'start': '2026-11-15T15:00:00.000Z',
          'location': 'Главный офис',
        },
        isApproved: true,
      );

      final result = await meetingProposal.execute(dataEngine);
      expect(result, isTrue);

      final events = await dataEngine.getEvents();
      expect(events.length, 1);
      expect(events.first.title, 'Консультация с архитектором');
      expect(events.first.location, 'Главный офис');
    });
  });
}
