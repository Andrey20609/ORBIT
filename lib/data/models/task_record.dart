import 'package:flutter/foundation.dart';

@immutable
final class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.workspaceId,
    required this.title,
    this.project,
    this.dueDate,
    this.isDone = false,
    this.priority = 0,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String? project;
  final String? dueDate;
  final bool isDone;
  final int priority; // 0 = standard, 1 = high, 2 = urgent
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'workspace_id': workspaceId,
    'title': title,
    'project': project,
    'due_date': dueDate,
    'is_done': isDone ? 1 : 0,
    'priority': priority,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory TaskRecord.fromMap(Map<String, Object?> map) {
    return TaskRecord(
      id: map['id']! as String,
      workspaceId: (map['workspace_id'] as String?) ?? 'workspace-work',
      title: map['title']! as String,
      project: map['project'] as String?,
      dueDate: map['due_date'] as String?,
      isDone: ((map['is_done'] as num?)?.toInt() ?? 0) == 1,
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
    );
  }

  TaskRecord copyWith({
    String? workspaceId,
    String? title,
    String? project,
    String? dueDate,
    bool? isDone,
    int? priority,
  }) {
    return TaskRecord(
      id: id,
      workspaceId: workspaceId ?? this.workspaceId,
      title: title ?? this.title,
      project: project ?? this.project,
      dueDate: dueDate ?? this.dueDate,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workspaceId == other.workspaceId &&
          title == other.title &&
          project == other.project &&
          dueDate == other.dueDate &&
          isDone == other.isDone &&
          priority == other.priority;

  @override
  int get hashCode => Object.hash(
    id,
    workspaceId,
    title,
    project,
    dueDate,
    isDone,
    priority,
  );
}
