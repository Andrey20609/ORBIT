import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
final class EventRecord {
  const EventRecord({
    required this.id,
    required this.workspaceId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.isAllDay = false,
    this.category = 'work',
    this.participants = const [],
  });

  final String id;
  final String workspaceId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final bool isAllDay;
  final String category;
  final List<String> participants;

  Map<String, Object?> toMap() => {
    'id': id,
    'workspace_id': workspaceId,
    'title': title,
    'description': description,
    'start_time': startTime.millisecondsSinceEpoch,
    'end_time': endTime.millisecondsSinceEpoch,
    'location': location,
    'is_all_day': isAllDay ? 1 : 0,
    'category': category,
    'participants_json': jsonEncode(participants),
  };

  factory EventRecord.fromMap(Map<String, Object?> map) {
    List<String> parsedParticipants = const [];
    final rawParticipants = map['participants_json'];
    if (rawParticipants is String && rawParticipants.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawParticipants);
        if (decoded is List) {
          parsedParticipants = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return EventRecord(
      id: map['id']! as String,
      workspaceId: (map['workspace_id'] as String?) ?? 'workspace-work',
      title: map['title']! as String,
      description: map['description'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (map['start_time'] as num).toInt(),
        isUtc: true,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (map['end_time'] as num).toInt(),
        isUtc: true,
      ),
      location: map['location'] as String?,
      isAllDay: ((map['is_all_day'] as num?)?.toInt() ?? 0) == 1,
      category: (map['category'] as String?) ?? 'work',
      participants: parsedParticipants,
    );
  }

  EventRecord copyWith({
    String? workspaceId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    bool? isAllDay,
    String? category,
    List<String>? participants,
  }) {
    return EventRecord(
      id: id,
      workspaceId: workspaceId ?? this.workspaceId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      isAllDay: isAllDay ?? this.isAllDay,
      category: category ?? this.category,
      participants: participants ?? this.participants,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workspaceId == other.workspaceId &&
          title == other.title &&
          description == other.description &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          location == other.location &&
          isAllDay == other.isAllDay &&
          category == other.category &&
          listEquals(participants, other.participants);

  @override
  int get hashCode => Object.hash(
    id,
    workspaceId,
    title,
    description,
    startTime,
    endTime,
    location,
    isAllDay,
    category,
    Object.hashAll(participants),
  );
}
