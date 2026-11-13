import 'package:flutter/foundation.dart';

enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly,
}

@immutable
final class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.until,
    this.count,
    this.daysOfWeek = const [],
  });

  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime? until;
  final int? count;
  final List<int> daysOfWeek; // 1 = Monday .. 7 = Sunday

  String toRRuleString() {
    final buffer = StringBuffer('FREQ=${frequency.name.toUpperCase()}');
    if (interval > 1) buffer.write(';INTERVAL=$interval');
    if (until != null) {
      buffer.write(';UNTIL=${until!.toUtc().toIso8601String()}');
    }
    if (count != null) buffer.write(';COUNT=$count');
    if (daysOfWeek.isNotEmpty) {
      const dayNames = {
        1: 'MO',
        2: 'TU',
        3: 'WE',
        4: 'TH',
        5: 'FR',
        6: 'SA',
        7: 'SU',
      };
      final days = daysOfWeek.map((d) => dayNames[d] ?? 'MO').join(',');
      buffer.write(';BYDAY=$days');
    }
    return buffer.toString();
  }

  static RecurrenceRule? parse(String? rruleStr) {
    if (rruleStr == null || rruleStr.isEmpty) return null;
    final parts = rruleStr.split(';');
    RecurrenceFrequency freq = RecurrenceFrequency.weekly;
    int interval = 1;
    DateTime? until;
    int? count;
    List<int> daysOfWeek = [];

    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      final key = kv[0].toUpperCase();
      final val = kv[1];

      switch (key) {
        case 'FREQ':
          freq = switch (val.toUpperCase()) {
            'DAILY' => RecurrenceFrequency.daily,
            'WEEKLY' => RecurrenceFrequency.weekly,
            'MONTHLY' => RecurrenceFrequency.monthly,
            'YEARLY' => RecurrenceFrequency.yearly,
            _ => RecurrenceFrequency.weekly,
          };
        case 'INTERVAL':
          interval = int.tryParse(val) ?? 1;
        case 'UNTIL':
          until = DateTime.tryParse(val);
        case 'COUNT':
          count = int.tryParse(val);
        case 'BYDAY':
          const dayMap = {
            'MO': 1,
            'TU': 2,
            'WE': 3,
            'TH': 4,
            'FR': 5,
            'SA': 6,
            'SU': 7,
          };
          daysOfWeek = val
              .split(',')
              .map((d) => dayMap[d.toUpperCase()])
              .whereType<int>()
              .toList();
      }
    }

    return RecurrenceRule(
      frequency: freq,
      interval: interval,
      until: until,
      count: count,
      daysOfWeek: daysOfWeek,
    );
  }

  List<DateTime> generateOccurrences({
    required DateTime start,
    required DateTime rangeEnd,
    int maxOccurrences = 50,
  }) {
    final occurrences = <DateTime>[];
    var current = start;
    var totalGenerated = 0;

    while (current.isBefore(rangeEnd) || current.isAtSameMomentAs(rangeEnd)) {
      if (until != null && current.isAfter(until!)) break;
      if (count != null && totalGenerated >= count!) break;
      if (occurrences.length >= maxOccurrences) break;

      if (frequency == RecurrenceFrequency.weekly && daysOfWeek.isNotEmpty) {
        if (daysOfWeek.contains(current.weekday)) {
          occurrences.add(current);
          totalGenerated++;
        }
      } else {
        occurrences.add(current);
        totalGenerated++;
      }

      switch (frequency) {
        case RecurrenceFrequency.daily:
          current = current.add(Duration(days: interval));
        case RecurrenceFrequency.weekly:
          if (daysOfWeek.isNotEmpty) {
            current = current.add(const Duration(days: 1));
          } else {
            current = current.add(Duration(days: 7 * interval));
          }
        case RecurrenceFrequency.monthly:
          current = DateTime(
            current.year,
            current.month + interval,
            current.day,
            current.hour,
            current.minute,
          );
        case RecurrenceFrequency.yearly:
          current = DateTime(
            current.year + interval,
            current.month,
            current.day,
            current.hour,
            current.minute,
          );
      }
    }

    return occurrences;
  }
}
