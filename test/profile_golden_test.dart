import 'dart:io';

import 'package:clock/clock.dart';
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

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFont('OrbitSans', [
    'assets/fonts/OrbitSans-Regular.ttf',
    'assets/fonts/OrbitSans-Medium.ttf',
    'assets/fonts/OrbitSans-SemiBold.ttf',
  ]);
  await _loadFont('OrbitSerif', [
    'assets/fonts/OrbitSerif-Regular.ttf',
    'assets/fonts/OrbitSerif-Medium.ttf',
  ]);

  // Widget tests do not automatically register Material Icons. Resolve the
  // font from the same Flutter SDK that supplies the active Dart executable.
  const materialIconsRelativePath =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  var flutterRoot = File(Platform.resolvedExecutable).parent;
  while (flutterRoot.path != '/' &&
      !File('${flutterRoot.path}/$materialIconsRelativePath').existsSync()) {
    flutterRoot = flutterRoot.parent;
  }
  final materialIcons = File('${flutterRoot.path}/$materialIconsRelativePath');
  if (!materialIcons.existsSync()) {
    throw StateError('Material Icons font not found: ${materialIcons.path}');
  }
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(
      materialIcons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  await iconLoader.load();

  for (final profile in OrbitProfile.values) {
    testWidgets('rendered Today profile ${profile.name}', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 5, 9, 41)), () async {
        tester.view.physicalSize = const Size(780, 1688);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final repository = MemoryAppearanceRepository(
          AppearanceSettings(
            profile: profile,
            quality: OrbitQuality.eco,
            motionEnabled: false,
          ),
        );
        final style = OrbitStyleManager(repository);
        await style.load();
        final quality = OrbitQualityManager();
        addTearDown(quality.dispose);
        await tester.pumpWidget(
          OrbitVisualLabApp(
            style: style,
            quality: quality,
            appState: OrbitAppState(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();

        expect(find.byKey(const Key('today-greeting')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const Key('orbit-shell')),
          matchesGoldenFile('goldens/today_${profile.name}.png'),
        );
      });
    });
  }
}
