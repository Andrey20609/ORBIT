import 'dart:async';
import '../../data/models/event_record.dart';

abstract interface class CalendarTransport {
  Future<List<EventRecord>> fetchEvents({
    required DateTime start,
    required DateTime end,
  });

  Future<EventRecord> createEvent(EventRecord event);
  Future<bool> deleteEvent(String eventId);
}

final class SimulatedCalendarTransport implements CalendarTransport {
  SimulatedCalendarTransport({List<EventRecord>? remoteEvents})
    : _remoteEvents = remoteEvents ?? [];

  final List<EventRecord> _remoteEvents;

  void addRemoteEvent(EventRecord event) {
    _remoteEvents.add(event);
  }

  @override
  Future<List<EventRecord>> fetchEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    return _remoteEvents.where((e) {
      return (e.startTime.isAfter(start) || e.startTime.isAtSameMomentAs(start)) &&
          (e.startTime.isBefore(end) || e.startTime.isAtSameMomentAs(end));
    }).toList();
  }

  @override
  Future<EventRecord> createEvent(EventRecord event) async {
    _remoteEvents.removeWhere((e) => e.id == event.id);
    _remoteEvents.add(event);
    return event;
  }

  @override
  Future<bool> deleteEvent(String eventId) async {
    final initialCount = _remoteEvents.length;
    _remoteEvents.removeWhere((e) => e.id == eventId);
    return _remoteEvents.length < initialCount;
  }
}
