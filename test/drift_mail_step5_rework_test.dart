import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/orbit_bootstrap.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

const _backgroundSample = <int>[0x16, 0x18, 0x2C]; // #16182C
const _referenceSha256 =
    '8b948d674958df4d582557f1d46a5f02540550a2c6ff2361683c0d3374ff983e';

/// Asset bundle that always fails, mirroring a missing/corrupt branding
/// asset so the production decode path's failure branch is exercised.
final class _FailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw StateError('branding asset unavailable in test: $key');
  }
}

final class _DeferredAppearanceRepository implements OrbitAppearanceRepository {
  final completer = Completer<AppearanceSettings>();

  void complete(AppearanceSettings value) => completer.complete(value);

  @override
  Future<AppearanceSettings> load() => completer.future;

  @override
  Future<void> save(AppearanceSettings settings) async {}
}

Future<int> _countNonBackgroundPixels(
  WidgetTester tester,
  Key boundaryKey,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final pixels = bytes.buffer.asUint8List();
  var count = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    final distance = (pixels[i] - _backgroundSample[0]).abs() +
        (pixels[i + 1] - _backgroundSample[1]).abs() +
        (pixels[i + 2] - _backgroundSample[2]).abs();
    if (distance > 40) count++;
  }
  return count;
}

Future<void> _pumpStartupShellDirect(
  WidgetTester tester,
  ui.Image artwork,
) async {
  await tester.pumpWidget(OrbitStartupShell(artwork: artwork));
  await tester.pump();
}

Future<void> _pumpStartupShell(
  WidgetTester tester, {
  _DeferredAppearanceRepository? repository,
  ui.Image? artwork,
}) async {
  final style = OrbitStyleManager(repository ?? MemoryAppearanceRepository());
  final quality = OrbitQualityManager();
  addTearDown(quality.dispose);
  await tester.pumpWidget(
    OrbitBootstrap(
      startup: Stopwatch()..start(),
      style: style,
      quality: quality,
      appState: OrbitAppState(MemoryLocalStateRepository()),
      initializeGraphics: false,
      initializeLocales: false,
      startupArtwork: artwork,
    ),
  );
  await tester.pump();
}

