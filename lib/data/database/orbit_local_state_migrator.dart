import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/event_record.dart';
import '../models/task_record.dart';
import '../orbit_local_state_repository.dart';
import 'orbit_data_engine.dart';

@immutable
final class MigrationResult {
  const MigrationResult({
    required this.tasksMigrated,
    required this.eventsMigrated,
    required this.success,
    this.error,
  });

  final int tasksMigrated;
  final int eventsMigrated;
  final bool success;
  final String? error;
}

final class OrbitLocalStateMigrator {
  const OrbitLocalStateMigrator({
    required OrbitLocalStateRepository repository,
    required OrbitDataEngine dataEngine,
  }) : _repository = repository,
       _dataEngine = dataEngine;

  final OrbitLocalStateRepository _repository;
  final OrbitDataEngine _dataEngine;

  Future<MigrationResult> migrateIfNeeded({
    String defaultWorkspaceId = 'workspace-work',
  }) async {
    try {
      final legacyState = await _repository.load();
      if (legacyState.isEmpty) {
        return const MigrationResult(
          tasksMigrated: 0,
          eventsMigrated: 0,
          success: true,
        );
      }

      var tasksMigrated = 0;
      var eventsMigrated = 0;

      // Вся миграция выполняется в одной транзакции: при ошибке ни одна
      // запись не остаётся частично перенесённой. Повторный запуск не
      // создаёт дубликаты: saveTask/saveEvent пишут с replace-on-conflict
      // по тем же id.
      await _dataEngine.runInTransaction(() async {
        // 1. Migrate tasks
        final rawTasks = legacyState['tasks'];
        if (rawTasks is List) {
          for (final item in rawTasks) {
            if (item is Map<String, Object?>) {
              final task = TaskRecord(
                id: item['id']! as String,
                workspaceId: defaultWorkspaceId,
                title: item['title']! as String,
                project: item['project'] as String?,
                dueDate: item['due'] as String?,
                isDone: (item['done'] as bool?) ?? false,
                priority: (item['priority'] as num?)?.toInt() ?? 0,
                createdAt: DateTime.now().toUtc(),
              );
              await _dataEngine.saveTask(task);
              tasksMigrated++;
            }
          }
        }

        // 2. Migrate events
        final rawEvents = legacyState['events'];
        if (rawEvents is List) {
          for (final item in rawEvents) {
            if (item is Map<String, Object?>) {
              final startTime = item['start'] != null
                  ? DateTime.tryParse(item['start'] as String) ?? DateTime.now()
                  : DateTime.now();
              final endTime = item['end'] != null
                  ? DateTime.tryParse(item['end'] as String) ??
                        startTime.add(const Duration(hours: 1))
                  : startTime.add(const Duration(hours: 1));

              final event = EventRecord(
                id: item['id']! as String,
                workspaceId: defaultWorkspaceId,
                title: (item['title'] as String?) ?? 'Событие',
                description: item['location'] as String?,
                startTime: startTime.toUtc(),
                endTime: endTime.toUtc(),
                location: item['location'] as String?,
              );
              await _dataEngine.saveEvent(event);
              eventsMigrated++;
            }
          }
        }
      });

      return MigrationResult(
        tasksMigrated: tasksMigrated,
        eventsMigrated: eventsMigrated,
        success: true,
      );
    } catch (e) {
      return MigrationResult(
        tasksMigrated: 0,
        eventsMigrated: 0,
        success: false,
        error: e.toString(),
      );
    }
  }
}
