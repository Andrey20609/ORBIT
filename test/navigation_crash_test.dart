import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/screens/contacts_screen.dart';
import 'package:orbit_visual_lab/screens/files_screen.dart';
import 'package:orbit_visual_lab/screens/notes_screen.dart';
import 'package:orbit_visual_lab/screens/search_screen.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_mail_account_sheet.dart';
import 'package:orbit_visual_lab/widgets/orbit_page.dart';

Widget createTestApp(Widget child, OrbitAppState appState) {
  final style = OrbitStyleManager(
    MemoryAppearanceRepository(
      const AppearanceSettings(
        profile: OrbitProfile.one,
        atmosphereMode: AtmosphereMode.automatic,
        quality: OrbitQuality.eco,
        motionEnabled: false,
      ),
    ),
  );
  final quality = OrbitQualityManager();
  final palette = OrbitPalette.ofBrightness(OrbitProfile.one, Brightness.dark);
  return OrbitEnvironment(
    style: style,
    quality: quality,
    appState: appState,
    appearanceSettings: style.settings,
    resolvedQuality: quality.resolve(style.settings),
    dataRevision: appState.dataRevision,
    graphicsFallbackReason: null,
    appearancePersistenceError: null,
    appearanceLoadError: null,
    platformBrightness: Brightness.dark,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: palette.themeData(palette.accent),
      home: child,
    ),
  );
}

void main() {
  testWidgets('ContactsScreen, NotesScreen, FilesScreen, SearchScreen mount and render without crash', (tester) async {
    final state = OrbitAppState(MemoryLocalStateRepository());
    await state.load();

    // Test ContactsScreen
    await tester.pumpWidget(createTestApp(const ContactsScreen(), state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ContactsScreen), findsOneWidget);
    expect(find.text('Контакты'), findsOneWidget);

    // Test NotesScreen
    await tester.pumpWidget(createTestApp(const NotesScreen(), state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.text('Заметки'), findsOneWidget);

    // Test FilesScreen
    await tester.pumpWidget(createTestApp(const FilesScreen(), state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FilesScreen), findsOneWidget);
    expect(find.text('Файлы и документы'), findsOneWidget);

    // Test SearchScreen
    await tester.pumpWidget(createTestApp(const SearchScreen(), state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Единый поиск'), findsOneWidget);
  });

  testWidgets('OrbitPage places header in scroll view with ClampingScrollPhysics', (tester) async {
    final state = OrbitAppState(MemoryLocalStateRepository());
    await state.load();

    await tester.pumpWidget(
      createTestApp(
        const OrbitPage(
          title: 'Тест заголовок',
          subtitle: 'Тест подзаголовок',
          body: SizedBox(height: 2000, key: Key('tall-body')),
        ),
        state,
      ),
    );
    await tester.pump();

    final scrollFinder = find.byKey(const Key('orbit-page-scroll'));
    expect(scrollFinder, findsOneWidget);

    final scrollWidget = tester.widget<SingleChildScrollView>(scrollFinder);
    expect(scrollWidget.physics, isA<ClampingScrollPhysics>());
    expect(find.text('Тест заголовок'), findsOneWidget);
  });

  testWidgets('OrbitMailAccountsSheet has fixed close button and dismisses cleanly', (tester) async {
    final state = OrbitAppState(MemoryLocalStateRepository());
    await state.load();
    final palette = OrbitPalette.ofBrightness(OrbitProfile.one, Brightness.dark);

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showOrbitMailAccountsSheet(ctx, palette: palette),
            child: const Text('Open'),
          ),
        ),
        state,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('close-mail-accounts-sheet-btn')), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-mail-accounts-sheet-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('close-mail-accounts-sheet-btn')), findsNothing);
  });
}
