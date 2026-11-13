import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/demo_data.dart';
import 'package:orbit_visual_lab/data/orbit_calendar.dart';

void main() {
  group('orbitAddMonths', () {
    test('December to January carries the year forward', () {
      expect(orbitAddMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
    });

    test('January to December carries the year backward', () {
      expect(orbitAddMonths(DateTime(2027, 1, 15), -1), DateTime(2026, 12, 15));
    });

    test('31 January clamps to 28 February in a common year', () {
      expect(orbitAddMonths(DateTime(2027, 1, 31), 1), DateTime(2027, 2, 28));
    });

    test('31 January clamps to 29 February in a leap year', () {
      expect(orbitAddMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('31 March back one month lands on 29 February 2028', () {
      expect(orbitAddMonths(DateTime(2028, 3, 31), -1), DateTime(2028, 2, 29));
    });

    test('31 August forward lands on 30 September', () {
      expect(orbitAddMonths(DateTime(2026, 8, 31), 1), DateTime(2026, 9, 30));
    });

    test('29 February plus twelve months clamps to 28 February', () {
      expect(orbitAddMonths(DateTime(2028, 2, 29), 12), DateTime(2029, 2, 28));
    });

    test('multi-year shift keeps the month index in range', () {
      expect(orbitAddMonths(DateTime(2026, 11, 9), 26), DateTime(2029, 1, 9));
      expect(orbitAddMonths(DateTime(2026, 11, 9), -26), DateTime(2024, 9, 9));
    });
  });

  group('orbitDaysInMonth', () {
    test('February across leap and century rules', () {
      expect(orbitDaysInMonth(2026, 2), 28);
      expect(orbitDaysInMonth(2028, 2), 29);
      expect(orbitDaysInMonth(2000, 2), 29);
      expect(orbitDaysInMonth(1900, 2), 28);
    });

    test('December and thirty-day months', () {
      expect(orbitDaysInMonth(2026, 12), 31);
      expect(orbitDaysInMonth(2026, 4), 30);
    });
  });

  group('orbitAddDays', () {
    test('crosses month and year boundaries', () {
      expect(orbitAddDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(orbitAddDays(DateTime(2027, 1, 1), -1), DateTime(2026, 12, 31));
      expect(orbitAddDays(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
      expect(orbitAddDays(DateTime(2028, 2, 29), 1), DateTime(2028, 3, 1));
    });

    test('always returns local midnight', () {
      final result = orbitAddDays(DateTime(2026, 3, 29, 23, 45), 1);
      expect(result, DateTime(2026, 3, 30));
      expect(result.hour, 0);
      expect(result.minute, 0);
    });
  });

  group('orbitStartOfWeek', () {
    test('Sunday maps back to the previous Monday', () {
      expect(orbitStartOfWeek(DateTime(2026, 11, 8)), DateTime(2026, 11, 2));
    });

    test('Monday maps to itself', () {
      expect(orbitStartOfWeek(DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
    });
  });

  group('event filtering and ordering', () {
    const dated = DemoEvent(
      'a',
      '10:00',
      'Датированное',
      '',
      Color(0xFF000000),
    );

    test('undated demo events belong to the injected today', () {
      final today = DateTime(2026, 11, 9);
      expect(orbitEventOccursOn(dated, today, today: today), isTrue);
      expect(
        orbitEventOccursOn(dated, DateTime(2026, 11, 10), today: today),
        isFalse,
      );
    });

    test('explicit date wins over today and ignores the time component', () {
      final event = DemoEvent(
        'b',
        '23:59',
        'Вечернее',
        '',
        const Color(0xFF000000),
        date: DateTime(2026, 11, 11, 23, 59),
      );
      expect(
        orbitEventOccursOn(
          event,
          DateTime(2026, 11, 11),
          today: DateTime(2026, 11, 9),
        ),
        isTrue,
      );
      expect(
        orbitEventOccursOn(
          event,
          DateTime(2026, 11, 12),
          today: DateTime(2026, 11, 9),
        ),
        isFalse,
      );
    });

    test('orbitEventsOn sorts by start time and is deterministic on ties', () {
      final day = DateTime(2026, 11, 9);
      final events = <DemoEvent>[
        DemoEvent(
          'z',
          '17:00',
          'Вечер',
          '',
          const Color(0xFF000000),
          date: day,
        ),
        DemoEvent(
          'b',
          '09:00',
          'Утро B',
          '',
          const Color(0xFF000000),
          date: day,
        ),
        DemoEvent(
          'a',
          '09:00',
          'Утро A',
          '',
          const Color(0xFF000000),
          date: day,
        ),
        DemoEvent(
          'other',
          '08:00',
          'Другой день',
          '',
          const Color(0xFF000000),
          date: DateTime(2026, 11, 10),
        ),
      ];
      final result = orbitEventsOn(events, day, today: day);
      expect(result.map((event) => event.id).toList(), ['a', 'b', 'z']);
    });

    test('clock injection drives the default today', () {
      withClock(Clock.fixed(DateTime(2030, 6, 15, 8)), () {
        expect(orbitToday(), DateTime(2030, 6, 15));
        expect(orbitEventOccursOn(dated, DateTime(2030, 6, 15)), isTrue);
      });
    });

    test('unparseable time sorts last without throwing', () {
      const broken = DemoEvent('x', 'Вчера', '', '', Color(0xFF000000));
      expect(orbitEventMinutes(broken), 1 << 30);
    });
  });

  group('orbitDayKey', () {
    test('is zero padded and locale independent', () {
      expect(orbitDayKey(DateTime(2027, 1, 5)), '2027-01-05');
      expect(orbitDayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
