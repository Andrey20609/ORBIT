import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';
import 'package:orbit_visual_lab/widgets/orbit_rive_mark.dart';
import 'package:rive/rive.dart' as rive;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android renderer, lifecycle and persistence contract', (
    tester,
  ) async {
    // The application entry point performs this initialization in production.
    // Integration tests pump the app directly, so they must initialize the real
    // native runtime explicitly instead of silently accepting Static fallback.
    await rive.RiveNative.init();
    OrbitRiveMark.runtimeAvailable = true;
    OrbitRiveMark.runtimeInitializationError = null;

    final repository = SharedPreferencesAppearanceRepository();
    final style = OrbitStyleManager(repository);
    await style.load();

    // Exercise every persisted field, not only profile and quality. ADB scripts
    // separately cover process death, reboot and APK upgrade without data wipe.
    await style.setProfile(OrbitProfile.atelier);
    await style.setQuality(OrbitQuality.balanced);
    await style.setThemeMode(ThemeMode.dark);
    await style.setAccentColor(const Color(0xFF33CC99));
    await style.setLanguage('de');
    await style.setDensity(OrbitDensity.compact);
    await style.setMotionEnabled(false);
    await style.setRenderer(TodayRenderer.filament);
    await style.setTextScale(1.3);

    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString(
      SharedPreferencesAppearanceRepository.storageKey,
    );
    expect(persisted, isNotNull);
    debugPrint('[ORBIT device] persisted=$persisted');

    final recreated = OrbitStyleManager(
      SharedPreferencesAppearanceRepository(),
    );
    await recreated.load();
    expect(recreated.settings.profile, OrbitProfile.atelier);
    expect(recreated.settings.quality, OrbitQuality.balanced);
    expect(recreated.settings.themeMode, ThemeMode.dark);
    expect(recreated.settings.accentColor, const Color(0xFF33CC99));
    expect(recreated.settings.languageCode, 'de');
    expect(recreated.settings.density, OrbitDensity.compact);
    expect(recreated.settings.motionEnabled, isFalse);
    expect(recreated.settings.renderer, TodayRenderer.filament);
    expect(recreated.settings.textScale, 1.3);

    final appState = OrbitAppState(SharedPreferencesLocalStateRepository());
    await appState.load();
    appState.addTask('ORBIT 0.5 Android persistence');
    appState.addEvent(
      'ORBIT 0.5 Android event',
      '11:45',
      DateTime(2026, 11, 8),
    );
    appState.updateDraft(
      to: 'android@example.demo',
      subject: 'ORBIT 0.5 local draft',
      body: 'Process restart must preserve this draft',
    );
    await appState.flush();
    final recreatedLocal = OrbitAppState(
      SharedPreferencesLocalStateRepository(),
    );
    await recreatedLocal.load();
    expect(
      recreatedLocal.tasks.any(
        (task) => task.title == 'ORBIT 0.5 Android persistence',
      ),
      isTrue,
    );
    expect(
      recreatedLocal.events.any(
        (event) => event.title == 'ORBIT 0.5 Android event',
      ),
      isTrue,
    );
    expect(recreatedLocal.draftTo, 'android@example.demo');
    expect(recreatedLocal.draftSubject, 'ORBIT 0.5 local draft');

    await style.setProfile(OrbitProfile.one);
    await style.setThemeMode(ThemeMode.dark);
    await style.setAccentColor(const Color(0xFF9B8CFF));
    await style.setLanguage('en');
    await style.setDensity(OrbitDensity.comfortable);
    await style.setMotionEnabled(false);
    await style.setRenderer(TodayRenderer.procedural);
    await style.setQuality(OrbitQuality.eco);
    await style.setTextScale(1);

    final quality = OrbitQualityManager();
    await tester.pumpWidget(
      OrbitVisualLabApp(style: style, quality: quality, appState: appState),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    final systemInfo = await const MethodChannel(
      'orbit/system',
    ).invokeMethod<Map<Object?, Object?>>('getSystemInfo');
    debugPrint('[ORBIT device] buildMetadata=$systemInfo');
    expect(systemInfo?['versionName'], '0.5.5');
    expect(systemInfo?['versionCode'], 11);
    expect(systemInfo?['buildFlavor'], 'photoreal-stabilize');
    expect(systemInfo?['gitHash'].toString(), isNotEmpty);

    // A — Static/Eco. The procedural scene must remain present and no native
    // renderer may be created while Eco or motion-disabled fallback is active.
    expect(quality.resolve(style.settings), ResolvedQuality.static);
    expect(find.byType(OrbitPhotorealScene), findsOneWidget);
    expect(find.byType(OrbitRiveMark), findsNothing);
    expect(find.byKey(const Key('filament-native-surface')), findsNothing);
    debugPrint('[ORBIT device] A Static/Eco resolved=static');
    await _capture(tester, 'orbit_static_eco');

    // B — Rive atmosphere. Static stays below it and a tap fires the Pulse
    // trigger when the runtime loaded successfully.
    await style.setQuality(OrbitQuality.balanced);
    await style.setMotionEnabled(true);
    await style.setRenderer(TodayRenderer.rive);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(quality.resolve(style.settings), ResolvedQuality.balanced);
    expect(find.byType(OrbitPhotorealScene), findsOneWidget);
    expect(find.byType(OrbitRiveMark), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('rive-atmosphere')), findsOneWidget);
    debugPrint('[ORBIT device] renderer=${style.settings.renderer}');
    debugPrint(
      '[ORBIT device] experimentHeaders=${find.text('EXPERIMENT B · RIVE').evaluate().length}',
    );
    debugPrint(
      '[ORBIT device] atmosphereRect=${tester.getRect(find.byKey(const Key('rive-atmosphere')))}',
    );
    await tester.tap(
      find.byKey(const Key('rive-atmosphere')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    final riveStats = quality.runtimeDiagnosticsFor('today');
    debugPrint('[ORBIT device] B Rive runtime=$riveStats');
    debugPrint(
      '[ORBIT device] B Rive diagnostics=${quality.graphicsDiagnostics}',
    );
    expect(
      riveStats['actualRenderer'],
      'rive',
      reason: 'Static fallback is not a successful Rive runtime test',
    );
    expect(riveStats['rivLoaded'], isTrue);
    expect(riveStats['artboardReady'], isTrue);
    expect(riveStats['stateMachineReady'], isTrue);
    expect(riveStats['stateMachineAdvancing'], isTrue);
    expect(riveStats['riveAssetLoaded'], isTrue);
    expect(riveStats['nativeArtboardAnimationProven'], isFalse);
    expect(riveStats['flutterTransformActive'], isTrue);
    expect(riveStats['staticFallback'], isFalse);
    expect(
      (riveStats['stateMachineAdvanceCount'] as num? ?? 0),
      greaterThan(0),
    );
    expect(riveStats['pulseAvailable'], isTrue);
    expect((riveStats['pulseCount'] as num? ?? 0), greaterThan(0));
    await _captureNativeWindow(tester, 'orbit_rive_motion_t0', 'rive');
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final advancedRiveStats = quality.runtimeDiagnosticsFor('today');
    debugPrint('[ORBIT device] B Rive elapsed=$advancedRiveStats');
    expect((advancedRiveStats['elapsedSeconds'] as num? ?? 0), greaterThan(1));
    expect(
      (advancedRiveStats['lastAdvanceSeconds'] as num? ?? 0),
      greaterThan(0),
    );
    await _captureNativeWindow(tester, 'orbit_rive_motion_t2', 'rive');
    await _capture(tester, 'orbit_rive_balanced');

    // C — Filament. Native rendering is mandatory for this Android gate.
    // Static fallback is captured as a failure, never relabeled as a 3D PASS.
    await style.setRenderer(TodayRenderer.filament);
    await tester.pump();
    // Frame delta uses wall-clock native evidence, not fake test time.
    await Future<void>.delayed(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OrbitPhotorealScene), findsOneWidget);
    const filamentChannel = MethodChannel('orbit/filament');
    var stats = await _filamentStats(filamentChannel);
    debugPrint('[ORBIT device] C Filament initial stats=$stats');

    final nativeSurface = find.byKey(const Key('filament-native-surface'));
    expect(
      nativeSurface,
      findsOneWidget,
      reason: 'Static fallback is not a successful Filament runtime test',
    );
    expect(stats, isNotEmpty);
    final viewStats = stats.values.first as Map<Object?, Object?>;
    expect(viewStats['initialized'], isTrue);
    expect(viewStats['sceneReady'], isTrue);
    expect(viewStats['hasSwapChain'], isTrue);
    expect((viewStats['renderedFrames'] as num? ?? 0), greaterThan(0));
    expect(viewStats['lastError'], isNull);
    var labStats = quality.runtimeDiagnosticsFor('today');
    for (var attempt = 0; attempt < 15; attempt++) {
      if ((labStats['framesDelta5Seconds'] as num? ?? 0) > 0) break;
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      labStats = quality.runtimeDiagnosticsFor('today');
    }
    expect(labStats['actualRenderer'], 'filament');
    expect((labStats['framesDelta5Seconds'] as num? ?? 0), greaterThan(0));
    final cameraGesture = await tester.startGesture(
      tester.getTopLeft(nativeSurface) + const Offset(30, 100),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await cameraGesture.moveBy(const Offset(120, 0));
    await cameraGesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    stats = await _filamentStats(filamentChannel);
    final gestureStats = stats.values.first as Map<Object?, Object?>;
    expect(
      (gestureStats['cameraInputCount'] as num? ?? 0),
      greaterThan(0),
      reason: 'Real pointer movement must reach the native camera input',
    );
    expect(
      (gestureStats['parallaxX'] as num? ?? 0).abs(),
      greaterThan(0.01),
      reason: 'Drag, not only a stationary tap, must move the camera',
    );
    await _captureNativeWindow(tester, 'orbit_filament_system_t0', 'filament');
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    final motionStats = await _filamentStats(filamentChannel);
    debugPrint('[ORBIT device] C Filament motion stats=$motionStats');
    final motionViewStats = motionStats.values.first as Map<Object?, Object?>;
    final initialEyeX = (viewStats['cameraEyeX'] as num).toDouble();
    final motionEyeX = (motionViewStats['cameraEyeX'] as num).toDouble();
    final initialEyeZ = (viewStats['cameraEyeZ'] as num).toDouble();
    final motionEyeZ = (motionViewStats['cameraEyeZ'] as num).toDouble();
    expect(
      (motionEyeX - initialEyeX).abs() + (motionEyeZ - initialEyeZ).abs(),
      greaterThan(0.01),
      reason: 'Visible camera path must change, not only native frame counters',
    );
    await _captureNativeWindow(tester, 'orbit_filament_system_t2', 'filament');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 700));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    stats = await _filamentStats(filamentChannel);
    debugPrint('[ORBIT device] Filament paused stats=$stats');
    expect(
      stats,
      isEmpty,
      reason: 'Background lifecycle must release native 3D',
    );
    expect(find.byKey(const Key('filament-native-surface')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 700));
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();
    stats = await _filamentStats(filamentChannel);
    debugPrint('[ORBIT device] Filament resumed stats=$stats');
    expect(stats, isNotEmpty);
    final resumedStats = stats.values.first as Map<Object?, Object?>;
    expect(resumedStats['paused'], isFalse);
    expect(resumedStats['initialized'], isTrue);
    expect(resumedStats['sceneReady'], isTrue);
    expect(resumedStats['hasSwapChain'], isTrue);
    expect(
      (resumedStats['renderedFrames'] as num).toInt(),
      greaterThan(0),
      reason: 'A new native scene must render frames after resume',
    );
    await _capture(tester, 'orbit_filament_balanced');

    // Switching away disposes the platform view and releases native resources.
    await style.setRenderer(TodayRenderer.procedural);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('filament-native-surface')), findsNothing);
    stats = await _filamentStats(filamentChannel);
    expect(stats, isEmpty);
    debugPrint('[ORBIT device] Filament release stats=$stats');

    // Explicit lifecycle fallback must remove heavy renderers without blocking
    // the Flutter shell. Low-memory and real Activity pause are in the ADB suite.
    await style.setRenderer(TodayRenderer.rive);
    await tester.pump();
    quality.setAppLifecycle(resumed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(quality.resolve(style.settings), ResolvedQuality.static);
    expect(find.byType(OrbitPhotorealScene), findsOneWidget);
    expect(find.byType(OrbitRiveMark), findsNothing);
    quality.setAppLifecycle(resumed: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Leave Filament selected for the following real onTrimMemory ADB probe.
    await style.setQuality(OrbitQuality.balanced);
    await style.setMotionEnabled(true);
    await style.setRenderer(TodayRenderer.filament);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    debugPrint(
      '[ORBIT device] before low-memory stats=${await _filamentStats(filamentChannel)}',
    );
    await _captureNativeWindow(
      tester,
      'orbit_filament_before_low_memory_system',
      'filament',
    );
    await _capture(tester, 'orbit_before_low_memory');
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  await _captureNativeWindow(tester, name, 'flutter');
}

Future<List<int>> _captureNativeWindow(
  WidgetTester tester,
  String name,
  String requestedRenderer,
) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  debugPrint('[ORBIT device] captureStart=$name');
  await tester.pump(const Duration(milliseconds: 100));
  final bytes = await binding
      .takeScreenshot(name)
      .timeout(const Duration(seconds: 20));
  debugPrint('[ORBIT device] capturePixels=$name bytes=${bytes.length}');
  final file = File('${Directory.systemTemp.path}/$name.png');
  await file.writeAsBytes(bytes, flush: true);
  await const MethodChannel('orbit/qa')
      .invokeMethod<void>('saveScreenshot', {'name': name, 'bytes': bytes})
      .timeout(const Duration(seconds: 20));
  debugPrint(
    '[ORBIT device] integrationScreenshot=$name actualRenderer=$requestedRenderer captureMethod=FlutterSurface',
  );
  return bytes;
}

Future<Map<Object?, Object?>> _filamentStats(MethodChannel channel) async {
  try {
    final value = await channel.invokeMethod<Map<Object?, Object?>>('stats');
    return value ?? <Object?, Object?>{};
  } on MissingPluginException {
    return <Object?, Object?>{};
  } on PlatformException catch (error) {
    debugPrint('[ORBIT device] Filament stats unavailable: $error');
    return <Object?, Object?>{};
  }
}
