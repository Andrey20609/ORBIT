import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_filament_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('orbit/filament');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('hung native configuration times out into safe Static fallback', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final configure = Completer<Map<Object?, Object?>>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'configure') return configure.future;
      return null;
    });
    final style = OrbitStyleManager(
      MemoryAppearanceRepository(
        const AppearanceSettings(
          quality: OrbitQuality.balanced,
          renderer: TodayRenderer.filament,
        ),
      ),
    );
    await style.load();
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);
    await tester.pumpWidget(
      OrbitEnvironment(
        style: style,
        quality: quality,
        appState: OrbitAppState(),
        appearanceSettings: style.settings,
        resolvedQuality: quality.resolve(style.settings),
        dataRevision: 0,
        graphicsFallbackReason: null,
        child: MaterialApp(
          home: OrbitFilamentScene(
            palette: OrbitPalette.one,
            quality: ResolvedQuality.balanced,
            diagnosticsId: 'timeout-test',
          ),
        ),
      ),
    );
    tester
        .widget<AndroidView>(find.byKey(const Key('filament-native-surface')))
        .onPlatformViewCreated
        ?.call(0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    final stats = quality.runtimeDiagnosticsFor('timeout-test');
    expect(stats['actualRenderer'], 'static');
    expect(stats['nativePending'], isFalse);
    expect(stats['lastError'], contains('timed out'));
    expect(find.byKey(const Key('filament-native-surface')), findsNothing);
    expect(quality.graphicsFallbackReason, contains('Filament'));
    debugDefaultTargetPlatformOverride = null;
  });
}
