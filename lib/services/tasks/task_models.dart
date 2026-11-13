import 'package:flutter/foundation.dart';
import '../../data/models/task_record.dart';

@immutable
final class SubtaskRecord {
  const SubtaskRecord({
    required this.id,
    required this.taskId,
    required this.title,
    this.isDone = false,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String title;
  final bool isDone;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'task_id': taskId,
    'title': title,
    'is_done': isDone ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory SubtaskRecord.fromMap(Map<String, Object?> map) {
    return SubtaskRecord(
      id: map['id']! as String,
      taskId: map['task_id']! as String,
      title: map['title']! as String,
      isDone: ((map['is_done'] as num?)?.toInt() ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
        isUtc: true,
      ),
    );
  }

  SubtaskRecord copyWith({
    String? title,
    bool? isDone,
  }) {
    return SubtaskRecord(
      id: id,
      taskId: taskId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtaskRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          taskId == other.taskId &&
          title == other.title &&
          isDone == other.isDone;

  @override
  int get hashCode => Object.hash(id, taskId, title, isDone);
}

@immutable
final class TaskWithSubtasks {
  const TaskWithSubtasks({
    required this.task,
    this.subtasks = const [],
  });

  final TaskRecord task;
  final List<SubtaskRecord> subtasks;

  int get totalSubtasks => subtasks.length;
  int get completedSubtasks => subtasks.where((s) => s.isDone).length;

  double get progress {
    if (subtasks.isEmpty) return task.isDone ? 1.0 : 0.0;
    return completedSubtasks / totalSubtasks;
  }

  bool get isFullyCompleted =>
      task.isDone || (subtasks.isNotEmpty && completedSubtasks == totalSubtasks);
}

enum EntityType {
  email,
  task,
  event,
  document,
  note,
}

@immutable
final class CrossEntityLink {
  const CrossEntityLink({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.createdAt,
  });

  final String id;
  final EntityType sourceType;
  final String sourceId;
  final EntityType targetType;
  final String targetId;
  final String title;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'source_type': sourceType.name,
    'source_id': sourceId,
    'target_type': targetType.name,
    'target_id': targetId,
    'title': title,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory CrossEntityLink.fromMap(Map<String, Object?> map) {
    return CrossEntityLink(
      id: map['id']! as String,
      sourceType: EntityType.values.firstWhere(
        (e) => e.name == map['source_type'],
        orElse: () => EntityType.email,
      ),
      sourceId: map['source_id']! as String,
      targetType: EntityType.values.firstWhere(
        (e) => e.name == map['target_type'],
        orElse: () => EntityType.task,
      ),
      targetId: map['target_id']! as String,
      title: map['title']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
        isUtc: true,
      ),
    );
  }
}
