// Standalone STEP6 evidence generator. NOT part of the default test suite:
// run explicitly with
//   ORBIT_EVIDENCE_OUT_DIR=<abs dir> flutter test tool/dissolve_evidence_test.dart
// Uses the production decode flow and the production dissolve overlay,
// captures deterministic frames at 0% / 35% / 70% / 100% of the 420 ms
// transition (via the debugFrozenProgress hook; 100% is a real completed
// run) and pixel-asserts each state: empty background vs initial artwork vs
// eroding mid states vs completed Today. Writes step6_dissolve_00/35/70/100
// PNGs into the explicitly configured directory (created by this tool).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/orbit_bootstrap.dart';
import 'package:orbit_visual_lab/orbit_startup_dissolve.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

const _backgroundSample = <int>[0x16, 0x18, 0x2C]; // #16182C
const _markRect = (316, 216, 484, 384); // central 168×168 of 800×600
const _readySettings = AppearanceSettings(
  profile: OrbitProfile.one,
  quality: OrbitQuality.balanced,
  motionEnabled: true,
);

final class _DeferredAppearanceRepository implements OrbitAppearanceRepository {
  final completer = Completer<AppearanceSettings>();

  void complete(AppearanceSettings value) => completer.complete(value);

  @override
  Future<AppearanceSettings> load() => completer.future;

  @override
  Future<void> save(AppearanceSettings settings) async {}
}

/// Minimal PNG encoder: truecolour RGB, one filter byte per scanline.
List<int> _encodePng(int width, int height, Uint8List rgba) {
  final raw = <int>[];
  for (var y = 0; y < height; y++) {
    raw.add(0); // filter type none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw.addAll([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  List<int> chunk(String type, List<int> body) {
    final len = body.length;
    final out = <int>[
      (len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF,
    ];
    final typeBytes = type.codeUnits;
    out.addAll(typeBytes);
    out.addAll(body);
    var crc = 0xFFFFFFFF;
    for (final b in [...typeBytes, ...body]) {
      crc ^= b;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
      }
    }
    crc ^= 0xFFFFFFFF;
    out.addAll([
      (crc >> 24) & 0xFF, (crc >> 16) & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF,
    ]);
    return out;
  }

  final ihdr = <int>[
    (width >> 24) & 0xFF, (width >> 16) & 0xFF, (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF, (height >> 16) & 0xFF, (height >> 8) & 0xFF,
    height & 0xFF,
    8, 2, 0, 0, 0, // bit depth 8, colour type 2 (RGB)
  ];
  final zlibData = ZLibEncoder(raw: false).convert(raw);
  final out = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  out.addAll(chunk('IHDR', ihdr));
  out.addAll(chunk('IDAT', zlibData));
  out.addAll(chunk('IEND', const []));
  return out;
}

int _countNonBackground(Uint8List px, (int, int, int, int) rect, int width) {
  final (x0, y0, x1, y1) = rect;
  var count = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * width + x) * 4;
      final d = (px[i] - _backgroundSample[0]).abs() +
          (px[i + 1] - _backgroundSample[1]).abs() +
          (px[i + 2] - _backgroundSample[2]).abs();
      if (d > 40) count++;
    }
  }
  return count;
}

int _countNearWhite(Uint8List px) {
  var count = 0;
  for (var i = 0; i < px.length; i += 4) {
    if (px[i] > 235 && px[i + 1] > 235 && px[i + 2] > 235) count++;
  }
  return count;
}

int _countDifferingInRect(
  Uint8List a,
  Uint8List b,
  (int, int, int, int) rect,
  int width, {
  int tolerance = 15,
}) {
  final (x0, y0, x1, y1) = rect;
  var differing = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * width + x) * 4;
      if ((a[i] - b[i]).abs() > tolerance ||
          (a[i + 1] - b[i + 1]).abs() > tolerance ||
          (a[i + 2] - b[i + 2]).abs() > tolerance) {
        differing++;
      }
    }
  }
  return differing;
}

