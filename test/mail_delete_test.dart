import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  testWidgets(
    'delete email removes from list, persists deletion, and can be restored via snackbar',
    (tester) async {
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
      final appState = OrbitAppState();

      await tester.pumpWidget(
        OrbitVisualLabApp(
          style: style,
          quality: quality,
          appState: appState,
        ),
      );
      await tester.pumpAndSettle();

      // Go to Mail tab
      await tester.tap(find.byKey(const Key('orbit-nav-1')));
      await tester.pumpAndSettle();

      // Verify email exists in inbox
      expect(find.byKey(const Key('email-weekly-plan')), findsOneWidget);

      // Open email
      await tester.tap(find.byKey(const Key('email-weekly-plan')));
      await tester.pumpAndSettle();

      // Verify Delete icon button exists and tap it
      final deleteBtn = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Verify returned to mail list and email is removed
      expect(find.byKey(const Key('email-weekly-plan')), findsNothing);
      expect(appState.isDeleted('weekly-plan'), isTrue);

      // Verify persistence across repository reload (reboot simulation)
      await appState.flush();
      final reloadedState = OrbitAppState(appState.repository);
      await reloadedState.load();
      expect(reloadedState.isDeleted('weekly-plan'), isTrue);

      // Verify snackbar appears with "Отмена" action
      expect(find.text('Письмо удалено'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);

      // Tap "Отмена" to restore email
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      // Email restored
      expect(appState.isDeleted('weekly-plan'), isFalse);
      expect(find.byKey(const Key('email-weekly-plan')), findsOneWidget);

      // Verify restoration persists across repository reload
      await appState.flush();
      final restoredReloadedState = OrbitAppState(appState.repository);
      await restoredReloadedState.load();
      expect(restoredReloadedState.isDeleted('weekly-plan'), isFalse);
    },
  );
}
