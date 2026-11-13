import 'package:flutter/foundation.dart';

@immutable
final class WorkspaceRecord {
  const WorkspaceRecord({
    required this.id,
    required this.name,
    required this.type,
    this.colorValue = 0xFF9B8CFF,
    this.isDefault = false,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String type; // 'work', 'personal', 'projects'
  final int colorValue;
  final bool isDefault;
  final DateTime createdAt;

  static final defaultWorkspaces = [
    WorkspaceRecord(
      id: 'workspace-work',
      name: 'Работа',
      type: 'work',
      colorValue: 0xFF78D9FF,
      isDefault: true,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
    WorkspaceRecord(
      id: 'workspace-personal',
      name: 'Личное',
      type: 'personal',
      colorValue: 0xFF9B8CFF,
      isDefault: false,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
    WorkspaceRecord(
      id: 'workspace-projects',
      name: 'Проекты',
      type: 'projects',
      colorValue: 0xFFFFB68C,
      isDefault: false,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'color_value': colorValue,
    'is_default': isDefault ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory WorkspaceRecord.fromMap(Map<String, Object?> map) {
    return WorkspaceRecord(
      id: map['id']! as String,
      name: map['name']! as String,
      type: (map['type'] as String?) ?? 'work',
      colorValue: (map['color_value'] as num?)?.toInt() ?? 0xFF9B8CFF,
      isDefault: ((map['is_default'] as num?)?.toInt() ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
        isUtc: true,
      ),
    );
  }

  WorkspaceRecord copyWith({
    String? name,
    String? type,
    int? colorValue,
    bool? isDefault,
  }) {
    return WorkspaceRecord(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          colorValue == other.colorValue &&
          isDefault == other.isDefault;

  @override
  int get hashCode => Object.hash(id, name, type, colorValue, isDefault);
}
