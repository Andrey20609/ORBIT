import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/models/email_record.dart';
import 'package:orbit_visual_lab/services/tasks/task_models.dart';
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

  group('[TSK-02] Cross-Entity Linkage (Email -> Task -> Event)', () {
    test('creates Task from incoming Email and establishes bidirectional link', () async {
      final email = EmailRecord(
        id: 'email-audit-1',
        workspaceId: 'workspace-work',
        sender: 'Артём Кузнецов',
        recipient: 'alexey@orbit.app',
        subject: 'Презентация для инвесторов',
        preview: 'Финальная версия и правки',
        body: 'Привет! Прикладываю правки.',
        timestamp: DateTime.utc(2026, 11, 11, 10, 0),
      );
      await dataEngine.saveEmail(email);

      // 1. Create task from email
      final task = await tasksService.createTaskFromEmail(
        email,
        project: 'Инвестиции',
        dueDate: 'Завтра, 12:00',
      );

      expect(task.title, 'Ответить: Презентация для инвесторов');
      expect(task.project, 'Инвестиции');

      // Verify link exists on both email and task
      final emailLinks = tasksService.getLinksForEntity(email.id);
      expect(emailLinks.length, 1);
      expect(emailLinks.first.targetType, EntityType.task);
      expect(emailLinks.first.targetId, task.id);

      final taskLinks = tasksService.getLinksForEntity(task.id);
      expect(taskLinks.length, 1);
      expect(taskLinks.first.sourceType, EntityType.email);

      // 2. Schedule Event in calendar from Task
      final event = await tasksService.createEventFromTask(
        task,
        startTime: DateTime.utc(2026, 11, 12, 14, 0),
        endTime: DateTime.utc(2026, 11, 12, 15, 0),
        location: 'Zoom',
      );

      expect(event.title, task.title);

      // Verify all links for task (now 2 links: one to Email, one to Event)
      final allTaskLinks = tasksService.getLinksForEntity(task.id);
      expect(allTaskLinks.length, 2);
    });
  });
}
