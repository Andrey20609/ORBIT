import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/screens/contact_detail_sheet.dart';
import 'package:orbit_visual_lab/screens/file_detail_sheet.dart';
import 'package:orbit_visual_lab/screens/note_detail_sheet.dart';
import 'package:orbit_visual_lab/services/tasks/task_models.dart';
import 'package:orbit_visual_lab/visual_engine/appearance_settings.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_palette.dart';
import 'package:orbit_visual_lab/widgets/orbit_spatial_surfaces.dart';

import 'orbit_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final palette = OrbitPalette.of(OrbitProfile.one);

  Widget buildSheetHarness(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('visionOS Spatial Glass Surfaces & Filled Buttons', () {
    testWidgets('OrbitSpatialCard renders with specular highlight and child content', (tester) async {
      await tester.pumpWidget(
        buildSheetHarness(
          OrbitSpatialCard(
            palette: palette,
            radius: 20,
            child: const Text('Spatial Content'),
          ),
        ),
      );

      expect(find.text('Spatial Content'), findsOneWidget);
      expect(find.byType(OrbitSpatialCard), findsOneWidget);
    });

    testWidgets('OrbitFilledButton renders with primary gradient and triggers onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSheetHarness(
          OrbitFilledButton(
            palette: palette,
            buttonKey: const Key('test-spatial-btn'),
            icon: Icons.bolt_rounded,
            label: 'Action Label',
            subtitle: 'Action Subtitle',
            badge: 'NEW',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byKey(const Key('test-spatial-btn')), findsOneWidget);
      expect(find.text('Action Label'), findsOneWidget);
      expect(find.text('Action Subtitle'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);

      await tester.tap(find.byKey(const Key('test-spatial-btn')));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('NoteDetailSheet (Task 2)', () {
    testWidgets('allows editing note, adding/removing tags, and converting to task', (tester) async {
      final initialNote = OrbitNoteDetailModel(
        id: 'note_001',
        title: 'Тестовая заметка',
        markdownBody: '# Заголовок\nТекст заметки',
        updatedAt: DateTime.now(),
        tags: const ['дизайн', 'архитектура'],
      );

      CrossEntityLink? generatedLink;

      await tester.pumpWidget(
        buildSheetHarness(
          NoteDetailSheet(
            palette: palette,
            profile: OrbitProfile.one,
            note: initialNote,
            onConvertToTask: (link) => generatedLink = link,
          ),
        ),
      );

      expect(find.text('Заметка Markdown'), findsOneWidget);
      expect(find.text('Тестовая заметка'), findsOneWidget);
      expect(find.text('#дизайн'), findsOneWidget);
      expect(find.text('#архитектура'), findsOneWidget);

      // Convert to task
      await tester.ensureVisible(find.byKey(const Key('note-convert-to-task-button')));
      await tester.tap(find.byKey(const Key('note-convert-to-task-button')));
      await tester.pump();

      expect(generatedLink, isNotNull);
      expect(generatedLink!.sourceType, EntityType.note);
      expect(generatedLink!.targetType, EntityType.task);
      expect(generatedLink!.sourceId, 'note_001');

      // Add a tag
      await tester.enterText(find.byKey(const Key('note-add-tag-input')), 'релиз');
      await tester.tap(find.byKey(const Key('note-add-tag-button')));
      await tester.pump();
      expect(find.text('#релиз'), findsOneWidget);

      // Remove a tag
      await tester.tap(find.bySemanticsLabel('Удалить тег дизайн'));
      await tester.pump();
      expect(find.text('#дизайн'), findsNothing);
    });
  });

  group('ContactDetailSheet (Task 3)', () {
    testWidgets('displays monogram initials, job title, and quick ecosystem actions', (tester) async {
      const contact = OrbitContactDetailModel(
        id: 'c_001',
        fullName: 'Алексей Смирнов',
        email: 'alexey@orbit.io',
        organization: 'ORBIT Core',
        jobTitle: 'Lead Architect',
      );

      await tester.pumpWidget(
        buildSheetHarness(
          const ContactDetailSheet(
            palette: OrbitPalette.one,
            profile: OrbitProfile.one,
            contact: contact,
          ),
        ),
      );

      expect(find.text('АС'), findsOneWidget);
      expect(find.text('Алексей Смирнов'), findsOneWidget);
      expect(find.text('Lead Architect • ORBIT Core'), findsOneWidget);
      expect(find.byKey(const Key('contact-action-mail')), findsOneWidget);
      expect(find.byKey(const Key('contact-action-calendar')), findsOneWidget);
      expect(find.byKey(const Key('contact-action-task')), findsOneWidget);
    });
  });

  group('FileDetailSheet (Task 4)', () {
    testWidgets('displays file metadata, quota ratio progress and attach actions', (tester) async {
      final file = OrbitFileDetailModel(
        id: 'file_001',
        fileName: 'Документ.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 2500000,
        addedAt: DateTime(2026, 11, 10, 14, 0),
        storageUsedBytes: 45000000,
        storageQuotaBytes: 52428800,
      );

      await tester.pumpWidget(
        buildSheetHarness(
          FileDetailSheet(
            palette: OrbitPalette.one,
            profile: OrbitProfile.one,
            file: file,
          ),
        ),
      );

      expect(find.text('Документ.pdf'), findsOneWidget);
      expect(find.text('PDF Документ • 2.38 МБ'), findsOneWidget);
      expect(find.text('Квота хранилища ORBIT Vault'), findsOneWidget);
      expect(find.textContaining('85%'), findsOneWidget);
      expect(find.byKey(const Key('file-attach-to-task-button')), findsOneWidget);
      expect(find.byKey(const Key('file-attach-to-mail-button')), findsOneWidget);
      expect(find.byKey(const Key('file-delete-button')), findsOneWidget);
    });
  });

  group('Full App Integration: TodayScreen & BrainScreen', () {
    testWidgets('TodayScreen provides quick-actions-fab and app-hub-trigger-button', (tester) async {
      await pumpOrbitApp(tester);

      expect(find.byKey(const Key('quick-actions-fab')), findsOneWidget);
      expect(find.byKey(const Key('app-hub-trigger-button')), findsOneWidget);
    });

    testWidgets('BrainScreen displays Live Context, triggers daily plan and clears memory', (tester) async {
      await pumpOrbitApp(tester);

      // Open quick actions then Brain
      await tester.tap(find.byKey(const Key('quick-actions-fab')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ORBIT Brain').last);
      await tester.tap(find.text('ORBIT Brain').last);
      await tester.pumpAndSettle();

      expect(find.text('КОНТЕКСТ ДНЯ'), findsOneWidget);
      expect(find.byKey(const Key('brain-cmd-daily-plan')), findsOneWidget);
      expect(find.byKey(const Key('brain-cmd-mail-summary')), findsOneWidget);
      expect(find.byKey(const Key('brain-cmd-clear-privacy')), findsOneWidget);

      // Trigger daily plan
      await tester.ensureVisible(find.byKey(const Key('brain-cmd-daily-plan')));
      await tester.tap(find.byKey(const Key('brain-cmd-daily-plan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('brain-demo-response')), findsOneWidget);
      expect(find.byKey(const Key('brain-confirm-task-0')), findsOneWidget);

      // Confirm suggested task
      await tester.ensureVisible(find.byKey(const Key('brain-confirm-task-0')));
      await tester.tap(find.byKey(const Key('brain-confirm-task-0')));
      await tester.pumpAndSettle();
      expect(find.text('Задача создана — открыть список задач'), findsOneWidget);

      // Clear privacy memory
      await tester.ensureVisible(find.byKey(const Key('brain-cmd-clear-privacy')));
      await tester.tap(find.byKey(const Key('brain-cmd-clear-privacy')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Контекстный кэш ORBIT Brain полностью очищен'), findsOneWidget);
    });
  });
}
