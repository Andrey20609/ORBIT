import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/models/contact_record.dart';
import 'package:orbit_visual_lab/data/models/email_record.dart';
import 'package:orbit_visual_lab/data/models/event_record.dart';
import 'package:orbit_visual_lab/data/models/note_record.dart';
import 'package:orbit_visual_lab/data/models/task_record.dart';

void main() {
  late MemoryOrbitDatabase db;
  late OrbitDataEngine engine;

  setUp(() async {
    db = MemoryOrbitDatabase();
    engine = OrbitDataEngine(db);
    await engine.initialize();
  });

  group('OrbitDatabase and OrbitDataEngine CRUD', () {
    test('auto-seeds default workspaces', () async {
      final workspaces = await engine.getWorkspaces();
      expect(workspaces.length, 3);
      expect(workspaces.map((w) => w.id), containsAll([
        'workspace-work',
        'workspace-personal',
        'workspace-projects',
      ]));
    });

    test('performs full Task CRUD operations', () async {
      final task = TaskRecord(
        id: 'task-101',
        workspaceId: 'workspace-work',
        title: 'Подготовить отчёт по КГЭ',
        project: 'КТЭ',
        dueDate: 'Сегодня, 17:00',
        isDone: false,
        priority: 1,
        createdAt: DateTime.utc(2026, 11, 11, 10, 0),
      );

      await engine.saveTask(task);
      var tasks = await engine.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Подготовить отчёт по КГЭ');
      expect(tasks.first.isDone, isFalse);

      // Toggle done
      await engine.setTaskDone('task-101', true);
      tasks = await engine.getTasks();
      expect(tasks.first.isDone, isTrue);

      // Delete task
      await engine.deleteTask('task-101');
      tasks = await engine.getTasks();
      expect(tasks, isEmpty);
    });

    test('performs Event CRUD operations', () async {
      final event = EventRecord(
        id: 'event-201',
        workspaceId: 'workspace-work',
        title: 'Совещание по ВП',
        description: 'Teams',
        startTime: DateTime.utc(2026, 11, 11, 10, 0),
        endTime: DateTime.utc(2026, 11, 11, 11, 0),
        location: 'Teams',
      );

      await engine.saveEvent(event);
      var events = await engine.getEvents();
      expect(events.length, 1);
      expect(events.first.title, 'Совещание по ВП');

      await engine.deleteEvent('event-201');
      events = await engine.getEvents();
      expect(events, isEmpty);
    });

    test('performs Email CRUD and read status', () async {
      final email = EmailRecord(
        id: 'email-301',
        workspaceId: 'workspace-work',
        sender: 'Мария Соколова',
        recipient: 'alexey@orbit.app',
        subject: 'План на неделю',
        preview: 'Прикрепляю обновлённый план',
        body: 'Привет, Алексей!',
        timestamp: DateTime.utc(2026, 11, 11, 9, 41),
        isRead: false,
      );

      await engine.saveEmail(email);
      var emails = await engine.getEmails();
      expect(emails.length, 1);
      expect(emails.first.isRead, isFalse);

      await engine.setEmailRead('email-301', true);
      emails = await engine.getEmails();
      expect(emails.first.isRead, isTrue);
    });

    test('performs Notes and Contacts operations', () async {
      final note = NoteRecord(
        id: 'note-401',
        workspaceId: 'workspace-work',
        title: 'Идеи для релиза',
        content: 'Внедрить Visual Engine 2.0',
        tags: [' релиз', 'дизайн'],
        updatedAt: DateTime.utc(2026, 11, 11, 12, 0),
      );
      await engine.saveNote(note);
      final notes = await engine.getNotes();
      expect(notes.length, 1);
      expect(notes.first.title, 'Идеи для релиза');

      final contact = const ContactRecord(
        id: 'contact-501',
        workspaceId: 'workspace-work',
        name: 'Илья Волков',
        email: 'volkov@example.com',
        company: 'ORBIT Team',
        role: 'Дизайнер',
      );
      await engine.saveContact(contact);
      final contacts = await engine.getContacts();
      expect(contacts.length, 1);
      expect(contacts.first.name, 'Илья Волков');
    });
  });
}
