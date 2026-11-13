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

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(const Key('orbit-shell')),
    matchesGoldenFile('goldens/$name.png'),
  );
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFont('OrbitSans', [
    'assets/fonts/OrbitSans-Regular.ttf',
    'assets/fonts/OrbitSans-Medium.ttf',
    'assets/fonts/OrbitSans-SemiBold.ttf',
  ]);
  const materialIconsRelativePath =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  var flutterRoot = File(Platform.resolvedExecutable).parent;
  while (flutterRoot.path != '/' &&
      !File('${flutterRoot.path}/$materialIconsRelativePath').existsSync()) {
    flutterRoot = flutterRoot.parent;
  }
  final materialIcons = File('${flutterRoot.path}/$materialIconsRelativePath');
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(
      materialIcons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  await iconLoader.load();

  testWidgets('rendered mail, compose, calendar and tasks surfaces', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 11, 5, 9, 41)), () async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final repository = MemoryAppearanceRepository(
        const AppearanceSettings(
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

      await tester.tap(find.byKey(const Key('orbit-nav-1')));
      await _capture(tester, 'mail_inbox');
      await tester.tap(find.byKey(const Key('email-weekly-plan')));
      await _capture(tester, 'mail_detail');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('orbit-button-Новое письмо')));
      await _capture(tester, 'mail_compose');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('orbit-nav-2')));
      await _capture(tester, 'calendar');
      await tester.tap(find.byKey(const Key('orbit-nav-3')));
      await _capture(tester, 'tasks');
    });
  });
}
