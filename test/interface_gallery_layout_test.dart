import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  testWidgets('Russian interface gallery fits 320 dp at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final style = OrbitStyleManager(
      MemoryAppearanceRepository(
        const AppearanceSettings(
          quality: OrbitQuality.eco,
          motionEnabled: false,
          languageCode: 'ru',
        ),
      ),
    );
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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orbit-nav-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-Интерфейс')));
    tester
        .widget<ListTile>(find.byKey(const Key('settings-Интерфейс')))
        .onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('interface-gallery')), findsOneWidget);
    expect(find.byKey(const Key('profile-one')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
