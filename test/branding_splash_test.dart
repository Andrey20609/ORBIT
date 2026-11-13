import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/orbit_bootstrap.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

const _brandingAssetPath = 'assets/branding/orbit_splash_mark.png';

final class _DeferredAppearanceRepository implements OrbitAppearanceRepository {
  final completer = Completer<AppearanceSettings>();

  void complete(AppearanceSettings value) => completer.complete(value);

  @override
  Future<AppearanceSettings> load() => completer.future;

  @override
  Future<void> save(AppearanceSettings settings) async {}
}

Future<Uint8List> _loadBrandingBytes() async {
  // The rootBundle in tests resolves against the real project assets.
  final data = await rootBundle.load(_brandingAssetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('STEP5 branding & static splash', () {
    testWidgets(
        'startup shell shows the master mark asset, key kept, no spinner '
        'and no legacy text', (tester) async {
      final repository = _DeferredAppearanceRepository();
      final style = OrbitStyleManager(repository);
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
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('orbit-startup-shell')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == _brandingAssetPath,
          description: 'Image.asset(orbit_splash_mark.png)',
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('ORBIT'), findsNothing);
      // The unified splash background, identical to the native splash.
      final scaffold = tester.widget<Scaffold>(
        find.byKey(const Key('orbit-startup-shell')),
      );
      expect(scaffold.backgroundColor, const Color(0xFF0B1026));

      repository.complete(
        const AppearanceSettings(
          profile: OrbitProfile.one,
          quality: OrbitQuality.balanced,
          motionEnabled: true,
        ),
      );
      // Today keeps ambient animations running, so a fixed pump sequence
      // (not pumpAndSettle) verifies the readiness switch deterministically.
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('orbit-startup-shell')), findsNothing);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
    });

    test('branding asset exists, is a valid alpha PNG and is registered',
        () async {
      final bytes = await _loadBrandingBytes();
      expect(bytes.length, greaterThan(10000));

      // PNG signature.
      expect(bytes.sublist(0, 8),
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      // IHDR: width=1024, height=1024, bit depth 8, colour type 6 (RGBA).
      final width = (bytes[16] << 24) | (bytes[17] << 16) |
          (bytes[18] << 8) | bytes[19];
      final height = (bytes[20] << 24) | (bytes[21] << 16) |
          (bytes[22] << 8) | bytes[23];
      expect(width, 1024);
      expect(height, 1024);
      expect(bytes[24], 8); // bit depth
      expect(bytes[25], 6); // colour type: truecolour with alpha
    });

    testWidgets(
        'Reduce Motion / Eco keep the shell equally static (no animation '
        'controllers introduced by branding)', (tester) async {
      final repository = _DeferredAppearanceRepository();
      final style = OrbitStyleManager(repository);
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
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // No scheduled animation frames from the shell itself: a static
      // subtree leaves the pipeline idle; a CircularProgressIndicator would
      // keep scheduling frames indefinitely. hasScheduledFrame returns true
      // only while something is still asking for frames.
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse,
          reason: 'static shell must not keep scheduling frames');

      repository.complete(
        const AppearanceSettings(
          profile: OrbitProfile.zen,
          quality: OrbitQuality.eco,
          motionEnabled: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
    });




    test('legacy launcher PNGs match required densities', () {
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
        expect(file.existsSync(), isTrue,
            reason: 'missing ${entry.key} launcher icon');
        final bytes = file.readAsBytesSync();
        final width = (bytes[16] << 24) | (bytes[17] << 16) |
            (bytes[18] << 8) | bytes[19];
        final height = (bytes[20] << 24) | (bytes[21] << 16) |
            (bytes[22] << 8) | bytes[23];
        expect(width, entry.value, reason: '${entry.key} width mismatch');
        expect(height, entry.value, reason: '${entry.key} height mismatch');
        // Legacy icons are opaque RGB (no transparent Flutter silhouette).
        expect(bytes[25], 2, reason: '${entry.key} must have an opaque '
            'background (colour type 2)');
      }
    });
  });
}