void main() {
  // Live binding: real frames and real async so engine image decodes and
  // RepaintBoundary captures work deterministically in this file.
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    orbitStartupArtworkReady = false;
    orbitStartupShellLoadFailed = false;
  });

  group('STEP5-rework branding & static splash (production decode flow)', () {
    test('[Gate] StartupFrameGate: hold/release pairing is idempotent and '
        'fires each callback exactly once', () {
      var holds = 0;
      var releases = 0;
      final gate = StartupFrameGate(
        onHold: () => holds++,
        onRelease: () => releases++,
      );
      expect(gate.isHeld, isFalse);
      expect(holds, 0);

      gate.hold();
      expect(gate.isHeld, isTrue);
      expect(holds, 1);

      gate.hold(); // idempotent: a second hold is a no-op
      expect(holds, 1);

      gate.release();
      expect(gate.isHeld, isFalse);
      expect(releases, 1);

      gate.release(); // idempotent: a second release is a no-op
      expect(releases, 1, reason: 'allowFirstFrame must never be '
          'over-called — that assertion crashes real launches');
      expect(holds, 1);
    });

    testWidgets('[R1] first rendered frame contains the actual artwork '
        'pixels, not an empty background', (tester) async {
      // Production decode path (decodeBrandingArtworkAsset -> rootBundle ->
      // instantiateImageCodec) against the actual orbit_splash_mark.png.
      final artwork = await tester.runAsync(() => decodeBrandingArtworkAsset());
      expect(artwork, isNotNull);
      await _pumpStartupShellDirect(tester, artwork!);

      final nonBackground = await _countNonBackgroundPixels(
        tester,
        const Key('orbit-startup-shell-mark'),
      );
      // The photorealistic tor + orbit trails occupy a substantial part of
      // the 168 dp square; an empty background frame would have 0.
      expect(nonBackground, greaterThan(2000));
    });

    testWidgets('[R2] no async blank: pre-decode frame is the unified '
        'background; decoded frame carries the actual artwork', (tester) async {
      // Stage 1: no artwork — the shell is the unified background only
      // (the deferred frame is still held; nothing painted yet).
      await tester.pumpWidget(const OrbitStartupShell());
      await tester.pump();
      expect(orbitStartupArtworkReady, isFalse);
      final blankPixels = await _countNonBackgroundPixels(
        tester,
        const Key('orbit-startup-shell-mark'),
      );
      // A small system-overlay/noise share is tolerated on the empty stage;
      // the artwork-free frame must not carry significant content.
      final totalPixels = 168 * 168;
      expect(blankPixels, lessThan(totalPixels * 0.2),
          reason: 'pre-decode frame must be the unified background');

      // Stage 2: the decoded ACTUAL asset in the very first available frame.
      final artwork = await tester.runAsync(() => decodeBrandingArtworkAsset());
      expect(artwork, isNotNull);
      await tester.pumpWidget(OrbitStartupShell(artwork: artwork));
      await tester.pump();
      final nonBackground = await _countNonBackgroundPixels(
        tester,
        const Key('orbit-startup-shell-mark'),
      );
      expect(nonBackground, greaterThan(totalPixels * 0.3),
          reason: 'the first available frame must show the artwork');
    });

    testWidgets('[R3] production decode FAILURE: the frame gate releases, '
        'the error is surfaced and the fallback painter is visible', (
      tester,
    ) async {
      var holds = 0;
      var releases = 0;
      final gate = StartupFrameGate(
        onHold: () => holds++,
        onRelease: () => releases++,
      );
      gate.hold(); // mirrors OrbitBootstrap.initState on real launches

      Object? reportedError;
      ui.Image? readyImage;
      await tester.runAsync(
        () => decodeAndPresentStartupBranding(
          frameGate: gate,
          bundle: _FailingBundle(),
          onArtworkReady: (image) => readyImage = image,
          onArtworkError: (error) => reportedError = error,
        ),
      );
      await tester.pump(); // fires the post-frame gate release

      expect(readyImage, isNull);
      expect(reportedError, isNotNull);
      expect(releases, 1,
          reason: 'a failed asset must release the deferred frame too — '
              'the app must never stay on the held splash');
      expect(gate.isHeld, isFalse);
      // The injected flow owns no global flags; the production bootstrap
      // callback (which sets orbitStartupShellLoadFailed) is not mounted
      // here, so the ready flag must still be untouched.
      expect(orbitStartupArtworkReady, isFalse);

      // The shell with loadError renders the diagnostic fallback painter —
      // a visible, non-blank frame (never an empty screen and no hang).
      await tester.pumpWidget(
        const OrbitStartupShell(loadError: 'branding asset failed in test'),
      );
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(RawImage), findsNothing,
          reason: 'fallback painter replaces the missing artwork');
      final fallbackPixels = await _countNonBackgroundPixels(
        tester,
        const Key('orbit-startup-shell-mark'),
      );
      expect(fallbackPixels, greaterThan(200),
          reason: 'the failure frame must be visible, not blank');
    });

    testWidgets('[R4] readiness unchanged: app mounts, does not hang and '
        'reaches Today after actual loading', (tester) async {
      final repository = _DeferredAppearanceRepository();
      await _pumpStartupShell(
        tester,
        repository: repository,
        artwork: (await tester.runAsync(() => decodeBrandingArtworkAsset()))!,
      );

      expect(find.byKey(const Key('today-greeting')), findsNothing);

      repository.complete(
        const AppearanceSettings(
          profile: OrbitProfile.one,
          quality: OrbitQuality.balanced,
          motionEnabled: true,
        ),
      );
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('orbit-startup-shell')), findsNothing);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
      expect(orbitStartupShellLoadFailed, isFalse,
          reason: 'a normal mount must not trip the failure flag');
    });

    testWidgets('[R5] static only: no periodic frames from branding', (
      tester,
    ) async {
      final artwork = await tester.runAsync(() => decodeBrandingArtworkAsset());
      expect(artwork, isNotNull);
      await _pumpStartupShellDirect(tester, artwork!);

      // Static proof: two captures 2 s apart are byte-identical, i.e. the
      // branding adds no animation controllers or periodic frames.
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('orbit-startup-shell-mark')),
      );
      final first = await boundary.toImage(pixelRatio: 1.0);
      final firstBytes = (await first.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!
          .buffer
          .asUint8List();
      await tester.pump(const Duration(seconds: 2));
      final second = await boundary.toImage(pixelRatio: 1.0);
      final secondBytes = (await second.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!
          .buffer
          .asUint8List();
      expect(secondBytes, firstBytes,
          reason: 'branding must not introduce periodic frame changes');
    });

    test('[R6] provenance: master/splash generated from the approved '
        'reference; density PNGs correct', () {
      final reference = File('tool/branding/orbit_icon_reference.jpg');
      expect(reference.existsSync(), isTrue);
      final referenceBytes = reference.readAsBytesSync();
      final digest = _sha256Hex(referenceBytes);
      expect(
        digest,
        _referenceSha256,
        reason: 'the approved user reference must be used verbatim',
      );

      final master = File('assets/branding/orbit_icon_master.png');
      expect(master.existsSync(), isTrue);
      final masterBytes = master.readAsBytesSync();
      final mWidth = (masterBytes[16] << 24) | (masterBytes[17] << 16) |
          (masterBytes[18] << 8) | masterBytes[19];
      final mHeight = (masterBytes[20] << 24) | (masterBytes[21] << 16) |
          (masterBytes[22] << 8) | masterBytes[23];
      expect(mWidth, 2048);
      expect(mHeight, 2048);

      final splash = File('assets/branding/orbit_splash_mark.png');
      expect(splash.existsSync(), isTrue);
      final splashBytes = splash.readAsBytesSync();
      final sWidth = (splashBytes[16] << 24) | (splashBytes[17] << 16) |
          (splashBytes[18] << 8) | splashBytes[19];
      expect(sWidth, 1024);

      final densities = <String, int>{
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final entry in densities.entries) {
        final file = File(
          'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        );
        expect(file.existsSync(), isTrue);
        final bytes = file.readAsBytesSync();
        final width = (bytes[16] << 24) | (bytes[17] << 16) |
            (bytes[18] << 8) | bytes[19];
        expect(width, entry.value);
      }
    });

    testWidgets('[R7] production decode SUCCESS: actual asset decodes, '
        'artwork is surfaced and the gate releases after the painted frame', (
      tester,
    ) async {
      var holds = 0;
      var releases = 0;
      final gate = StartupFrameGate(
        onHold: () => holds++,
        onRelease: () => releases++,
      );
      gate.hold(); // mirrors OrbitBootstrap.initState on real launches

      ui.Image? readyImage;
      Object? reportedError;
      await tester.runAsync(
        () => decodeAndPresentStartupBranding(
          frameGate: gate,
          onArtworkReady: (image) => readyImage = image,
          onArtworkError: (error) => reportedError = error,
        ),
      );
      await tester.pump(); // fires the post-frame gate release

      expect(reportedError, isNull);
      expect(readyImage, isNotNull);
      // The production asset is the 1024 px rounded splash mark.
      expect(readyImage!.width, 1024);
      expect(readyImage!.height, 1024);
      expect(releases, 1,
          reason: 'the deferred frame must be released once the artwork '
              'frame is painted');
      expect(gate.isHeld, isFalse);
    });
  });
}

