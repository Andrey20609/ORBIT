import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
final class NoteRecord {
  const NoteRecord({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'workspace_id': workspaceId,
    'title': title,
    'content': content,
    'tags_json': jsonEncode(tags),
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory NoteRecord.fromMap(Map<String, Object?> map) {
    List<String> parsedTags = const [];
    final rawTags = map['tags_json'];
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return NoteRecord(
      id: map['id']! as String,
      workspaceId: (map['workspace_id'] as String?) ?? 'workspace-work',
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      tags: parsedTags,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
        isUtc: true,
      ),
    );
  }

  NoteRecord copyWith({
    String? workspaceId,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return NoteRecord(
      id: id,
      workspaceId: workspaceId ?? this.workspaceId,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workspaceId == other.workspaceId &&
          title == other.title &&
          content == other.content &&
          listEquals(tags, other.tags);

  @override
  int get hashCode => Object.hash(
    id,
    workspaceId,
    title,
    content,
    Object.hashAll(tags),
  );
}
