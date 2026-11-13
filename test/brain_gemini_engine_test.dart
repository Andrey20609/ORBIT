import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/screens/brain_screen.dart';
import 'package:orbit_visual_lab/services/brain/brain_context_aggregator.dart';
import 'package:orbit_visual_lab/services/brain/brain_engine.dart';
import 'package:orbit_visual_lab/services/brain/brain_tool_caller.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';

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
  group('BrainContextAggregator from AppState', () {
    test('aggregates ecosystem snapshot with verified mail account', () async {
      final appState = OrbitAppState();
      await appState.load();

      final context = BrainContextAggregator.buildFromAppState(appState);
      expect(context['pendingTasksCount'], isNotNull);
      expect(context['unreadEmailsCount'], isNotNull);
      expect(context['activeMailAccount'], isA<Map<String, Object?>>());

      final activeAcc = context['activeMailAccount']! as Map<String, Object?>;
      expect(activeAcc['email'], 'alexey.demo@orbit.local');
      expect(activeAcc['isVerified'], isTrue);
    });
  });

  group('BrainActionProposal on AppState', () {
    test('unapproved action throws StateError', () async {
      final appState = OrbitAppState();
      await appState.load();

      const proposal = BrainActionProposal(
        id: 'prop-unapproved',
        toolName: 'createTask',
        arguments: {'title': 'Тестовая задача'},
        isApproved: false,
      );

      expect(() => proposal.executeOnAppState(appState), throwsA(isA<StateError>()));
    });

    test('approved createTask adds task to OrbitAppState', () async {
      final appState = OrbitAppState();
      await appState.load();
      final initialCount = appState.tasks.length;

      const proposal = BrainActionProposal(
        id: 'prop-task',
        toolName: 'createTask',
        arguments: {'title': 'Подготовить отчёт релиза'},
        isApproved: true,
      );

      final ok = await proposal.executeOnAppState(appState);
      expect(ok, isTrue);
      expect(appState.tasks.length, initialCount + 1);
      expect(appState.tasks.first.title, 'Подготовить отчёт релиза');
    });

    test('approved composeMailDraft updates draft in OrbitAppState', () async {
      final appState = OrbitAppState();
      await appState.load();

      const proposal = BrainActionProposal(
        id: 'prop-draft',
        toolName: 'composeMailDraft',
        arguments: {
          'to': 'security@orbit.local',
          'subject': 'Аудит портов',
          'body': 'Порты 993 и 465 успешно верифицированы.',
        },
        isApproved: true,
      );

      final ok = await proposal.executeOnAppState(appState);
      expect(ok, isTrue);
      expect(appState.draftTo, 'security@orbit.local');
      expect(appState.draftSubject, 'Аудит портов');
      expect(appState.draftBody, contains('успешно верифицированы'));
    });

    test('approved scheduleMeeting adds event to OrbitAppState', () async {
      final appState = OrbitAppState();
      await appState.load();
      final initialEventsCount = appState.events.length;

      const proposal = BrainActionProposal(
        id: 'prop-event',
        toolName: 'scheduleMeeting',
        arguments: {
          'title': 'Демонстрация релиза 0.5.17',
          'time': '17:30',
        },
        isApproved: true,
      );

      final ok = await proposal.executeOnAppState(appState);
      expect(ok, isTrue);
      expect(appState.events.length, initialEventsCount + 1);
      expect(appState.events.last.title, 'Демонстрация релиза 0.5.17');
    });
  });

  group('BrainEngine query & streaming', () {
    const engine = BrainEngine();

    test('generateResponse for plan query yields action proposal', () async {
      final appState = OrbitAppState();
      await appState.load();

      final result = engine.generateResponse(query: 'Составь план на день', appState: appState);
      expect(result.replyText, contains('Сводка контекста'));
      expect(result.actionProposal, isNotNull);
      expect(result.actionProposal!.toolName, 'createTask');
    });

    test('generateResponse for mail query analyzes unread inbox and account', () async {
      final appState = OrbitAppState();
      await appState.load();

      final result = engine.generateResponse(query: 'Проверь почту и письма', appState: appState);
      expect(result.replyText, contains('Анализ почтового ящика'));
      expect(result.replyText, contains('alexey.demo@orbit.local'));
      expect(result.actionProposal, isNotNull);
    });

    test('streamTokens yields progressive chunks to complete string', () async {
      const text = 'ORBIT Brain Gemini на максималках';
      final tokens = <String>[];

      await for (final token in engine.streamTokens(text, delay: Duration.zero)) {
        tokens.add(token);
      }

      expect(tokens, isNotEmpty);
      expect(tokens.last, text);
    });
  });

  group('BrainScreen UI & Gemini Custom Query Integration', () {
    testWidgets('custom query generates response and creates executable action proposal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = OrbitAppState();
      await appState.load();

      await tester.pumpWidget(createTestApp(const BrainScreen(), appState));
      await tester.pumpAndSettle();

      expect(find.text('КОНТЕКСТ ДНЯ'), findsOneWidget);
      expect(find.byKey(const Key('brain-query-input')), findsOneWidget);

      // Enter query to create task
      await tester.enterText(find.byKey(const Key('brain-query-input')), 'Создай задачу для релиза');
      await tester.tap(find.byKey(const Key('brain-send-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('brain-demo-response')), findsOneWidget);
      expect(find.byKey(const Key('brain-confirm-task-0')), findsOneWidget);

      // Ensure visible and tap confirm proposal
      final initialTasksCount = appState.tasks.length;
      await tester.ensureVisible(find.byKey(const Key('brain-confirm-task-0')));
      await tester.tap(find.byKey(const Key('brain-confirm-task-0')));
      await tester.pumpAndSettle();

      expect(appState.tasks.length, initialTasksCount + 1);
      expect(find.text('Задача создана — открыть список задач'), findsOneWidget);
    });
  });
}