/// Compact SHA-256 (FIPS 180-4) so the provenance check needs no extra
/// dependency. Input is hashed as raw bytes.
int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;

List<int> _sha256(List<int> data) {
  const k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  var h = <int>[
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c,
    0x1f83d9ab, 0x5be0cd19,
  ];
  final bitLength = data.length * 8;
  final padded = <int>[...data, 0x80];
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  for (var i = 7; i >= 0; i--) {
    padded.add((bitLength >> (8 * i)) & 0xFF);
  }
  for (var block = 0; block < padded.length; block += 64) {
    final w = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++) {
      w[i] = (padded[block + i * 4] << 24) |
          (padded[block + i * 4 + 1] << 16) |
          (padded[block + i * 4 + 2] << 8) |
          padded[block + i * 4 + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
      final temp1 = (hh + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xFFFFFFFF;
      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xFFFFFFFF;
    }
    h = [
      (h[0] + a) & 0xFFFFFFFF,
      (h[1] + b) & 0xFFFFFFFF,
      (h[2] + c) & 0xFFFFFFFF,
      (h[3] + d) & 0xFFFFFFFF,
      (h[4] + e) & 0xFFFFFFFF,
      (h[5] + f) & 0xFFFFFFFF,
      (h[6] + g) & 0xFFFFFFFF,
      (h[7] + hh) & 0xFFFFFFFF,
    ];
  }
  return h;
}

String _sha256Hex(List<int> bytes) =>
    _sha256(bytes).map((v) => v.toRadixString(16).padLeft(8, '0')).join();
