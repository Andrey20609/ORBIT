library;

import 'package:clock/clock.dart';

import 'demo_data.dart';

DateTime orbitDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime orbitToday() => orbitDateOnly(clock.now());

bool orbitIsSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime orbitAddDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

int orbitDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime orbitAddMonths(DateTime date, int months) {
  final totalMonths = date.year * 12 + (date.month - 1) + months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final maxDay = orbitDaysInMonth(year, month);
  final day = date.day > maxDay ? maxDay : date.day;
  return DateTime(year, month, day);
}

DateTime orbitStartOfWeek(DateTime date) =>
    orbitAddDays(orbitDateOnly(date), -(date.weekday - DateTime.monday));

String orbitDayKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime orbitEventDay(DemoEvent event, {DateTime? today}) {
  if (event.date != null) return orbitDateOnly(event.date!);
  final current = today ?? orbitToday();
  final demoIndex = switch (event.id) {
    'review' => 0,
    'audit' => 1,
    'report' => 2,
    _ => 0,
  };
  return orbitAddDays(current, demoIndex);
}

bool orbitEventOccursOn(DemoEvent event, DateTime day, {DateTime? today}) =>
    orbitIsSameDay(orbitEventDay(event, today: today), orbitDateOnly(day));

int orbitEventMinutes(DemoEvent event) {
  final parts = event.time.split(':');
  if (parts.length != 2) return 1 << 30;
  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) return 1 << 30;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return 1 << 30;
  return hour * 60 + minute;
}

int orbitCompareEvents(DemoEvent a, DemoEvent b, {DateTime? today}) {
  final byDay = orbitEventDay(
    a,
    today: today,
  ).compareTo(orbitEventDay(b, today: today));
  if (byDay != 0) return byDay;
  final byTime = orbitEventMinutes(a).compareTo(orbitEventMinutes(b));
  if (byTime != 0) return byTime;
  return a.id.compareTo(b.id);
}

List<DemoEvent> orbitEventsOn(
  Iterable<DemoEvent> events,
  DateTime day, {
  DateTime? today,
}) {
  final result = events
      .where((event) => orbitEventOccursOn(event, day, today: today))
      .toList();
  result.sort((a, b) => orbitCompareEvents(a, b, today: today));
  return result;
}

List<DemoEvent> orbitSortedEvents(
  Iterable<DemoEvent> events, {
  DateTime? today,
}) {
  final result = events.toList();
  result.sort((a, b) => orbitCompareEvents(a, b, today: today));
  return result;
}
