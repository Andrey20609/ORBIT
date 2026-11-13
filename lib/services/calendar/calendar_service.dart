import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/database/orbit_data_engine.dart';
import '../../data/models/event_record.dart';
import 'calendar_transport.dart';

final class CalendarService extends ChangeNotifier {
  CalendarService({
    required OrbitDataEngine dataEngine,
    required CalendarTransport transport,
  }) : _dataEngine = dataEngine,
       _transport = transport;

  final OrbitDataEngine _dataEngine;
  final CalendarTransport _transport;

  Future<int> syncRange({
    required DateTime start,
    required DateTime end,
    String? workspaceId,
  }) async {
    final ws = workspaceId ?? _dataEngine.activeWorkspaceId;
    final remoteEvents = await _transport.fetchEvents(start: start, end: end);
    var savedCount = 0;

    for (final event in remoteEvents) {
      final record = event.copyWith(workspaceId: ws);
      await _dataEngine.saveEvent(record);
      savedCount++;
    }

    notifyListeners();
    return savedCount;
  }

  Future<EventRecord> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? location,
    String? workspaceId,
    List<String> participants = const [],
  }) async {
    final ws = workspaceId ?? _dataEngine.activeWorkspaceId;
    final id = 'event-${DateTime.now().millisecondsSinceEpoch}';

    final event = EventRecord(
      id: id,
      workspaceId: ws,
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      location: location,
      participants: participants,
    );

    // Save locally to SQLite
    await _dataEngine.saveEvent(event);

    // Sync to remote calendar
    await _transport.createEvent(event);

    notifyListeners();
    return event;
  }

  Future<void> deleteEvent(String eventId) async {
    await _dataEngine.deleteEvent(eventId);
    await _transport.deleteEvent(eventId);
    notifyListeners();
  }

  Future<List<EventRecord>> getEventsForDay(
    DateTime day, {
    String? workspaceId,
  }) async {
    final allEvents = await _dataEngine.getEvents(workspaceId: workspaceId);
    return allEvents.where((e) {
      return e.startTime.year == day.year &&
          e.startTime.month == day.month &&
          e.startTime.day == day.day;
    }).toList();
  }
}
