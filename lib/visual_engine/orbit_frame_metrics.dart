import 'dart:ui' as ui show FramePhase;

import 'package:flutter/scheduler.dart';

final class OrbitFrameMetrics {
  static const _maxValidDurationMicros = 5000000;

  final List<double> _intervals = <double>[];
  final List<double> _uiTimes = <double>[];
  final List<double> _rasterTimes = <double>[];
  final List<double> _totalSpans = <double>[];
  int? _lastTimestamp;
  int _lastFrameNumber = -1;
  int _acceptedFrames = 0;
  int _rejectedFrames = 0;
  int _rejectedIntervals = 0;
  int _lifecycleGaps = 0;

  void addAll(List<FrameTiming> frames) {
    for (final frame in frames) {
      final timestamp = frame.timestampInMicroseconds(
        ui.FramePhase.rasterFinishWallTime,
      );
      final buildMicros = frame.buildDuration.inMicroseconds;
      final rasterMicros = frame.rasterDuration.inMicroseconds;
      final totalMicros = frame.totalSpan.inMicroseconds;
      if (timestamp <= 0 ||
          buildMicros < 0 ||
          rasterMicros < 0 ||
          totalMicros < 0 ||
          buildMicros > _maxValidDurationMicros ||
          rasterMicros > _maxValidDurationMicros ||
          totalMicros > _maxValidDurationMicros) {
        _rejectedFrames++;
        continue;
      }
      if (frame.frameNumber > 0 && frame.frameNumber <= _lastFrameNumber) {
        _rejectedFrames++;
        continue;
      }
      final previous = _lastTimestamp;
      if (previous != null) {
        final interval = timestamp - previous;
        if (interval > 0 && interval <= _maxValidDurationMicros) {
          _intervals.add(interval / 1000);
        } else if (interval > _maxValidDurationMicros) {
          _lifecycleGaps++;
        } else {
          _rejectedIntervals++;
        }
      }
      if (previous == null || timestamp > previous) {
        _lastTimestamp = timestamp;
      }
      if (frame.frameNumber > 0) _lastFrameNumber = frame.frameNumber;
      _acceptedFrames++;
      _uiTimes.add(buildMicros / 1000);
      _rasterTimes.add(rasterMicros / 1000);
      _totalSpans.add(totalMicros / 1000);
    }
  }

  Map<String, Object?> snapshot({required double refreshRateHz}) {
    final intervalP50 = _percentile(_intervals, 0.5);
    return <String, Object?>{
      'schemaVersion': 2,
      'source':
          'Flutter FrameTiming.rasterFinishWallTime; buildDuration; rasterDuration',
      'status': _acceptedFrames == 0 ? 'NO_VALID_FRAMES' : 'OK',
      'refreshRateHz': refreshRateHz,
      'frameBudgetMs': 1000 / refreshRateHz,
      'acceptedFrameCount': _acceptedFrames,
      'intervalCount': _intervals.length,
      'rejectedFrameCount': _rejectedFrames,
      'rejectedIntervalCount': _rejectedIntervals,
      'lifecycleGapCount': _lifecycleGaps,
      'intervalMs': _distribution(_intervals),
      'uiMs': _distribution(_uiTimes),
      'rasterMs': _distribution(_rasterTimes),
      'totalSpanMs': _distribution(_totalSpans),
      'buildOverBudgetCount': _uiTimes
          .where((value) => value > 1000 / refreshRateHz)
          .length,
      'rasterOverBudgetCount': _rasterTimes
          .where((value) => value > 1000 / refreshRateHz)
          .length,
      'totalSpanOverBudgetCount': _totalSpans
          .where((value) => value > 1000 / refreshRateHz)
          .length,
      'medianPresentedFps': intervalP50 == null || intervalP50 == 0
          ? null
          : 1000 / intervalP50,
      'jankyFrameCount': _intervals
          .where((value) => value > 1000 / refreshRateHz)
          .length,
      'jankyFramePercent': _intervals.isEmpty
          ? null
          : 100 *
                _intervals
                    .where((value) => value > 1000 / refreshRateHz)
                    .length /
                _intervals.length,
    };
  }

  void clearWindow() {
    _intervals.clear();
    _uiTimes.clear();
    _rasterTimes.clear();
    _totalSpans.clear();
    _acceptedFrames = 0;
    _rejectedFrames = 0;
    _rejectedIntervals = 0;
    _lifecycleGaps = 0;
  }

  static Map<String, Object?> _distribution(List<double> values) {
    if (values.isEmpty) {
      return const <String, Object?>{'status': 'NOT MEASURED'};
    }
    return <String, Object?>{
      'p50': _percentile(values, 0.5),
      'p95': _percentile(values, 0.95),
      'p99': _percentile(values, 0.99),
      'min': values.reduce((a, b) => a < b ? a : b),
      'max': values.reduce((a, b) => a > b ? a : b),
    };
  }

  static double? _percentile(List<double> values, double fraction) {
    if (values.isEmpty) return null;
    final ordered = List<double>.of(values)..sort();
    final position = (ordered.length - 1) * fraction;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return ordered[lower];
    return ordered[lower] * (upper - position) +
        ordered[upper] * (position - lower);
  }
}
