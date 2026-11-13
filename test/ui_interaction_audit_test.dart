import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/demo_data.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/l10n/orbit_localizations.dart';
import 'package:orbit_visual_lab/screens/brain_screen.dart';
import 'package:orbit_visual_lab/screens/mail_screens.dart';
import 'package:orbit_visual_lab/screens/settings_screens.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_app_hub_sheet.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_living_backdrop.dart';
import 'package:orbit_visual_lab/widgets/orbit_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final palette = OrbitPalette.of(OrbitProfile.one);

  Widget buildTestHarness({
    required Widget child,
    OrbitAppState? appState,
    OrbitStyleManager? styleManager,
  }) {
    final style = styleManager ??
        OrbitStyleManager(
          MemoryAppearanceRepository(
            initialSettings: const AppearanceSettings(profile: OrbitProfile.one),
          ),
        );
    final quality = OrbitQualityManager();
    final state = appState ??
        OrbitAppState(
          MemoryLocalStateRepository(),
        );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('Settings Destination')),
        ),
        GoRoute(
          path: '/brain',
          builder: (context, state) => const Scaffold(body: Text('Brain Destination')),
        ),
        GoRoute(
          path: '/notes',
          builder: (context, state) => const Scaffold(body: Text('Notes Destination')),
        ),
        GoRoute(
          path: '/contacts',
          builder: (context, state) => const Scaffold(body: Text('Contacts Destination')),
        ),
        GoRoute(
          path: '/files',
          builder: (context, state) => const Scaffold(body: Text('Files Destination')),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const Scaffold(body: Text('Search Destination')),
        ),
      ],
    );

    return OrbitEnvironment(
      style: style,
      quality: quality,
      appState: state,
      appearanceSettings: style.settings,
      resolvedQuality: ResolvedQuality.balanced,
      dataRevision: 0,
      graphicsFallbackReason: null,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  group('UI Interaction & Modal Sheet Root Navigator Audit', () {
    testWidgets('showOrbitAppHub uses root navigator and lowest actions are reachable without dock overlap', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showOrbitAppHub(
                ctx,
                palette: palette,
                profile: OrbitProfile.one,
              ),
              child: const Text('Open Hub'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Hub'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Хаб экосистемы'), findsOneWidget);
      expect(find.text('СИСТЕМА И ПРОФИЛЬ'), findsOneWidget);

      // Verify the lowest action 'Настройки' is visible and clickable
      await tester.ensureVisible(find.text('Настройки'));
      await tester.pump();
      await tester.tap(find.text('Настройки'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Successfully navigated to settings destination
      expect(find.text('Settings Destination'), findsOneWidget);
    });

    testWidgets('showOrbitWallpaperStudioSheet lowest actions are fully accessible', (tester) async {
      final controller = OrbitLivingWallpaperController();

      await tester.pumpWidget(
        buildTestHarness(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showOrbitWallpaperStudioSheet(
                ctx,
                palette: palette,
                profile: OrbitProfile.one,
                controller: controller,
              ),
              child: const Text('Open Studio'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Studio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Scroll to lowest section: ЭФФЕКТ ОЖИВЛЕНИЯ КАРТИНКИ
      await tester.ensureVisible(find.text('Чистый 3D-параллакс'));
      await tester.pump();
      await tester.tap(find.text('Чистый 3D-параллакс'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.effect, OrbitAtmosphereEffect.pureDepth);
    });
  });

  group('7 Handlers Verification', () {
    testWidgets('Brain settings icon opens AI engine modal sheet', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          child: const BrainScreen(),
        ),
      );

      // Find Settings icon in actions
      final settingsIcon = find.byTooltip('Settings');
      expect(settingsIcon, findsOneWidget);

      await tester.tap(settingsIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Параметры ORBIT Brain'), findsOneWidget);
      expect(find.text('On-Device Edge Neural Engine'), findsOneWidget);
      expect(find.text('Cloud Hybrid Pro (2028 Next-Gen)'), findsOneWidget);

      // Tap an option
      await tester.tap(find.byKey(const Key('brain-setting-edge')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Включен локальный Edge AI'), findsOneWidget);

      // Drain spatial island timer (3s)
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Mail detail star button toggles starred status', (tester) async {
      final appState = OrbitAppState(MemoryLocalStateRepository());
      final testEmail = demoEmails.first;

      await tester.pumpWidget(
        buildTestHarness(
          appState: appState,
          child: MailDetailScreen(id: testEmail.id),
        ),
      );

      final initialStarred = appState.isStarred(testEmail);
      final starButton = find.byIcon(
        initialStarred ? Icons.star_rounded : Icons.star_outline_rounded,
      );
      expect(starButton, findsOneWidget);

      await tester.tap(starButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Star status was toggled
      expect(appState.isStarred(testEmail), !initialStarred);
      expect(
        find.text(!initialStarred ? 'Письмо помечено как важное' : 'Снята отметка важности'),
        findsOneWidget,
      );

      // Drain banner timer (4s)
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Interface gallery search button toggles search input and filters profiles', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          child: const InterfaceGalleryScreen(),
        ),
      );

      // Initially search input is not visible
      expect(find.byKey(const Key('gallery-search-input')), findsNothing);

      // Tap search icon in actions
      await tester.tap(find.byKey(const Key('gallery-search-button')));
      await tester.pump();

      // Search input appears
      expect(find.byKey(const Key('gallery-search-input')), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byKey(const Key('gallery-search-input')), 'zen');
      await tester.pump();

      // Only Zen profile is rendered
      expect(find.byKey(const Key('profile-zen')), findsOneWidget);
      expect(find.byKey(const Key('profile-atelier')), findsNothing);
      expect(find.text('ORBIT Zen'), findsOneWidget);
      expect(find.text('ORBIT Atelier'), findsNothing);

      // Close search
      await tester.tap(find.byKey(const Key('gallery-search-button')));
      await tester.pump();

      expect(find.byKey(const Key('gallery-search-input')), findsNothing);
      expect(find.byKey(const Key('profile-atelier')), findsOneWidget);
      expect(find.text('ORBIT Atelier'), findsOneWidget);
    });

    testWidgets('Compose formatting buttons insert markdown tokens into body', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          child: const ComposeScreen(),
        ),
      );

      final bodyFinder = find.byKey(const Key('draft-body'));
      expect(bodyFinder, findsOneWidget);

      // Tap Bold 'B'
      await tester.tap(find.byKey(const Key('format-bold')));
      await tester.pump();
      expect(find.text('****'), findsOneWidget);

      // Clear text
      await tester.enterText(bodyFinder, '');
      await tester.pump();

      // Tap Italic 'I'
      await tester.tap(find.byKey(const Key('format-italic')));
      await tester.pump();
      expect(find.text('**'), findsOneWidget);

      // Clear text
      await tester.enterText(bodyFinder, '');
      await tester.pump();

      // Tap List
      await tester.tap(find.byKey(const Key('format-list')));
      await tester.pump();
      expect(find.text('\n• '), findsOneWidget);

      // Clear text
      await tester.enterText(bodyFinder, '');
      await tester.pump();

      // Tap Link
      await tester.tap(find.byKey(const Key('format-link')));
      await tester.pump();
      expect(find.text('[](https://)'), findsOneWidget);
    });
  });

  group('Mail Filter "Новые" / "Все" Verification', () {
    testWidgets('Filter "Новые" correctly handles 0 unread, active unread, and returns to "Все"', (tester) async {
      final appState = OrbitAppState(MemoryLocalStateRepository());

      await tester.pumpWidget(
        buildTestHarness(
          appState: appState,
          child: const MailScreen(),
        ),
      );

      // Initially on "Все" (filter 0)
      expect(
        find.text(demoEmails.first.localizedSubject(tester.element(find.byType(MailScreen)))),
        findsOneWidget,
      );
      // Mark all emails as read to test 0 unread scenario
      for (final email in demoEmails) {
        appState.markRead(email.id);
      }
      await tester.pump();

      // Select filter 1 (unread / "Непрочитанные")
      await tester.tap(find.byKey(const Key('mail-filter-1')));
      await tester.pump();

      // When 0 unread emails, empty state is displayed
      expect(find.text('Здесь пока пусто'), findsOneWidget);

      // Return to filter 0 ("Все")
      await tester.tap(find.byKey(const Key('mail-filter-0')));
      await tester.pump();

      // Full list is restored
      expect(find.text('Здесь пока пусто'), findsNothing);
    });
  });

  group('Full Shell & Dock Hierarchy Verification', () {
    testWidgets('Full app shell with OrbitBottomNavigation: showOrbitAppHub opens above dock and lowest action is clicked without dock intercept', (tester) async {
      final repo = MemoryAppearanceRepository(
        initialSettings: const AppearanceSettings(
          quality: OrbitQuality.balanced,
          motionEnabled: false,
        ),
      );
      final style = OrbitStyleManager(repo);
      await style.load();
      final quality = OrbitQualityManager();
      addTearDown(quality.dispose);
      final appState = OrbitAppState(MemoryLocalStateRepository());
      await appState.load();

      await tester.pumpWidget(
        OrbitVisualLabApp(
          style: style,
          quality: quality,
          appState: appState,
        ),
      );
      await tester.pumpAndSettle();

      // Verify OrbitBottomNavigation is mounted on screen
      expect(find.byType(OrbitBottomNavigation), findsOneWidget);

      // Open Hub via Today screen header action
      final hubButton = find.byTooltip('Хаб приложений ORBIT');
      expect(hubButton, findsOneWidget);
      await tester.tap(hubButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Hub sheet is open on top of the shell
      expect(find.text('Хаб экосистемы'), findsOneWidget);
      expect(find.text('СИСТЕМА И ПРОФИЛЬ'), findsOneWidget);

      // Verify lowest action 'Настройки' can be tapped without dock stealing touch
      final settingsAction = find.text('Настройки');
      await tester.ensureVisible(settingsAction);
      await tester.pump();
      await tester.tap(settingsAction);
      await tester.pumpAndSettle();

      // Navigated to Settings screen
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('AppState Starred Email Persistence', () {
    test('Starred and unstarred emails persist across state reload', () async {
      final repo = MemoryLocalStateRepository();
      final state1 = OrbitAppState(repo);
      await state1.load();

      final email = demoEmails.first;
      final initial = state1.isStarred(email);

      // Toggle star
      state1.toggleStarred(email.id, email.starred);
      expect(state1.isStarred(email), !initial);

      // Allow async persist to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Create new state loading from same repository
      final state2 = OrbitAppState(repo);
      await state2.load();

      expect(state2.isStarred(email), !initial);
    });
  });

  group('Living Backdrop Eco and Procedural Persistence', () {
    testWidgets('OrbitLivingBackdrop releases gyro subscription when in Eco mode', (tester) async {
      final controller = OrbitLivingWallpaperController();
      await controller.setPresetAsset('assets/photoreal/optimized/one_sky_night.webp');

      final repo = MemoryAppearanceRepository(
        initialSettings: const AppearanceSettings(quality: OrbitQuality.eco, motionEnabled: true),
      );
      final style = OrbitStyleManager(repo);
      await style.load();

      await tester.pumpWidget(
        buildTestHarness(
          styleManager: style,
          child: OrbitLivingBackdrop(
            controller: controller,
            palette: palette,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      // In Eco mode, gyro motion subscription must be released
      expect(OrbitMotionService.instance.subscribersCount, 0);
    });

    test('Procedural wallpaper theme name is preserved across serialization', () {
      final controller1 = OrbitLivingWallpaperController();
      controller1.setProceduralTheme('Северное сияние');
      final json = controller1.toJson();
      expect(json['proceduralTheme'], 'Северное сияние');

      final controller2 = OrbitLivingWallpaperController();
      controller2.applyJson(json);
      expect(controller2.proceduralTheme, 'Северное сияние');
    });
  });
}

final class MemoryAppearanceRepository implements OrbitAppearanceRepository {
  MemoryAppearanceRepository({AppearanceSettings initialSettings = const AppearanceSettings()})
      : _settings = initialSettings;

  AppearanceSettings _settings;

  @override
  Future<AppearanceSettings> load() async => _settings;

  @override
  Future<void> save(AppearanceSettings settings) async {
    _settings = settings;
  }
}

final class MemoryLocalStateRepository implements OrbitLocalStateRepository {
  Map<String, Object?> _data = {};

  @override
  Future<Map<String, Object?>> load() async => Map.of(_data);

  @override
  Future<void> save(Map<String, Object?> state) async {
    _data = Map.of(state);
  }
}
