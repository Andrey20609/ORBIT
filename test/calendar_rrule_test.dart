import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/services/calendar/calendar_models.dart';

void main() {
  group('[CAL-01] RecurrenceRule and Occurrence Generation', () {
    test('generates daily occurrences with interval 2', () {
      const rrule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        interval: 2,
        count: 4,
      );

      final start = DateTime.utc(2026, 11, 1, 10, 0);
      final occurrences = rrule.generateOccurrences(
        start: start,
        rangeEnd: DateTime.utc(2026, 11, 20),
      );

      expect(occurrences.length, 4);
      expect(occurrences[0], DateTime.utc(2026, 11, 1, 10, 0));
      expect(occurrences[1], DateTime.utc(2026, 11, 3, 10, 0));
      expect(occurrences[2], DateTime.utc(2026, 11, 5, 10, 0));
      expect(occurrences[3], DateTime.utc(2026, 11, 7, 10, 0));
    });

    test('generates weekly occurrences on specified days of week (Mon, Wed, Fri)', () {
      const rrule = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: [DateTime.monday, DateTime.wednesday, DateTime.friday],
      );

      // 2026-11-02 is Monday
      final start = DateTime.utc(2026, 11, 2, 9, 0);
      final rangeEnd = DateTime.utc(2026, 11, 8, 23, 59);

      final occurrences = rrule.generateOccurrences(
        start: start,
        rangeEnd: rangeEnd,
      );

      expect(occurrences.length, 3);
      expect(occurrences[0].weekday, DateTime.monday);
      expect(occurrences[1].weekday, DateTime.wednesday);
      expect(occurrences[2].weekday, DateTime.friday);
    });

    test('round-trips RRULE string serialization and parsing', () {
      final until = DateTime.utc(2026, 12, 31, 23, 59);
      final original = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        until: until,
        daysOfWeek: const [DateTime.tuesday, DateTime.thursday],
      );

      final rruleStr = original.toRRuleString();
      expect(rruleStr, contains('FREQ=WEEKLY'));
      expect(rruleStr, contains('BYDAY=TU,TH'));

      final parsed = RecurrenceRule.parse(rruleStr);
      expect(parsed, isNotNull);
      expect(parsed!.frequency, RecurrenceFrequency.weekly);
      expect(parsed.daysOfWeek, const [DateTime.tuesday, DateTime.thursday]);
      expect(parsed.until, isNotNull);
    });
  });
}
