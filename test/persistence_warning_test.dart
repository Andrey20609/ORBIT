import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  testWidgets('save failure shows a retry warning and clears after success', (
    tester,
  ) async {
    final localRepository = MemoryLocalStateRepository()..failNextSave = true;
    final appState = OrbitAppState(localRepository);
    await appState.load();
    final style = OrbitStyleManager(
      MemoryAppearanceRepository(
        const AppearanceSettings(
          quality: OrbitQuality.eco,
          motionEnabled: false,
        ),
      ),
    );
    await style.load();
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);
    await tester.pumpWidget(
      OrbitVisualLabApp(style: style, quality: quality, appState: appState),
    );
    await tester.pump();
    appState.addTask('Проверить уведомление');
    await tester.pump();

    expect(find.byKey(const Key('persistence-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('persistence-retry')));
    await tester.pump();

    expect(find.byKey(const Key('persistence-retry')), findsNothing);
    expect(appState.lastPersistenceError, isNull);
    expect(localRepository.saveCount, 1);
  });
}