int _countDiffering(Uint8List a, Uint8List b, {int tolerance = 15}) {
  assert(a.length == b.length);
  var differing = 0;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() > tolerance ||
        (a[i + 1] - b[i + 1]).abs() > tolerance ||
        (a[i + 2] - b[i + 2]).abs() > tolerance) {
      differing++;
    }
  }
  return differing;
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture dissolve frames 0/35/70/100% with pixel assertions',
      (tester) async {
    final outDir = Platform.environment['ORBIT_EVIDENCE_OUT_DIR'];
    expect(outDir, isNotNull,
        reason: 'set ORBIT_EVIDENCE_OUT_DIR=<abs dir> for this tool');
    Directory(outDir!).createSync(recursive: true);

    // Production decode path against the actual orbit_splash_mark.png
    // (deliberate production-path use from the review-evidence tool).
    // ignore: invalid_use_of_visible_for_testing_member
    final artwork = await tester.runAsync(() => decodeBrandingArtworkAsset());
    expect(artwork, isNotNull);

    Future<Uint8List> captureAt(
      double? frozen,
      Key key,
    ) async {
      // Deliberate production-hook use from the review-evidence tool.
      // ignore: invalid_use_of_visible_for_testing_member
      OrbitStartupDissolveOverlay.debugFrozenProgress = frozen;
      final repository = _DeferredAppearanceRepository();
      final style = OrbitStyleManager(repository);
      final quality = OrbitQualityManager();
      addTearDown(quality.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: OrbitBootstrap(
            startup: Stopwatch()..start(),
            style: style,
            quality: quality,
            appState: OrbitAppState(MemoryLocalStateRepository()),
            initializeGraphics: false,
            initializeLocales: false,
            startupArtwork: artwork,
          ),
        ),
      );
      await tester.pump();
      repository.complete(_readySettings);
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return bytes.buffer.asUint8List();
    }

    Future<void> save(String name, Uint8List bytes) async {
      final file = File('$outDir/$name');
      await file.writeAsBytes(_encodePng(800, 600, bytes));
      expect(file.existsSync(), isTrue);
      // ignore: avoid_print
      print('EVIDENCE_WRITTEN: ${file.path} (${file.lengthSync()} bytes)');
    }

    // 0% — pixel-equivalent to the accepted static shell: artwork present,
    // no white flash.
    final frame00 = await captureAt(0.0, const Key('cap-00'));
    final stats00 = _countNonBackground(frame00, _markRect, 800);
    expect(stats00, greaterThan(2000),
        reason: '0%: initial frame carries the actual artwork');
    expect(_countNearWhite(frame00), lessThan(800 * 600 * 0.01),
        reason: '0%: no white flash');
    await save('step6_dissolve_00.png', frame00);

    // 35% of the transition: artwork partially eroded, frame changed vs 0%.
    final frame35 = await captureAt(0.35, const Key('cap-35'));
    final stats35 = _countNonBackground(frame35, _markRect, 800);
    expect(stats35, greaterThan(300),
        reason: '35%: artwork still partially visible');
    expect(_countDiffering(frame00, frame35), greaterThan(300),
        reason: '35%: dissolve visibly progressed');
    await save('step6_dissolve_35.png', frame35);

    // 70% of the transition: the mark region changed substantially again
    // (erosion + fade + particle drift) — Today dominates the frame.
    final frame70 = await captureAt(0.70, const Key('cap-70'));
    final rectChanges = _countDifferingInRect(frame35, frame70, _markRect, 800);
    expect(rectChanges, greaterThan(1000),
        reason: '70%: mask/particles advanced vs 35% in the mark region');
    await save('step6_dissolve_70.png', frame70);

    // 100% — real completed run: overlay removed, only Today remains.
    // Deliberate production-hook use from the review-evidence tool.
    // ignore: invalid_use_of_visible_for_testing_member
    OrbitStartupDissolveOverlay.debugFrozenProgress = null;
    final repository = _DeferredAppearanceRepository();
    final style = OrbitStyleManager(repository);
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('cap-100'),
        child: OrbitBootstrap(
          startup: Stopwatch()..start(),
          style: style,
          quality: quality,
          appState: OrbitAppState(MemoryLocalStateRepository()),
          initializeGraphics: false,
          initializeLocales: false,
          startupArtwork: artwork,
        ),
      ),
    );
    await tester.pump();
    repository.complete(_readySettings);
    await tester.pump(); // _ready: overlay created, controller starts
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(); // completion propagated, overlay removed
    expect(find.byKey(const Key('orbit-startup-dissolve')), findsNothing,
        reason: '100%: overlay removed from the tree');
    expect(find.byKey(const Key('today-greeting')), findsOneWidget);
    final boundary100 = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('cap-100')),
    );
    final image100 = await boundary100.toImage(pixelRatio: 1.0);
    final bytes100 =
        (await image100.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final frame100 = bytes100.buffer.asUint8List();
    expect(_countDiffering(frame00, frame100), greaterThan(800 * 600 * 0.1),
        reason: '100%: Today fully replaced the startup screen');
    // No white flash anywhere in the transition: the overlay can only DIM
    // Today, so 35%/70% must not add bright pixels beyond Today's own
    // content (the sun in the backdrop) plus a small AA margin.
    final todayWhite = _countNearWhite(frame100);
    expect(_countNearWhite(frame35), lessThan(todayWhite + 200),
        reason: '35%: no white flash over Today');
    expect(_countNearWhite(frame70), lessThan(todayWhite + 200),
        reason: '70%: no white flash over Today');
    await save('step6_dissolve_100.png', frame100);

    // Deliberate production-hook use from the review-evidence tool.
    // ignore: invalid_use_of_visible_for_testing_member
    OrbitStartupDissolveOverlay.debugFrozenProgress = null;
  });
}
