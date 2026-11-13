import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_frame_metrics.dart';

FrameTiming _frame(
  int number,
  double wallMs, {
  double buildMs = 4,
  double rasterMs = 6,
}) {
  return FrameTiming(
    vsyncStart: 0,
    buildStart: 1000,
    buildFinish: 1000 + (buildMs * 1000).round(),
    rasterStart: 2000,
    rasterFinish: 2000 + (rasterMs * 1000).round(),
    rasterFinishWallTime: (wallMs * 1000).round(),
    frameNumber: number,
  );
}

void main() {
  test('uses each frame timestamp and separates UI from raster', () {
    final metrics = OrbitFrameMetrics();
    metrics.addAll([
      _frame(1, 1000, buildMs: 3, rasterMs: 5),
      _frame(2, 1016.6667, buildMs: 5, rasterMs: 7),
      _frame(3, 1033.3334, buildMs: 7, rasterMs: 9),
    ]);
    final snapshot = metrics.snapshot(refreshRateHz: 60);
    expect(snapshot['acceptedFrameCount'], 3);
    expect(snapshot['intervalCount'], 2);
    expect((snapshot['intervalMs'] as Map)['p50'], closeTo(16.6667, 0.001));
    expect((snapshot['uiMs'] as Map)['max'], 7);
    expect((snapshot['rasterMs'] as Map)['max'], 9);
    expect(snapshot['totalSpanMs'], isNotNull);
    expect(snapshot['buildOverBudgetCount'], 0);
    expect(snapshot['rasterOverBudgetCount'], 0);
    expect(snapshot['totalSpanOverBudgetCount'], 0);
    expect(snapshot['medianPresentedFps'], closeTo(60, 0.01));
  });

  test('rejects duplicate, zero and absurd frame records', () {
    final metrics = OrbitFrameMetrics();
    metrics.addAll([
      _frame(1, 1000),
      _frame(1, 1010),
      _frame(2, 0),
      _frame(3, 1020, buildMs: 6000),
      _frame(4, 1030),
    ]);
    final snapshot = metrics.snapshot(refreshRateHz: 60);
    expect(snapshot['acceptedFrameCount'], 2);
    expect(snapshot['rejectedFrameCount'], 3);
    expect(snapshot['intervalCount'], 1);
  });

  test('classifies long lifecycle gaps without inventing frames', () {
    final metrics = OrbitFrameMetrics();
    metrics.addAll([_frame(1, 1000), _frame(2, 11000)]);
    final snapshot = metrics.snapshot(refreshRateHz: 60);
    expect(snapshot['lifecycleGapCount'], 1);
    expect(snapshot['intervalCount'], 0);
    expect((snapshot['intervalMs'] as Map)['status'], 'NOT MEASURED');
  });

  test('clearWindow preserves the clock for the next measurement window', () {
    final metrics = OrbitFrameMetrics();
    metrics.addAll([_frame(1, 1000)]);
    metrics.clearWindow();
    metrics.addAll([_frame(2, 1020)]);
    final snapshot = metrics.snapshot(refreshRateHz: 60);
    expect(snapshot['acceptedFrameCount'], 1);
    expect(snapshot['intervalCount'], 1);
    expect((snapshot['intervalMs'] as Map)['p50'], 20);
  });
}
