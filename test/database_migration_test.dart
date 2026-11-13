import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/database/orbit_local_state_migrator.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';

void main() {
  group('[DATA-01] OrbitLocalStateMigrator', () {
    test('migrates legacy JSON tasks and events with 100% preservation', () async {
      final legacyJson = <String, Object?>{
        'schemaVersion': 1,
        'draftTo': 'test@example.com',
        'draftSubject': 'Legacy Subject',
        'tasks': [
          {
            'id': 'legacy-task-1',
            'title': 'Согласовать бюджет',
            'project': 'Финансы',
            'due': '15 нояб.',
            'done': false,
            'priority': 2,
          },
          {
            'id': 'legacy-task-2',
            'title': 'Обновить сертификаты',
            'project': 'Инфраструктура',
            'due': 'Завтра',
            'done': true,
            'priority': 0,
          },
        ],
        'events': [
          {
            'id': 'legacy-event-1',
            'title': 'Ревью архитектуры',
            'location': 'Конференц-зал 2',
            'start': '2026-11-12T14:00:00.000Z',
            'end': '2026-11-12T15:00:00.000Z',
          },
        ],
      };

      final legacyRepo = MemoryLocalStateRepository(legacyJson);
      final db = MemoryOrbitDatabase();
      final dataEngine = OrbitDataEngine(db);
      await dataEngine.initialize();

      final migrator = OrbitLocalStateMigrator(
        repository: legacyRepo,
        dataEngine: dataEngine,
      );

      final result = await migrator.migrateIfNeeded();

      expect(result.success, isTrue);
      expect(result.tasksMigrated, 2);
      expect(result.eventsMigrated, 1);

      // Verify tasks in dataEngine
      final tasks = await dataEngine.getTasks();
      expect(tasks.length, 2);
      final task1 = tasks.firstWhere((t) => t.id == 'legacy-task-1');
      expect(task1.title, 'Согласовать бюджет');
      expect(task1.project, 'Финансы');
      expect(task1.isDone, isFalse);
      expect(task1.priority, 2);

      final task2 = tasks.firstWhere((t) => t.id == 'legacy-task-2');
      expect(task2.isDone, isTrue);

      // Verify event in dataEngine
      final events = await dataEngine.getEvents();
      expect(events.length, 1);
      expect(events.first.title, 'Ревью архитектуры');
      expect(events.first.location, 'Конференц-зал 2');
    });

    test('handles empty legacy state gracefully', () async {
      final legacyRepo = MemoryLocalStateRepository({});
      final db = MemoryOrbitDatabase();
      final dataEngine = OrbitDataEngine(db);
      await dataEngine.initialize();

      final migrator = OrbitLocalStateMigrator(
        repository: legacyRepo,
        dataEngine: dataEngine,
      );

      final result = await migrator.migrateIfNeeded();
      expect(result.success, isTrue);
      expect(result.tasksMigrated, 0);
      expect(result.eventsMigrated, 0);
    });
  });
}
