import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/database/orbit_data_engine.dart';
import '../../data/models/email_record.dart';
import '../../data/models/event_record.dart';
import '../../data/models/task_record.dart';
import 'task_models.dart';

final class TasksService extends ChangeNotifier {
  TasksService(this._dataEngine);

  final OrbitDataEngine _dataEngine;
  final Map<String, List<SubtaskRecord>> _subtasksByTask = {};
  final List<CrossEntityLink> _links = [];

  OrbitDataEngine get dataEngine => _dataEngine;

  int _subtaskSequence = 0;

  // --- Subtasks ---

  List<SubtaskRecord> getSubtasks(String taskId) {
    return List.unmodifiable(_subtasksByTask[taskId] ?? []);
  }

  Future<SubtaskRecord> addSubtask({
    required String taskId,
    required String title,
  }) async {
    final subtaskId = 'subtask-${DateTime.now().microsecondsSinceEpoch}-${++_subtaskSequence}';
    final subtask = SubtaskRecord(
      id: subtaskId,
      taskId: taskId,
      title: title,
      createdAt: DateTime.now().toUtc(),
    );

    final list = _subtasksByTask.putIfAbsent(taskId, () => []);
    list.add(subtask);
    notifyListeners();
    return subtask;
  }

  Future<void> toggleSubtask(String taskId, String subtaskId, bool isDone) async {
    final list = _subtasksByTask[taskId];
    if (list == null) return;

    final index = list.indexWhere((s) => s.id == subtaskId);
    if (index >= 0) {
      list[index] = list[index].copyWith(isDone: isDone);

      // Check if all subtasks are done: auto-complete parent task
      final allDone = list.every((s) => s.isDone);
      if (allDone) {
        await _dataEngine.setTaskDone(taskId, true);
      }
      notifyListeners();
    }
  }

  Future<TaskWithSubtasks?> getTaskWithSubtasks(String taskId) async {
    final tasks = await _dataEngine.getTasks();
    final task = tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('Task not found: $taskId'),
    );
    final subtasks = getSubtasks(taskId);
    return TaskWithSubtasks(task: task, subtasks: subtasks);
  }

  // --- Cross-Entity Linkage (Email → Task → Event) ---

  Future<TaskRecord> createTaskFromEmail(
    EmailRecord email, {
    String? project,
    String? dueDate,
    int priority = 1,
  }) async {
    final taskId = 'task-from-mail-${email.id}';
    final task = TaskRecord(
      id: taskId,
      workspaceId: email.workspaceId,
      title: 'Ответить: ${email.subject}',
      project: project ?? 'Почта',
      dueDate: dueDate ?? 'Сегодня',
      priority: priority,
      createdAt: DateTime.now().toUtc(),
    );

    await _dataEngine.saveTask(task);

    // Create bidirectional link
    final linkId = 'link-${DateTime.now().millisecondsSinceEpoch}';
    _links.add(
      CrossEntityLink(
        id: linkId,
        sourceType: EntityType.email,
        sourceId: email.id,
        targetType: EntityType.task,
        targetId: task.id,
        title: 'Письмо: ${email.subject}',
        createdAt: DateTime.now().toUtc(),
      ),
    );

    notifyListeners();
    return task;
  }

  Future<EventRecord> createEventFromTask(
    TaskRecord task, {
    required DateTime startTime,
    required DateTime endTime,
    String? location,
  }) async {
    final eventId = 'event-from-task-${task.id}';
    final event = EventRecord(
      id: eventId,
      workspaceId: task.workspaceId,
      title: task.title,
      description: task.project != null ? 'Проект: ${task.project}' : null,
      startTime: startTime,
      endTime: endTime,
      location: location,
    );

    await _dataEngine.saveEvent(event);

    final linkId = 'link-${DateTime.now().millisecondsSinceEpoch}';
    _links.add(
      CrossEntityLink(
        id: linkId,
        sourceType: EntityType.task,
        sourceId: task.id,
        targetType: EntityType.event,
        targetId: event.id,
        title: 'Задача: ${task.title}',
        createdAt: DateTime.now().toUtc(),
      ),
    );

    notifyListeners();
    return event;
  }

  List<CrossEntityLink> getLinksForEntity(String entityId) {
    return _links
        .where((l) => l.sourceId == entityId || l.targetId == entityId)
        .toList();
  }
}
