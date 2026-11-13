import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/models/task_record.dart';
import 'package:orbit_visual_lab/services/tasks/tasks_service.dart';

void main() {
  late MemoryOrbitDatabase db;
  late OrbitDataEngine dataEngine;
  late TasksService tasksService;

  setUp(() async {
    db = MemoryOrbitDatabase();
    dataEngine = OrbitDataEngine(db);
    await dataEngine.initialize();

    tasksService = TasksService(dataEngine);
  });

  group('[TSK-01] Tasks Hierarchy and Subtasks', () {
    test('tracks subtask completion and calculates progress fraction', () async {
      final parentTask = TaskRecord(
        id: 'parent-task-1',
        workspaceId: 'workspace-work',
        title: 'Запустить Visual Engine 2.0',
        project: 'Релиз',
        createdAt: DateTime.utc(2026, 11, 11, 10, 0),
      );
      await dataEngine.saveTask(parentTask);

      final subtask1 = await tasksService.addSubtask(
        taskId: 'parent-task-1',
        title: 'Оптимизировать шейдеры стекла',
      );
      final subtask2 = await tasksService.addSubtask(
        taskId: 'parent-task-1',
        title: 'Проверить регрессионный тестборд',
      );

      var taskWithSubtasks = await tasksService.getTaskWithSubtasks('parent-task-1');
      expect(taskWithSubtasks, isNotNull);
      expect(taskWithSubtasks!.totalSubtasks, 2);
      expect(taskWithSubtasks.completedSubtasks, 0);
      expect(taskWithSubtasks.progress, 0.0);

      // Complete first subtask
      await tasksService.toggleSubtask('parent-task-1', subtask1.id, true);
      taskWithSubtasks = await tasksService.getTaskWithSubtasks('parent-task-1');
      expect(taskWithSubtasks!.completedSubtasks, 1);
      expect(taskWithSubtasks.progress, 0.5);

      // Complete second subtask -> triggers parent task completion
      await tasksService.toggleSubtask('parent-task-1', subtask2.id, true);
      taskWithSubtasks = await tasksService.getTaskWithSubtasks('parent-task-1');
      expect(taskWithSubtasks!.completedSubtasks, 2);
      expect(taskWithSubtasks.progress, 1.0);
      expect(taskWithSubtasks.isFullyCompleted, isTrue);

      final updatedParent = (await dataEngine.getTasks()).firstWhere((t) => t.id == 'parent-task-1');
      expect(updatedParent.isDone, isTrue);
    });
  });
}
