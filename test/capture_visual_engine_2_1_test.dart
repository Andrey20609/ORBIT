import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('orbit/motion'), (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('orbit/system'), (call) async => null);
    await _loadFont('OrbitSans', [
      'assets/fonts/OrbitSans-Regular.ttf',
      'assets/fonts/OrbitSans-Medium.ttf',
      'assets/fonts/OrbitSans-SemiBold.ttf',
    ]);
    await _loadFont('OrbitSerif', [
      'assets/fonts/OrbitSerif-Regular.ttf',
      'assets/fonts/OrbitSerif-Medium.ttf',
    ]);

    const materialIconsRelativePath =
        'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    var flutterRoot = File(Platform.resolvedExecutable).parent;
    while (flutterRoot.path != '/' &&
        !File('${flutterRoot.path}/$materialIconsRelativePath').existsSync()) {
      flutterRoot = flutterRoot.parent;
    }
    final materialIcons = File('${flutterRoot.path}/$materialIconsRelativePath');
    if (materialIcons.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(
          materialIcons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await iconLoader.load();
    }
  });

  testWidgets('capture ORBIT One diurnal states and tilt parallax', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final outDir = Directory('d:/Кими/ORBIT_AI_EXCHANGE/03_DELIVERIES_FROM_AUDIT/2026-11-09_ORBIT_0.5.9+15_release/screenshots');
    outDir.createSync(recursive: true);

    final conditions = <({String name, AtmosphereMode atmo, Offset tilt})>[
      (name: 'one_noon_neutral', atmo: AtmosphereMode.day, tilt: Offset.zero),
      (name: 'one_noon_tilt_left', atmo: AtmosphereMode.day, tilt: const Offset(-0.85, 0.1)),
      (name: 'one_noon_tilt_right', atmo: AtmosphereMode.day, tilt: const Offset(0.85, -0.1)),
      (name: 'one_dawn', atmo: AtmosphereMode.dawn, tilt: Offset.zero),
      (name: 'one_sunset', atmo: AtmosphereMode.sunset, tilt: Offset.zero),
      (name: 'one_night', atmo: AtmosphereMode.night, tilt: Offset.zero),
    ];

    for (final cond in conditions) {
      final repo = MemoryAppearanceRepository(
        AppearanceSettings(
          profile: OrbitProfile.one,
          quality: OrbitQuality.balanced,
          motionEnabled: true,
          atmosphereMode: cond.atmo,
          gyroIntensity: GyroIntensity.enhanced,
        ),
      );
      final style = OrbitStyleManager(repo);
      await style.load();
      final quality = OrbitQualityManager();

      OrbitMotionService.instance.reset();
      if (cond.tilt != Offset.zero) {
        OrbitMotionService.instance.setOffsetInstant(cond.tilt);
      }

      await tester.pumpWidget(
        OrbitVisualLabApp(
          style: style,
          quality: quality,
          appState: OrbitAppState(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(find.byKey(const Key('orbit-shell')), findsOneWidget);
      quality.dispose();
    }
  });
}
