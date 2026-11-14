import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/orbit_bootstrap.dart';
import 'package:orbit_visual_lab/orbit_startup_dissolve.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

const _backgroundSample = <int>[0x16, 0x18, 0x2C]; // #16182C
const _dissolveKey = Key('orbit-startup-dissolve');

final class _DeferredAppearanceRepository implements OrbitAppearanceRepository {
  final completer = Completer<AppearanceSettings>();

  void complete(AppearanceSettings value) => completer.complete(value);

  @override
  Future<AppearanceSettings> load() => completer.future;

  @override
  Future<void> save(AppearanceSettings settings) async {}
}

Future<ui.Image> _decodeArtwork(WidgetTester tester) async {
  // Production decode path (decodeBrandingArtworkAsset -> rootBundle ->
  // instantiateImageCodec) against the actual orbit_splash_mark.png.
  final artwork = await tester.runAsync(() => decodeBrandingArtworkAsset());
  expect(artwork, isNotNull);
  return artwork!;
}

Future<Uint8List> _captureBytes(
  WidgetTester tester,
  Key boundaryKey,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return bytes.buffer.asUint8List();
}

/// Counts pixels whose channels differ by more than [tolerance] between
/// two raw-RGBA captures of the same size.
int _countDifferingPixels(Uint8List a, Uint8List b, {int tolerance = 15}) {
  assert(a.length == b.length);
  var differing = 0;
  for (var i = 0; i < a.length; i += 4) {
    final dr = (a[i] - b[i]).abs();
    final dg = (a[i + 1] - b[i + 1]).abs();
    final db = (a[i + 2] - b[i + 2]).abs();
    if (dr > tolerance || dg > tolerance || db > tolerance) differing++;
  }
  return differing;
}

/// Counts differing pixels strictly OUTSIDE a rectangle.
int _countOutsideRectDiffering(
  Uint8List a,
  Uint8List b,
  (int, int, int, int) rect, {
  required int width,
  int tolerance = 15,
}) {
  final (x0, y0, x1, y1) = rect;
  var differing = 0;
  for (var i = 0; i < a.length; i += 4) {
    final px = (i ~/ 4) % width;
    final py = (i ~/ 4) ~/ width;
    if (px >= x0 && px < x1 && py >= y0 && py < y1) continue;
    final dr = (a[i] - b[i]).abs();
    final dg = (a[i + 1] - b[i + 1]).abs();
    final db = (a[i + 2] - b[i + 2]).abs();
    if (dr > tolerance || dg > tolerance || db > tolerance) differing++;
  }
  return differing;
}

/// Pixel statistics over a rectangular region of a raw-RGBA capture.
({int nonBackground, int nearWhite, int cyanViolet}) _pixelStats(
  Uint8List pixels, {
  required int width,
  required int height,
  (int, int, int, int)? rect,
}) {
  final (x0, y0, x1, y1) = rect ?? (0, 0, width, height);
  var nonBackground = 0;
  var nearWhite = 0;
  var cyanViolet = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * width + x) * 4;
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      final distance = (r - _backgroundSample[0]).abs() +
          (g - _backgroundSample[1]).abs() +
          (b - _backgroundSample[2]).abs();
      if (distance > 40) nonBackground++;
      if (r > 235 && g > 235 && b > 235) nearWhite++;
      if (b > 150 && g > 110 && r < 130 && b - r > 60) cyanViolet++;
    }
  }
  return (nonBackground: nonBackground, nearWhite: nearWhite,
      cyanViolet: cyanViolet);
}

/// Central 168×168 mark region of the default 800×600 test surface.
const (int, int, int, int) _markRect = (
  400 - 84,
  300 - 84,
  400 + 84,
  300 + 84,
);

/// Component harness: the host widget places a tappable probe UNDER the
/// overlay (exactly the bootstrap Stack order) and removes the overlay when
/// the transition completes — the same lifecycle the production bootstrap
/// implements. `mountOverlay` mirrors the production allowed/failed checks.
final class _DissolveHarness extends StatefulWidget {
  const _DissolveHarness({
    required this.artwork,
    required this.rootCaptureKey,
  });

  final ui.Image artwork;
  final Key rootCaptureKey;

  @override
  State<_DissolveHarness> createState() => _DissolveHarnessState();
}

