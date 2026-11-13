import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/demo_data.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';

void main() {
  test(
    'local tasks, events, read mail and drafts survive recreation',
    () async {
      final repository = MemoryLocalStateRepository();
      final first = OrbitAppState(repository);
      await first.load();
      first.addTask('Проверить сохранение');
      first.toggleTask('report');
      first.setTaskPriority('report', 2);
      first.addEvent('Локальное событие', '11:30', DateTime(2026, 11, 8));
      first.markRead('weekly-plan');
      first.updateDraft(
        to: 'person@example.demo',
        subject: 'Локальный черновик',
        body: 'Текст',
      );
      await first.flush();

      final second = OrbitAppState(repository);
      await second.load();

      expect(second.tasks.first.title, 'Проверить сохранение');
      expect(second.taskById('report')?.done, isTrue);
      expect(second.taskById('report')?.priority, 2);
      expect(second.events.last.title, 'Локальное событие');
      expect(second.events.last.time, '11:30');
      expect(second.unreadCount(secondTasksEmails), 1);
      expect(second.draftTo, 'person@example.demo');
      expect(second.draftSubject, 'Локальный черновик');
      expect(second.draftBody, 'Текст');
    },
  );

  test(
    'failed save is observable and retry persists the pending snapshot',
    () async {
      final repository = MemoryLocalStateRepository()..failNextSave = true;
      final state = OrbitAppState(repository);
      await state.load();
      var notifications = 0;
      state.addListener(() => notifications++);
      state.addTask('Не потерять изменение');

      await expectLater(state.flush(), throwsA(isA<StateError>()));
      expect(state.lastPersistenceError, isA<StateError>());
      expect(state.tasks.first.title, 'Не потерять изменение');
      expect(notifications, greaterThan(0));

      await state.retryPersistence();
      final restored = OrbitAppState(repository);
      await restored.load();
      expect(restored.tasks.first.title, 'Не потерять изменение');
      expect(state.lastPersistenceError, isNull);
    },
  );

  test(
    'invalid record rejects the whole snapshot without partial restoration',
    () async {
      final repository = MemoryLocalStateRepository({
        'tasks': [
          {'invalid': true},
        ],
        'events': <Object?>[],
        'readEmails': ['weekly-plan'],
        'draftSubject': 'Сохранено',
      });
      final state = OrbitAppState(repository);
      await state.load();

      expect(state.tasks.length, initialTasks.length);
      expect(state.events.length, demoEvents.length);
      expect(state.draftSubject, isEmpty);
      expect(state.lastLoadError, isNotNull);
      expect(state.unreadCount(secondTasksEmails), 2);
    },
  );
}

const secondTasksEmails = [
  DemoEmail(
    id: 'weekly-plan',
    sender: 'Demo',
    email: 'demo@example.demo',
    subject: 'Demo',
    preview: 'Demo',
    body: 'Demo',
    time: '10:00',
    color: Color(0xFF9B8CFF),
    unread: true,
  ),
  DemoEmail(
    id: 'design-review',
    sender: 'Demo',
    email: 'demo@example.demo',
    subject: 'Demo',
    preview: 'Demo',
    body: 'Demo',
    time: '10:00',
    color: Color(0xFF9B8CFF),
    unread: true,
  ),
];
