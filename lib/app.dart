import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'l10n/app_localizations.dart';

import 'screens/brain_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/files_screen.dart';
import 'screens/mail_screens.dart';
import 'screens/messenger_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screens.dart';
import 'screens/tasks_screen.dart';
import 'screens/today_screen.dart';
import 'screens/visual_lab_screen.dart';
import 'state/app_state.dart';
import 'visual_engine/orbit_visual_engine.dart';
import 'widgets/orbit_environment.dart';
import 'widgets/orbit_living_backdrop.dart';
import 'widgets/orbit_navigation.dart';

final class OrbitVisualLabApp extends StatefulWidget {
  const OrbitVisualLabApp({
    required this.style,
    required this.quality,
    required this.appState,
    super.key,
  });

  final OrbitStyleManager style;
  final OrbitQualityManager quality;
  final OrbitAppState appState;

  @override
  State<OrbitVisualLabApp> createState() => _OrbitVisualLabAppState();
}

final class _OrbitVisualLabAppState extends State<OrbitVisualLabApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  Brightness _platformBrightness = Brightness.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _router = GoRouter(
      initialLocation: '/today',
      debugLogDiagnostics: false,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => OrbitShell(shell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/today', builder: (_, _) => const TodayScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/mail',
                  builder: (_, _) => const MailScreen(),
                  routes: [
                    GoRoute(
                      path: 'message/:id',
                      builder: (_, state) =>
                          MailDetailScreen(id: state.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'compose',
                      builder: (_, _) => const ComposeScreen(),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/calendar',
                  builder: (_, state) => CalendarScreen(
                    openAdd: state.uri.queryParameters['add'] == '1',
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tasks',
                  builder: (_, state) => TasksScreen(
                    openAdd: state.uri.queryParameters['add'] == '1',
                  ),
                  routes: [
                    GoRoute(
                      path: 'task/:id',
                      builder: (_, state) =>
                          TaskDetailScreen(id: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (_, _) => const SettingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'personalization',
                      builder: (_, _) => const PersonalizationScreen(),
                      routes: [
                        GoRoute(
                          path: 'interface',
                          builder: (_, _) => const InterfaceGalleryScreen(),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'lab',
                      builder: (_, _) => const VisualLabScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/event/:id',
          builder: (_, state) =>
              EventDetailScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(path: '/brain', builder: (_, _) => const BrainScreen()),
        GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
        GoRoute(
          path: '/notes',
          builder: (_, state) =>
              NotesScreen(openAdd: state.uri.queryParameters['add'] == '1'),
        ),
        GoRoute(path: '/contacts', builder: (_, _) => const ContactsScreen()),
        GoRoute(path: '/files', builder: (_, _) => const FilesScreen()),
        GoRoute(
          path: '/messenger',
          builder: (context, _) {
            final env = OrbitEnvironment.of(context);
            return MessengerScreen(
              palette: env.palette,
              profile: env.palette.profile,
              onConvertMessageToEntity: (msg, type) {
                if (type == 'task') {
                  env.appState.addTask('${msg.senderName}: ${msg.text}');
                } else if (type == 'meeting') {
                  final now = DateTime.now();
                  env.appState.addEvent(
                    'Встреча: ${msg.senderName}',
                    '${now.hour.toString().padLeft(2, '0')}:00',
                    DateTime(now.year, now.month, now.day),
                  );
                }
              },
            );
          },
        ),
        GoRoute(path: '/', redirect: (_, _) => '/today'),
      ],
      errorBuilder: (_, _) => const _RouteErrorScreen(),
    );
    widget.quality.requestNativeStatus();
    widget.style.addListener(_syncLivingAtmosphere);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncLivingAtmosphere();
    });
  }

  void _syncLivingAtmosphere() {
    unawaited(
      orbitWallpaperController.syncWithAtmosphereMode(
        widget.style.settings.atmosphereMode,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.quality.setAppLifecycle(resumed: state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      widget.quality.requestNativeStatus();
      final current =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (current != _platformBrightness) {
        setState(() => _platformBrightness = current);
      }
    }
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  @override
  void dispose() {
    widget.style.removeListener(_syncLivingAtmosphere);
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.style,
        widget.quality,
        widget.appState,
      ]),
      builder: (context, _) {
        final settings = widget.style.settings;
        final brightness = settings.themeMode == ThemeMode.system
            ? _platformBrightness
            : (settings.themeMode == ThemeMode.light
                  ? Brightness.light
                  : Brightness.dark);
        final lightPalette = OrbitPalette.ofBrightness(
          settings.profile,
          Brightness.light,
        ).withAccent(settings.accentColor);
        final darkPalette = OrbitPalette.ofBrightness(
          settings.profile,
          Brightness.dark,
        ).withAccent(settings.accentColor);
        final activePalette = brightness == Brightness.light
            ? lightPalette
            : darkPalette;
        return OrbitEnvironment(
          style: widget.style,
          quality: widget.quality,
          appState: widget.appState,
          appearanceSettings: settings,
          resolvedQuality: widget.quality.resolve(settings),
          dataRevision: widget.appState.dataRevision,
          graphicsFallbackReason: widget.quality.graphicsFallbackReason,
          appearancePersistenceError: widget.style.lastPersistenceError,
          appearanceLoadError: widget.style.lastLoadError,
          platformBrightness: _platformBrightness,
          child: MaterialApp.router(
            title: 'ORBIT',
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
            theme: lightPalette.themeData(lightPalette.accent),
            darkTheme: darkPalette.themeData(darkPalette.accent),
            themeMode: settings.themeMode,
            locale: Locale(widget.style.settings.languageCode),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (_, child) => _SystemMotionSync(
              quality: widget.quality,
              child: AnimatedTheme(
                data: activePalette.themeData(activePalette.accent),
                duration: OrbitMotionEngine.duration(settings),
                child: Builder(
                  builder: (context) {
                    final query = MediaQuery.of(context);
                    return MediaQuery(
                      data: query.copyWith(
                        textScaler: TextScaler.linear(
                          query.textScaler.scale(1) *
                              widget.style.settings.textScale,
                        ),
                      ),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _SystemMotionSync extends StatefulWidget {
  const _SystemMotionSync({required this.quality, required this.child});
  final OrbitQualityManager quality;
  final Widget child;

  @override
  State<_SystemMotionSync> createState() => _SystemMotionSyncState();
}

final class _SystemMotionSyncState extends State<_SystemMotionSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced != widget.quality.reduceMotion) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.quality.setReduceMotion(reduced);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final class OrbitShell extends StatelessWidget {
  const OrbitShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final useRail = OrbitLayoutEngine.useNavigationRail(context);
    final palette = OrbitEnvironment.of(context).palette;
    void selectBranch(int index) {
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      shell.goBranch(index, initialLocation: index == shell.currentIndex);
    }

    final scaffold = Scaffold(
      key: const Key('orbit-shell'),
      extendBody: !useRail,
      backgroundColor: Colors.transparent,
      body: useRail
          ? Row(
              children: [
                OrbitNavigationRail(
                  index: shell.currentIndex,
                  onChanged: selectBranch,
                  extended: MediaQuery.sizeOf(context).width >= 1200,
                ),
                Expanded(child: shell),
              ],
            )
          : shell,
      bottomNavigationBar: useRail
          ? null
          : OrbitBottomNavigation(
              index: shell.currentIndex,
              onChanged: selectBranch,
            ),
    );

    return OrbitLivingBackdrop(
      controller: orbitWallpaperController,
      palette: palette,
      child: scaffold,
    );
  }
}

final class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    final palette = OrbitEnvironment.of(context).palette;
    return OrbitSceneBackground(
      palette: palette,
      quality: ResolvedQuality.static,
      motionEnabled: false,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).routeNotFound,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(AppLocalizations.of(context).routeStateSaved),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.go('/today'),
                  child: Text(AppLocalizations.of(context).today),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