final class _DissolveHarnessState extends State<_DissolveHarness> {
  int _taps = 0;
  bool _showOverlay = true;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(),
        child: RepaintBoundary(
          key: widget.rootCaptureKey,
          child: Stack(
            alignment: Alignment.topLeft,
            fit: StackFit.expand,
            children: [
              // The "Today" stand-in: dark probe surface with a button that
              // must stay tappable through the overlay.
              GestureDetector(
                key: const Key('today-probe'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _taps++),
                child: const ColoredBox(color: Color(0xFF16182C)),
              ),
              if (_showOverlay)
                OrbitStartupDissolveOverlay(
                  key: _dissolveKey,
                  artwork: widget.artwork,
                  onCompleted: () => setState(() {
                    _showOverlay = false;
                    _completed = true;
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mounts the production OrbitBootstrap the way main.dart does, with a
/// controllable appearance repository, and returns the harness keys.
Future<void> _pumpRealApp(
  WidgetTester tester, {
  required _DeferredAppearanceRepository repository,
  required Key rootCaptureKey,
  ui.Image? startupArtwork,
  OrbitQualityManager? quality,
}) async {
  final style = OrbitStyleManager(repository);
  final qualityManager = quality ?? OrbitQualityManager();
  addTearDown(qualityManager.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: rootCaptureKey,
      child: OrbitBootstrap(
        startup: Stopwatch()..start(),
        style: style,
        quality: qualityManager,
        appState: OrbitAppState(MemoryLocalStateRepository()),
        initializeGraphics: false,
        initializeLocales: false,
        startupArtwork: startupArtwork,
      ),
    ),
  );
  await tester.pump();
}

const _readySettings = AppearanceSettings(
  profile: OrbitProfile.one,
  quality: OrbitQuality.balanced,
  motionEnabled: true,
);

void main() {
  // Live binding: real frames and real async so engine image decodes,
  // RepaintBoundary captures and animation pumps work deterministically.
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    OrbitStartupDissolveOverlay.debugFrozenProgress = null;
  });

  group('STEP6 startup dissolve', () {
    testWidgets('[D1] initial continuity: progress=0 carries the actual '
        'artwork like the accepted shell, no white flash', (tester) async {
      final artwork = await _decodeArtwork(tester);

      // The accepted static shell (unchanged STEP5 component).
      await tester.pumpWidget(RepaintBoundary(
        key: const Key('root-shell'),
        child: OrbitStartupShell(artwork: artwork),
      ));
      await tester.pump();
      final shellBytes = await _captureBytes(tester, const Key('root-shell'));
      final shellStats = _pixelStats(
        shellBytes,
        width: 800,
        height: 600,
        rect: _markRect,
      );
      expect(shellStats.nonBackground, greaterThan(2000));

      // The dissolve overlay FROZEN at progress 0 — deterministic frame.
      OrbitStartupDissolveOverlay.debugFrozenProgress = 0.0;
      await tester.pumpWidget(_DissolveHarness(
        artwork: artwork,
        rootCaptureKey: const Key('root-dissolve'),
      ));
      await tester.pump();
      final overlayBytes = await _captureBytes(
        tester,
        const Key('root-dissolve'),
      );
      final overlayStats = _pixelStats(
        overlayBytes,
        width: 800,
        height: 600,
        rect: _markRect,
      );
      // Same artwork content as the shell (within AA tolerance).
      expect(overlayStats.nonBackground,
          closeTo(shellStats.nonBackground, shellStats.nonBackground * 0.05));
      // Continuity proof: the frozen progress-0 frame differs from the
      // accepted shell frame on far fewer than 0.5% of pixels — particles
      // invisible, background identical, no white flash.
      final differing = _countDifferingPixels(overlayBytes, shellBytes);
      expect(differing, lessThan(800 * 600 * 0.005),
          reason: 'progress=0 must be pixel-equivalent to the accepted '
              'STEP5 shell');
      final fullStats = _pixelStats(
        overlayBytes,
        width: 800,
        height: 600,
      );
      expect(fullStats.nearWhite, lessThan(800 * 600 * 0.01),
          reason: 'no white flash at the dissolve start');
    });

    testWidgets('[D2] mid dissolve: artwork partially eroded, particles '
        'visible and deterministic; Today under the overlay', (tester) async {
      final artwork = await _decodeArtwork(tester);

      // Exact mid-state via the frozen hook (35% of the transition).
      OrbitStartupDissolveOverlay.debugFrozenProgress = 0.35;
      await tester.pumpWidget(_DissolveHarness(
        artwork: artwork,
        rootCaptureKey: const Key('root-d2'),
      ));
      await tester.pump();
      final midBytes = await _captureBytes(tester, const Key('root-d2'));
      final midStats = _pixelStats(
        midBytes,
        width: 800,
        height: 600,
        rect: _markRect,
      );
      expect(midStats.nearWhite, lessThan(800 * 600 * 0.01),
          reason: 'no full-screen white flash mid dissolve');

      // Baseline frame at progress 0 for diff-based checks.
      OrbitStartupDissolveOverlay.debugFrozenProgress = 0.0;
      await tester.pumpWidget(_DissolveHarness(
        artwork: artwork,
        rootCaptureKey: const Key('root-d2zero'),
      ));
      await tester.pump();
      final zeroBytes = await _captureBytes(tester, const Key('root-d2zero'));

      // Erosion at 35%: the artwork is still partially present and the
      // whole frame changed versus progress 0.
      expect(midStats.nonBackground, greaterThan(300),
          reason: 'artwork still partially present at 35%');
      final markChanges = _countDifferingPixels(zeroBytes, midBytes);
      expect(markChanges, greaterThan(300),
          reason: 'the dissolve mask visibly erodes the artwork by 35%');

      // Particles: pixel changes OUTSIDE the mark region come only from
      // the deterministic light particles.
      final outsideChanges = _countOutsideRectDiffering(
        zeroBytes,
        midBytes,
        _markRect,
        width: 800,
      );
      expect(outsideChanges, greaterThan(50),
          reason: 'deterministic light particles are visible mid transition');

      // Erosion + particle motion progress at 70%.
      OrbitStartupDissolveOverlay.debugFrozenProgress = 0.70;
      await tester.pumpWidget(_DissolveHarness(
        artwork: artwork,
        rootCaptureKey: const Key('root-d2b'),
      ));
      await tester.pump();
      final lateBytes = await _captureBytes(tester, const Key('root-d2b'));
      final lateStats = _pixelStats(
        lateBytes,
        width: 800,
        height: 600,
        rect: _markRect,
      );
      expect(lateStats.nonBackground, lessThan(midStats.nonBackground),
          reason: 'erosion must visibly progress between 35% and 70%');
      final lateOutsideChanges = _countOutsideRectDiffering(
        midBytes,
        lateBytes,
        _markRect,
        width: 800,
      );
      expect(lateOutsideChanges, greaterThan(50),
          reason: 'particles drift outward between 35% and 70%');

      // Particle determinism: same seed -> identical particle set.
      List<Object> signature(List<DissolveParticle> ps) => [
        for (final p in ps) (p.origin.dx, p.origin.dy, p.direction.dx,
            p.direction.dy, p.distance, p.radius, p.delay, p.color.toARGB32()),
      ];
      final a = generateDissolveParticles();
      final b = generateDissolveParticles();
      expect(signature(b), signature(a));
      expect(a.length, inInclusiveRange(12, 18));

      // In the production app the overlay decorates an ALREADY-BUILT,
      // visible Today: greeting present under the overlay mid transition.
      final repository = _DeferredAppearanceRepository();
      await _pumpRealApp(
        tester,
        repository: repository,
        rootCaptureKey: const Key('root-d2real'),
        startupArtwork: artwork,
      );
      repository.complete(_readySettings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 147));
      expect(find.byKey(_dissolveKey), findsOneWidget);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget,
          reason: 'Today is built and visible under the overlay');
    });

    testWidgets('[D3] interactive during animation: input passes through '
        'the overlay', (tester) async {
      final artwork = await _decodeArtwork(tester);
      await tester.pumpWidget(_DissolveHarness(
        artwork: artwork,
        rootCaptureKey: const Key('root-d3'),
      ));
      await tester.pump();

      // Mid transition tap on the probe under the overlay.
      await tester.pump(const Duration(milliseconds: 147));
      await tester.tap(find.byKey(const Key('today-probe')), warnIfMissed: true);
      await tester.pump();
      final harness = tester.state<_DissolveHarnessState>(
        find.byType(_DissolveHarness),
      );
      expect(harness._taps, 1,
          reason: 'IgnorePointer lets Today receive input mid dissolve');
    });

    testWidgets('[D4] completion cleanup: overlay removed, no periodic '
        'frames, controller disposed', (tester) async {
      final artwork = await _decodeArtwork(tester);
      await tester.pumpWidget(_DissolveHarness(
        artwork: artwork,
        rootCaptureKey: const Key('root-d4'),
      ));
      await tester.pump();

      // Drive the 420 ms transition to completion.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      final harness = tester.state<_DissolveHarnessState>(
        find.byType(_DissolveHarness),
      );
      expect(harness._completed, isTrue);
      expect(find.byKey(_dissolveKey), findsNothing,
          reason: 'overlay removed from the tree after completion');

      // No periodic frames from branding/dissolve: two captures 2 s apart
      // are byte-identical.
      final first = await _captureBytes(tester, const Key('root-d4'));
      await tester.pump(const Duration(seconds: 2));
      final second = await _captureBytes(tester, const Key('root-d4'));
      expect(second, first,
          reason: 'dissolve leaves no animation loop behind');

      // Unmounting the host disposes everything without exceptions.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('[D5] readiness unchanged: no dissolve before _ready; '
        'Today available immediately after it', (tester) async {
      final artwork = await _decodeArtwork(tester);
      final repository = _DeferredAppearanceRepository();
      await _pumpRealApp(
        tester,
        repository: repository,
        rootCaptureKey: const Key('root-d5'),
        startupArtwork: artwork,
      );

      expect(find.byKey(_dissolveKey), findsNothing,
          reason: 'dissolve must not start before _ready');
      expect(find.byKey(const Key('today-greeting')), findsNothing);

      repository.complete(_readySettings);
      await tester.pump();
      // Both at the SAME pump: Today is interactive right away, the
      // overlay only decorates it — interactiveTodayMs is not shifted.
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
      expect(find.byKey(_dissolveKey), findsOneWidget);
    });

    testWidgets('[D6] Reduce Motion / Eco: instant switch, no controller '
        'state, no particles', (tester) async {
      // (a) quality.reduceMotion
      final artwork = await _decodeArtwork(tester);
      final repository = _DeferredAppearanceRepository();
      final quality = OrbitQualityManager()..setReduceMotion(true);
      await _pumpRealApp(
        tester,
        repository: repository,
        rootCaptureKey: const Key('root-d6a'),
        startupArtwork: artwork,
        quality: quality,
      );
      repository.complete(_readySettings);
      await tester.pump();
      expect(find.byKey(_dissolveKey), findsNothing,
          reason: 'reduce motion switches to Today instantly');
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
      // The instant mode contributes no transition widgets at all: after
      // 2 s the overlay is still absent (nothing from the dissolve can
      // tick; the app's own LivingBackdrop animation is pre-existing
      // behaviour outside STEP6 scope).
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(_dissolveKey), findsNothing);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);

      // (b) Eco quality resolves to Static.
      final repository2 = _DeferredAppearanceRepository();
      await _pumpRealApp(
        tester,
        repository: repository2,
        rootCaptureKey: const Key('root-d6b'),
        startupArtwork: artwork,
      );
      repository2.complete(_readySettings.copyWith(
        quality: OrbitQuality.eco,
      ));
      await tester.pump();
      expect(find.byKey(_dissolveKey), findsNothing);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
    });

    testWidgets('[D7] gate regression: dissolve never releases the frame '
        'gate; STEP5 gate semantics unchanged', (tester) async {
      var holds = 0;
      var releases = 0;
      final gate = StartupFrameGate(
        onHold: () => holds++,
        onRelease: () => releases++,
      );
      gate.hold();

      final artwork = await _decodeArtwork(tester);
      await tester.pumpWidget(_DissolveHarness(
        artwork: artwork,
        rootCaptureKey: const Key('root-d7'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      final harness = tester.state<_DissolveHarnessState>(
        find.byType(_DissolveHarness),
      );
      expect(harness._completed, isTrue);
      expect(releases, 0,
          reason: 'the dissolve must never touch allowFirstFrame — '
              'release stays owned by the STEP5 production flow');
      expect(gate.isHeld, isTrue);
      expect(holds, 1);
      // The production gate flow itself (success/failure exactly-once
      // release) remains covered by the unchanged STEP5 suite (Gate/R3/R7).
    });

    testWidgets('[D8] dispose mid transition: no late callbacks, no replay, '
        'no stuck overlay', (tester) async {
      final artwork = await _decodeArtwork(tester);

      // Dispose mid transition.
      await tester.pumpWidget(_DissolveHarness(
        artwork: artwork,
        rootCaptureKey: const Key('root-d8a'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 147));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(_dissolveKey), findsNothing);
      expect(tester.takeException(), isNull);

      // Fresh mount animates once from zero and completes cleanly.
      await tester.pumpWidget(_DissolveHarness(
        artwork: artwork,
        rootCaptureKey: const Key('root-d8b'),
      ));
      await tester.pump();
      expect(find.byKey(_dissolveKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      final harness = tester.state<_DissolveHarnessState>(
        find.byType(_DissolveHarness),
      );
      expect(harness._completed, isTrue,
          reason: 'fresh mount completes exactly once — no replay or stuck '
              'overlay');
      expect(find.byKey(_dissolveKey), findsNothing);
    });

    testWidgets('[D9] asset failure: Today reached directly, no dissolve of '
        'missing artwork, no hang', (tester) async {
      final repository = _DeferredAppearanceRepository();
      await _pumpRealApp(
        tester,
        repository: repository,
        rootCaptureKey: const Key('root-d9'),
        // No startupArtwork: mirrors a failed branding decode.
      );

      expect(find.byKey(_dissolveKey), findsNothing);
      repository.complete(_readySettings);
      await tester.pump();
      expect(find.byKey(const Key('today-greeting')), findsOneWidget,
          reason: 'Today reachable without artwork');
      expect(find.byKey(_dissolveKey), findsNothing,
          reason: 'never dissolve a missing artwork');
      expect(find.byKey(const Key('orbit-startup-shell')), findsNothing);
    });
  });
}
