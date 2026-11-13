import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/screens/tasks_screen.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_mail_account_sheet.dart';

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
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('tasks 3-dots button opens tasks menu with sorting and options', (tester) async {
    final appState = OrbitAppState();
    await appState.load();
    await tester.pumpWidget(createTestApp(const TasksScreen(), appState));
    await tester.pumpAndSettle();

    final moreBtn = find.byKey(const Key('tasks-more-button'));
    expect(moreBtn, findsOneWidget);

    await tester.tap(moreBtn);
    await tester.pumpAndSettle();

    expect(find.text('Опции задач'), findsOneWidget);
    expect(find.text('Скрыть выполненные'), findsOneWidget);
    expect(find.text('Отметить все как выполненные'), findsOneWidget);
    expect(find.text('Очистить выполненные задачи'), findsOneWidget);

    // Tap "Отметить все как выполненные"
    await tester.tap(find.text('Отметить все как выполненные'));
    await tester.pumpAndSettle();

    for (final t in appState.tasks) {
      expect(t.done, isTrue);
    }
  });

  testWidgets('floating SnackBarTheme matches visionOS glass specifications', (tester) async {
    final palette = OrbitPalette.ofBrightness(OrbitProfile.one, Brightness.dark);
    final theme = palette.themeData(palette.accent);

    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.snackBarTheme.elevation, 12);
    expect(theme.snackBarTheme.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('OrbitMailAccountsSheet opens and displays account options', (tester) async {
    final appState = OrbitAppState();
    await appState.load();
    final palette = OrbitPalette.ofBrightness(OrbitProfile.one, Brightness.dark);

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showOrbitMailAccountsSheet(ctx, palette: palette),
            child: const Text('Open Accounts'),
          ),
        ),
        appState,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Accounts'));
    await tester.pumpAndSettle();

    expect(find.text('Почтовые аккаунты'), findsOneWidget);
    expect(find.text('Добавить почтовый аккаунт'), findsOneWidget);
  });
}
