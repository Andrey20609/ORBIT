import 'package:clock/clock.dart';

/// The four canonical periods of the diurnal day used for contextual greetings
/// and automatic atmospheric synchronization.
///
/// Intervals:
/// - [morning] : 05:00 — 11:59:59.999
/// - [day]     : 12:00 — 16:59:59.999
/// - [evening] : 17:00 — 22:59:59.999
/// - [night]   : 23:00 — 04:59:59.999
enum OrbitDayPeriod {
  morning,
  day,
  evening,
  night;

  /// Resolves the canonical [OrbitDayPeriod] for a given [dateTime].
  static OrbitDayPeriod fromDateTime(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 5 && hour < 12) {
      return OrbitDayPeriod.morning;
    } else if (hour >= 12 && hour < 17) {
      return OrbitDayPeriod.day;
    } else if (hour >= 17 && hour < 23) {
      return OrbitDayPeriod.evening;
    } else {
      return OrbitDayPeriod.night;
    }
  }

  /// Resolves the current [OrbitDayPeriod] according to local device time.
  static OrbitDayPeriod current() => fromDateTime(clock.now());
}
