import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(390, 844),
    const Size(844, 390),
    const Size(840, 1000),
    const Size(1280, 900),
  ]) {
    testWidgets('main routes fit ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
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
      await tester.pump(const Duration(milliseconds: 80));

      if (size.width >= 840) {
        expect(find.byType(OrbitNavigationRail), findsOneWidget);
        expect(find.byType(OrbitBottomNavigation), findsNothing);
        expect(
          tester
              .widget<OrbitNavigationRail>(find.byType(OrbitNavigationRail))
              .extended,
          size.width >= 1200,
        );
      } else {
        expect(find.byType(OrbitNavigationRail), findsNothing);
        expect(find.byType(OrbitBottomNavigation), findsOneWidget);
      }

      for (var index = 0; index < 5; index++) {
        await tester.tap(find.byKey(Key('orbit-nav-$index')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'Navigation index $index at $size: $exception',
        );
        expect(find.byType(ErrorWidget), findsNothing);
      }
    });
  }
}
