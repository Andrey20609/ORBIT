import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/models/task_record.dart';

void main() {
  late MemoryOrbitDatabase db;
  late OrbitDataEngine engine;

  setUp(() async {
    db = MemoryOrbitDatabase();
    engine = OrbitDataEngine(db);
    await engine.initialize();
  });

  group('[DATA-02] Workspace Isolation', () {
    test('tasks created in work workspace do not leak into personal or projects', () async {
      final workTask = TaskRecord(
        id: 'task-work-1',
        workspaceId: 'workspace-work',
        title: 'Подготовить квартальный отчёт',
        createdAt: DateTime.utc(2026, 11, 11, 10, 0),
      );

      final personalTask = TaskRecord(
        id: 'task-pers-1',
        workspaceId: 'workspace-personal',
        title: 'Купить подарки',
        createdAt: DateTime.utc(2026, 11, 11, 11, 0),
      );

      await engine.saveTask(workTask);
      await engine.saveTask(personalTask);

      // Active workspace is workspace-work by default
      engine.setActiveWorkspace('workspace-work');
      var tasks = await engine.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Подготовить квартальный отчёт');

      // Switch to personal workspace
      engine.setActiveWorkspace('workspace-personal');
      tasks = await engine.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Купить подарки');

      // Switch to projects workspace (empty)
      engine.setActiveWorkspace('workspace-projects');
      tasks = await engine.getTasks();
      expect(tasks, isEmpty);
    });

    test('setActiveWorkspace notifies listeners', () {
      var notified = false;
      engine.addListener(() => notified = true);

      engine.setActiveWorkspace('workspace-personal');
      expect(notified, isTrue);
      expect(engine.activeWorkspaceId, 'workspace-personal');
    });
  });
}
