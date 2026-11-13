import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  testWidgets(
    'reply all, forward and disabled formatting have explicit DEMO semantics',
    (tester) async {
      final style = OrbitStyleManager(
        MemoryAppearanceRepository(
          const AppearanceSettings(
            quality: OrbitQuality.eco,
            motionEnabled: false,
            languageCode: 'en',
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
      await tester.tap(find.byKey(const Key('orbit-nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('email-weekly-plan')));
      await tester.pumpAndSettle();

      String draftValue(Key key) => tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(TextField),
              matchRoot: true,
            ),
          )
          .controller!
          .text;

      await tester.ensureVisible(find.byKey(const Key('reply-all-button')));
      await tester.tap(find.byKey(const Key('reply-all-button')));
      await tester.pumpAndSettle();
      expect(
        draftValue(const Key('draft-to')),
        contains('orbit-team@example.demo'),
      );
      expect(draftValue(const Key('draft-subject')), startsWith('Re:'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('forward-button')));
      await tester.tap(find.byKey(const Key('forward-button')));
      await tester.pumpAndSettle();
      expect(draftValue(const Key('draft-to')), isEmpty);
      expect(draftValue(const Key('draft-subject')), startsWith('Fwd:'));
      expect(
        draftValue(const Key('draft-body')),
        contains('Forwarded demo email'),
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('formatting-disabled')))
            .onPressed,
        isNull,
      );
    },
  );
}
