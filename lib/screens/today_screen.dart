import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/demo_data.dart';
import '../l10n/orbit_localizations.dart';
import '../visual_engine/orbit_visual_engine.dart';
import '../widgets/event_list.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_app_hub_sheet.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_filament_scene.dart';
import '../widgets/orbit_living_backdrop.dart';
import '../widgets/orbit_logo.dart';
import '../widgets/orbit_page.dart';
import '../widgets/orbit_persistence_warning.dart';
import '../widgets/orbit_photoreal_scene.dart';
import '../widgets/orbit_rive_mark.dart';
import '../widgets/orbit_spatial_surfaces.dart';
import 'quick_actions_screen.dart';

final class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

final class _TodayScreenState extends State<TodayScreen>
    with WidgetsBindingObserver {
  VoidCallback? _fireAtmospherePulse;
  Timer? _periodCheckTimer;
  OrbitDayPeriod _currentPeriod = OrbitDayPeriod.current();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPeriod = OrbitDayPeriod.current();
    _periodCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final nowPeriod = OrbitDayPeriod.current();
      if (nowPeriod != _currentPeriod && mounted) {
        setState(() => _currentPeriod = nowPeriod);
        _syncAutomaticWallpaper();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAutomaticWallpaper();
    });
  }

  void _syncAutomaticWallpaper() {
    final settings = OrbitEnvironment.read(context).style.settings;
    if (settings.atmosphereMode == AtmosphereMode.automatic) {
      unawaited(
        orbitWallpaperController.syncWithAtmosphereMode(
          AtmosphereMode.automatic,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final nowPeriod = OrbitDayPeriod.current();
      if (nowPeriod != _currentPeriod && mounted) {
        setState(() => _currentPeriod = nowPeriod);
        _syncAutomaticWallpaper();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodCheckTimer?.cancel();
    super.dispose();
  }

  bool get _filamentSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Widget _localData(Widget Function() builder) {
    final appState = OrbitEnvironment.read(context).appState;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => builder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(
      context,
      aspect: OrbitEnvironment.appearanceAspect,
    );
    OrbitEnvironment.of(context, aspect: OrbitEnvironment.qualityAspect);
    final palette = env.palette;
    final settings = env.style.settings;
    final useFilament = settings.renderer == TodayRenderer.filament;
    final useRive = settings.renderer == TodayRenderer.rive;

    final scene = Stack(
      fit: StackFit.expand,
      children: [
        // A real static scene always sits below the native Surface. It covers
        // initialization latency and remains visible after any GPU failure.
        OrbitPhotorealScene(
          palette: palette,
          quality: useFilament || useRive
              ? ResolvedQuality.static
              : env.resolvedQuality,
          motionEnabled: settings.motionEnabled && !useFilament && !useRive,
          settings: settings,
          active: true,
        ),
        if (useRive && env.resolvedQuality != ResolvedQuality.static)
          OrbitRiveMark(
            palette: palette,
            quality: env.resolvedQuality,
            atmospheric: true,
            onPulseReady: (callback) => _fireAtmospherePulse = callback,
            onError: (error) =>
                env.quality.reportGraphicsFallback('Rive', error),
          ),
        if (useFilament &&
            _filamentSupported &&
            env.resolvedQuality != ResolvedQuality.static)
          OrbitFilamentScene(
            key: ValueKey('filament-${palette.profile.name}'),
            palette: palette,
            quality: env.resolvedQuality,
          ),
      ],
    );

    return ListenableBuilder(
      listenable: orbitWallpaperController,
      builder: (context, _) {
        final isLiving =
            orbitWallpaperController.hasCustomWallpaper ||
            orbitWallpaperController.isLivingActive;
        return ColoredBox(
          color: isLiving ? Colors.transparent : palette.skyTop,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!isLiving) RepaintBoundary(child: scene),
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  if (useRive &&
                      env.resolvedQuality != ResolvedQuality.static) {
                    _fireAtmospherePulse?.call();
                  }
                  if (useFilament &&
                      env.resolvedQuality != ResolvedQuality.static) {
                    OrbitFilamentScene.pointerHandler?.call(event);
                  }
                },
                onPointerMove: (event) {
                  if (useFilament &&
                      env.resolvedQuality != ResolvedQuality.static) {
                    OrbitFilamentScene.pointerHandler?.call(event);
                  }
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: OrbitPhotorealScene.handleScrollNotification,
                  child: SafeArea(
                    bottom: false,
                    child: OrbitLayoutEngine.centered(
                      context,
                      CustomScrollView(
                        key: const Key('today-scroll'),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              OrbitLayoutEngine.pagePadding(context).left,
                              14,
                              OrbitLayoutEngine.pagePadding(context).right,
                              (OrbitLayoutEngine.useNavigationRail(context)
                                      ? 36
                                      : 126) +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                OrbitReveal(
                                  child: Row(
                                    mainAxisAlignment:
                                        MediaQuery.sizeOf(context).width < 360
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      if (MediaQuery.sizeOf(context).width >=
                                          360)
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: OrbitBrand(palette: palette),
                                          ),
                                        ),
                                      OrbitIconButton(
                                        key: const Key(
                                          'app-hub-trigger-button',
                                        ),
                                        palette: palette,
                                        icon: Icons.grid_view_rounded,
                                        tooltip: 'Хаб приложений ORBIT',
                                        filled: true,
                                        onTap: () => showOrbitAppHub(
                                          context,
                                          palette: palette,
                                          profile: palette.profile,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OrbitIconButton(
                                        key: const Key(
                                          'living-wallpaper-trigger-button',
                                        ),
                                        palette: palette,
                                        icon: Icons.wallpaper_rounded,
                                        tooltip:
                                            'Живой 2.5D-фон: выбрать и оживить картинку',
                                        filled: true,
                                        onTap: () =>
                                            showOrbitWallpaperStudioSheet(
                                              context,
                                              palette: palette,
                                              profile: palette.profile,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      OrbitIconButton(
                                        palette: palette,
                                        icon: Icons.auto_awesome_rounded,
                                        tooltip: 'ORBIT Brain',
                                        onTap: () => context.push('/brain'),
                                      ),
                                      const SizedBox(width: 8),
                                      OrbitIconButton(
                                        palette: palette,
                                        icon: Icons.notifications_none_rounded,
                                        tooltip: context.l10n.notifications,
                                        onTap: () => _showDemoNotice(
                                          context,
                                          context.l10n.notifications,
                                          context.l10n.notificationsDemo,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      FloatingActionButton(
                                        key: const Key('quick-actions-fab'),
                                        heroTag: 'today-quick-actions',
                                        mini: true,
                                        elevation: 0,
                                        highlightElevation: 1,
                                        tooltip: context.l10n.quickActions,
                                        onPressed: () =>
                                            showQuickActions(context),
                                        backgroundColor: palette.accent,
                                        foregroundColor: palette.isLight
                                            ? Colors.white
                                            : palette.skyTop,
                                        child: const Icon(
                                          Icons.add_rounded,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                OrbitReveal(
                                  index: 1,
                                  child: _GreetingHeader(
                                    palette: palette,
                                    dateLabel: _dateLabel(context),
                                    period: _currentPeriod,
                                  ),
                                ),
                                const OrbitPersistenceWarning(),
                                if (settings.renderer !=
                                    TodayRenderer.procedural) ...[
                                  const SizedBox(height: 12),
                                  OrbitReveal(
                                    index: 2,
                                    child: _ExperimentHeader(
                                      renderer: settings.renderer,
                                      palette: palette,
                                      quality: env.resolvedQuality,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                OrbitReveal(
                                  index: 2,
                                  child: _localData(
                                    () => _ProfileTopSection(
                                      palette: palette,
                                      env: env,
                                      dateLabel: _dateLabel(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                OrbitReveal(
                                  index: 4,
                                  child: _UpcomingSectionHeader(
                                    palette: palette,
                                    title: switch (palette.profile) {
                                      OrbitProfile.atelier =>
                                        'В фокусе сегодня',
                                      _ => context.l10n.upcoming,
                                    },
                                    eventCount: env.appState.events.length,
                                    onTitleTap: () => context.go('/calendar'),
                                    onAddTap: () =>
                                        context.push('/calendar?add=1'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OrbitReveal(
                                  index: 5,
                                  child: EventList(
                                    palette: palette,
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                OrbitReveal(
                                  index: 5,
                                  child: OrbitSectionTitle(
                                    context.l10n.actionCenter,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OrbitReveal(
                                  index: 6,
                                  child: _QuickStrip(palette: palette),
                                ),
                                if (useFilament && !_filamentSupported) ...[
                                  const SizedBox(height: 16),
                                  OrbitFilamentScene.unsupportedNotice(context),
                                ],
                                if ((useFilament || useRive) &&
                                    env.quality.graphicsFallbackReason !=
                                        null) ...[
                                  const SizedBox(height: 16),
                                  GlassPanel(
                                    palette: palette,
                                    quality: ResolvedQuality.static,
                                    child: Text(
                                      context.l10n.graphicsUnavailable(
                                        env.quality.graphicsFallbackReason!,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _dateLabel(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final value = DateFormat('EEEE, d MMMM', locale).format(clock.now());
    return context.l10n.dateFocus(
      '${value[0].toUpperCase()}${value.substring(1)}',
    );
  }

  static void _showDemoNotice(BuildContext context, String title, String text) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.understood),
          ),
        ],
      ),
    );
  }
}

final class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.palette,
    required this.dateLabel,
    this.period,
  });

  final OrbitPalette palette;
  final String dateLabel;
  final OrbitDayPeriod? period;

  @override
  Widget build(BuildContext context) {
    final currentPeriod = period ?? OrbitDayPeriod.current();
    final rawGreeting = currentPeriod
        .localizedGreeting(context, short: true)
        .replaceAll('!', '');
    final greetingTitle = '$rawGreeting, Алексей! 👋';
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final greetingStyle = Theme.of(
      context,
    ).textTheme.headlineMedium?.copyWith(fontSize: largeText ? 18 : null);
    final subtitle = switch (palette.profile) {
      OrbitProfile.one => 'Продуктивный день впереди',
      OrbitProfile.flow => 'Тихий фокус — идеальное время для важного',
      OrbitProfile.atelier => 'Спокойный фокус на важном',
      OrbitProfile.zen => 'Спокойный план на сегодня',
    };

    final datePill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: palette.isLight ? 0.70 : 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.accent.withValues(
            alpha: palette.isLight ? 0.20 : 0.12,
          ),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 13,
            color: palette.accentSecondary,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              dateLabel,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greetingTitle,
          key: const Key('today-greeting'),
          style: greetingStyle,
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        datePill,
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [greeting],
    );
  }
}

final class _ProfileTopSection extends StatelessWidget {
  const _ProfileTopSection({
    required this.palette,
    required this.env,
    required this.dateLabel,
  });

  final OrbitPalette palette;
  final OrbitEnvironment env;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final unreadEmails = env.appState.unreadCount(demoEmails);
    final eventsCount = env.appState.events.length;
    final totalTasks = env.appState.tasks.length;
    final completedTasks = env.appState.completedTasks;
    final pendingTasks = totalTasks - completedTasks;

    switch (palette.profile) {
      case OrbitProfile.flow:
        return Column(
          children: [
            _FlowModeSelector(palette: palette),
            const SizedBox(height: 14),
            _DayControlCenter(
              palette: palette,
              completed: completedTasks,
              total: totalTasks,
            ),
          ],
        );

      case OrbitProfile.atelier:
        return _AtelierStatusCards(
          palette: palette,
          unreadEmails: unreadEmails,
          eventsCount: eventsCount,
          tasksCount: pendingTasks,
        );

      case OrbitProfile.zen:
        return _ZenDateCard(palette: palette, dateLabel: dateLabel);

      case OrbitProfile.one:
        return _OneStatusCards(
          palette: palette,
          unreadEmails: unreadEmails,
          eventsCount: eventsCount,
          tasksCount: pendingTasks,
        );
    }
  }
}

final class _LargeStatusCard extends StatelessWidget {
  const _LargeStatusCard({required this.palette, required this.item});

  final OrbitPalette palette;
  final (IconData, String, String, String) item;

  @override
  Widget build(BuildContext context) {
    return OrbitPressable(
      onTap: () => context.go(item.$4),
      semanticLabel: item.$3,
      child: GlassPanel(
        palette: palette,
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(item.$1, size: 22, color: palette.accentSecondary),
            ),
            const SizedBox(width: 12),
            Text(
              item.$2,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.$3,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _OneStatusCards extends StatelessWidget {
  const _OneStatusCards({
    required this.palette,
    required this.unreadEmails,
    required this.eventsCount,
    required this.tasksCount,
  });

  final OrbitPalette palette;
  final int unreadEmails;
  final int eventsCount;
  final int tasksCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.mail_outline_rounded, '$unreadEmails', context.l10n.mail, '/mail'),
      (
        Icons.calendar_today_outlined,
        '$eventsCount',
        context.l10n.eventsMetric,
        '/calendar',
      ),
      (
        Icons.check_circle_outline_rounded,
        '$tasksCount',
        context.l10n.tasks,
        '/tasks',
      ),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;

    if (largeText) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _LargeStatusCard(palette: palette, item: items[i]),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: OrbitPressable(
                onTap: () => context.go(items[i].$4),
                semanticLabel: items[i].$3,
                child: GlassPanel(
                  palette: palette,
                  radius: 16,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: palette.accentSecondary.withValues(
                              alpha: 0.22,
                            ),
                            width: 0.6,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          items[i].$1,
                          size: 22,
                          color: palette.accentSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _AtelierStatusCards extends StatelessWidget {
  const _AtelierStatusCards({
    required this.palette,
    required this.unreadEmails,
    required this.eventsCount,
    required this.tasksCount,
  });

  final OrbitPalette palette;
  final int unreadEmails;
  final int eventsCount;
  final int tasksCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.mail_outline_rounded, '$unreadEmails', context.l10n.mail, '/mail'),
      (
        Icons.calendar_today_outlined,
        '$eventsCount',
        context.l10n.eventsMetric,
        '/calendar',
      ),
      (
        Icons.check_circle_outline_rounded,
        '$tasksCount',
        context.l10n.tasks,
        '/tasks',
      ),
      (Icons.edit_note_rounded, '—', 'Заметки', '/notes'),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;

    if (largeText) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _LargeStatusCard(palette: palette, item: items[i]),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: OrbitPressable(
                onTap: () => context.go(items[i].$4),
                semanticLabel: items[i].$3,
                child: GlassPanel(
                  palette: palette,
                  radius: 14,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 18,
                        color: palette.accentSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _FlowModeSelector extends StatefulWidget {
  const _FlowModeSelector({required this.palette});
  final OrbitPalette palette;

  @override
  State<_FlowModeSelector> createState() => _FlowModeSelectorState();
}

class _FlowModeSelectorState extends State<_FlowModeSelector> {
  int _selectedMode = 0;

  @override
  Widget build(BuildContext context) {
    final modes = [
      (Icons.waves_rounded, context.l10n.flow),
      (Icons.center_focus_strong_rounded, context.l10n.focus),
      (Icons.spa_rounded, 'Баланс'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.palette.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.palette.accentSecondary.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < modes.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedMode = i);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedMode == i
                        ? widget.palette.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _selectedMode == i
                        ? [
                            BoxShadow(
                              color: widget.palette.accent.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        modes[i].$1,
                        size: 15,
                        color: _selectedMode == i
                            ? Colors.white
                            : widget.palette.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        modes[i].$2,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _selectedMode == i
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _selectedMode == i
                              ? Colors.white
                              : widget.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _ZenDateCard extends StatelessWidget {
  const _ZenDateCard({required this.palette, required this.dateLabel});
  final OrbitPalette palette;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/calendar'),
      child: GlassPanel(
        palette: palette,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: palette.accentSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Сегодня, $dateLabel',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

final class _UpcomingSectionHeader extends StatelessWidget {
  const _UpcomingSectionHeader({
    required this.palette,
    required this.title,
    required this.eventCount,
    required this.onTitleTap,
    required this.onAddTap,
  });

  final OrbitPalette palette;
  final String title;
  final int eventCount;
  final VoidCallback onTitleTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTitleTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (palette.profile == OrbitProfile.atelier) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$eventCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: context.l10n.newEvent,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('today-add-event-button'),
              borderRadius: BorderRadius.circular(16),
              onTap: onAddTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: palette.surface.withValues(
                    alpha: palette.isLight ? 0.75 : 0.45,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: palette.isLight
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.16),
                    width: 0.75,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: palette.isLight ? 0.04 : 0.16,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ExperimentHeader extends StatelessWidget {
  const _ExperimentHeader({
    required this.renderer,
    required this.palette,
    required this.quality,
  });

  final TodayRenderer renderer;
  final OrbitPalette palette;
  final ResolvedQuality quality;

  @override
  Widget build(BuildContext context) {
    final isRive = renderer == TodayRenderer.rive;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final textColumn = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRive
              ? context.l10n.experimentRive
              : context.l10n.experimentFilament,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.accentSecondary,
            letterSpacing: largeText ? 0.5 : 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isRive ? context.l10n.liveBrandScene : context.l10n.pbrScene,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        TextButton(
          onPressed: () => context.push('/settings/lab'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 30),
          ),
          child: Text(context.l10n.compareRenderers),
        ),
      ],
    );
    final mark = (isRive && quality != ResolvedQuality.static)
        ? SizedBox(
            width: largeText ? 104 : 148,
            height: largeText ? 68 : 96,
            child: OrbitRiveMark(
              palette: palette,
              quality: quality,
              diagnosticsId: 'today-mark',
            ),
          )
        : OrbitLogo(palette: palette, size: largeText ? 52 : 62, animate: true);

    // При крупном тексте фиксированный 148×96 Rive-mark сжимал текстовую
    // колонку до посимвольного разрыва («EXPERIM/ENT B»). Композиция
    // перестраивается в столбец: текст сверху, mark снизу.
    if (largeText) {
      return GlassPanel(
        palette: palette,
        quality: quality,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            textColumn,
            const SizedBox(height: 10),
            Center(child: mark),
          ],
        ),
      );
    }

    return GlassPanel(
      palette: palette,
      quality: quality,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 102),
        child: Row(
          children: [
            Expanded(child: textColumn),
            mark,
          ],
        ),
      ),
    );
  }
}

final class _DayControlCenter extends StatelessWidget {
  const _DayControlCenter({
    required this.palette,
    required this.completed,
    required this.total,
  });

  final OrbitPalette palette;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final pulse = SizedBox(
      width: largeText ? 112 : 92,
      height: largeText ? 112 : 92,
      child: CustomPaint(
        painter: _DayPulsePainter(
          palette: palette,
          progress: total == 0 ? 0 : completed / total,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${((total == 0 ? 0 : completed / total) * 100).round()}%',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!largeText)
              Text(
                context.l10n.dayRhythm,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.yourSpace,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.completedSummary(completed, total),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _ModeChip(
              label: context.l10n.flow,
              icon: Icons.waves_rounded,
              palette: palette,
            ),
            _ModeChip(
              label: context.l10n.focus,
              icon: Icons.center_focus_strong_rounded,
              palette: palette,
            ),
          ],
        ),
      ],
    );
    return GlassPanel(
      palette: palette,
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [pulse, const SizedBox(height: 16), details],
            )
          : Row(
              children: [
                pulse,
                const SizedBox(width: 16),
                Expanded(child: details),
              ],
            ),
    );
  }
}

final class _DayPulsePainter extends CustomPainter {
  const _DayPulsePainter({required this.palette, required this.progress});
  final OrbitPalette palette;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: size.width * 0.42);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = palette.textSecondary.withValues(alpha: 0.15),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.04, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [palette.accent, palette.accentSecondary, palette.accent],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      size.width * 0.31,
      Paint()..color = palette.accent.withValues(alpha: 0.06),
    );
  }

  @override
  bool shouldRepaint(covariant _DayPulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.palette != palette;
}

final class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.palette,
  });
  final String label;
  final IconData icon;
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.accentSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

final class _EcosystemNode {
  const _EcosystemNode({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    required this.tint,
    this.isAiNode = false,
  });

  final String id;
  final IconData icon;
  final String label;
  final String route;
  final Color tint;
  final bool isAiNode;
}

final class _QuickStrip extends StatefulWidget {
  const _QuickStrip({required this.palette});
  final OrbitPalette palette;

  @override
  State<_QuickStrip> createState() => _QuickStripState();
}

final class _QuickStripState extends State<_QuickStrip>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() => _isExpanded = !_isExpanded);
  }

  double _resolveTileRadius(OrbitProfile profile) => switch (profile) {
    OrbitProfile.atelier => 14.0,
    OrbitProfile.flow => 20.0,
    OrbitProfile.zen => 12.0,
    OrbitProfile.one => 18.0,
  };

  double _resolveIconRadius(OrbitProfile profile) => switch (profile) {
    OrbitProfile.atelier => 10.0,
    OrbitProfile.flow => 14.0,
    OrbitProfile.zen => 8.0,
    OrbitProfile.one => 12.0,
  };

  double _resolveSpacing(OrbitProfile profile) => switch (profile) {
    OrbitProfile.atelier => 8.0,
    OrbitProfile.flow => 10.0,
    OrbitProfile.zen => 8.0,
    OrbitProfile.one => 9.0,
  };

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = context.l10n;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.25;

    const mailBlue = Color(0xFF3B82F6);
    const taskEmerald = Color(0xFF10B981);
    const calendarAmber = Color(0xFFF59E0B);
    const notesTerracotta = Color(0xFFEA580C);
    const filesIndigo = Color(0xFF6366F1);
    const contactsTeal = Color(0xFF14B8A6);

    // Row 1: Primary actions (preserves previous labels and routes for backwards compatibility & tests)
    final primaryNodes = <_EcosystemNode>[
      _EcosystemNode(
        id: 'mail',
        icon: Icons.edit_outlined,
        label: l10n.emailAction,
        route: '/mail/compose',
        tint: mailBlue,
      ),
      _EcosystemNode(
        id: 'tasks',
        icon: Icons.add_task_rounded,
        label: l10n.taskAction,
        route: '/tasks?add=1',
        tint: taskEmerald,
      ),
      _EcosystemNode(
        id: 'calendar',
        icon: Icons.event_outlined,
        label: l10n.eventAction,
        route: '/calendar?add=1',
        tint: calendarAmber,
      ),
      _EcosystemNode(
        id: 'brain',
        icon: Icons.auto_awesome_rounded,
        label: 'Brain',
        route: '/brain',
        tint: palette.accent,
        isAiNode: true,
      ),
    ];

    // Row 2: Secondary ecosystem modules
    final secondaryNodes = <_EcosystemNode>[
      _EcosystemNode(
        id: 'notes',
        icon: Icons.sticky_note_2_outlined,
        label: _resolveLocalizedLabel(context, 'notes'),
        route: '/notes',
        tint: notesTerracotta,
      ),
      _EcosystemNode(
        id: 'files',
        icon: Icons.folder_open_rounded,
        label: _resolveLocalizedLabel(context, 'files'),
        route: '/files',
        tint: filesIndigo,
      ),
      _EcosystemNode(
        id: 'contacts',
        icon: Icons.people_outline_rounded,
        label: _resolveLocalizedLabel(context, 'contacts'),
        route: '/contacts',
        tint: contactsTeal,
      ),
      _EcosystemNode(
        id: 'messenger',
        icon: Icons.chat_bubble_outline_rounded,
        label: _resolveLocalizedLabel(context, 'messenger'),
        route: '/messenger',
        tint: const Color(0xFF0EA5E9),
      ),
    ];

    final spacing = _resolveSpacing(palette.profile);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderBar(context, palette),
        SizedBox(height: spacing),
        _buildAdaptiveGrid(
          context: context,
          nodes: primaryNodes,
          isLargeText: isLargeText,
          spacing: spacing,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? Padding(
                  padding: EdgeInsets.only(top: spacing),
                  child: _buildAdaptiveGrid(
                    context: context,
                    nodes: secondaryNodes,
                    isLargeText: isLargeText,
                    spacing: spacing,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildHeaderBar(BuildContext context, OrbitPalette palette) {
    final textTheme = Theme.of(context).textTheme;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    final toggleText = _isExpanded
        ? (isRu ? 'Свернуть' : 'Collapse')
        : (isRu ? 'Все модули · 8' : 'All modules · 8');

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Ограничиваем пилюлю шириной строки: при крупном тексте на узких
        // экранах подпись сокращается многоточием вместо переполнения Row.
        Flexible(
          child: OrbitPressable(
            onTap: _toggleExpanded,
            semanticLabel: toggleText,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: palette.accentSecondary.withValues(alpha: 0.22),
                  width: 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      toggleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: palette.accentSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: palette.accentSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdaptiveGrid({
    required BuildContext context,
    required List<_EcosystemNode> nodes,
    required bool isLargeText,
    required double spacing,
  }) {
    if (!isLargeText) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < nodes.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: _buildVerticalTile(context, nodes[i])),
            ],
          ],
        ),
      );
    }

    final firstPair = nodes.sublist(0, 2);
    final secondPair = nodes.sublist(2, 4);

    Widget buildPairRow(List<_EcosystemNode> pair) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildHorizontalLargeTextTile(context, pair[0])),
            SizedBox(width: spacing),
            Expanded(child: _buildHorizontalLargeTextTile(context, pair[1])),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildPairRow(firstPair),
        SizedBox(height: spacing),
        buildPairRow(secondPair),
      ],
    );
  }

  Widget _buildVerticalTile(BuildContext context, _EcosystemNode node) {
    final palette = widget.palette;
    final effectiveRadius = _resolveTileRadius(palette.profile);

    return OrbitPressable(
      key: ValueKey('orbit_eco_${node.id}'),
      onTap: () => context.push(node.route),
      semanticLabel: node.label,
      child: GlassPanel(
        palette: palette,
        radius: effectiveRadius,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIconOrb(node),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: node.id == 'messenger'
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        node.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: node.isAiNode
                              ? FontWeight.w800
                              : FontWeight.w700,
                          fontSize: 11.5,
                          height: 1.15,
                          color: palette.textPrimary,
                        ),
                      ),
                    )
                  : Text(
                      node.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: node.isAiNode
                            ? FontWeight.w800
                            : FontWeight.w700,
                        fontSize: 11.5,
                        height: 1.15,
                        color: palette.textPrimary,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalLargeTextTile(
    BuildContext context,
    _EcosystemNode node,
  ) {
    final palette = widget.palette;
    final effectiveRadius = _resolveTileRadius(palette.profile);

    return OrbitPressable(
      key: ValueKey('orbit_eco_large_${node.id}'),
      onTap: () => context.push(node.route),
      semanticLabel: node.label,
      child: GlassPanel(
        palette: palette,
        radius: effectiveRadius,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          children: [
            _buildIconOrb(node),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                node.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: node.isAiNode ? FontWeight.w800 : FontWeight.w700,
                  height: 1.15,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconOrb(_EcosystemNode node) {
    final palette = widget.palette;
    if (node.isAiNode) {
      return OrbitLivingAiOrb(palette: palette, size: 40);
    }
    final iconRadius = _resolveIconRadius(palette.profile);

    final decoration = BoxDecoration(
      color: node.tint.withValues(alpha: palette.isLight ? 0.22 : 0.28),
      borderRadius: BorderRadius.circular(iconRadius + 2),
      border: Border.all(
        color: node.tint.withValues(alpha: palette.isLight ? 0.40 : 0.32),
        width: 0.7,
      ),
      boxShadow: [
        BoxShadow(
          color: node.tint.withValues(alpha: 0.16),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return Container(
      width: 42,
      height: 42,
      decoration: decoration,
      alignment: Alignment.center,
      child: Icon(node.icon, size: 24, color: node.tint),
    );
  }

  String _resolveLocalizedLabel(BuildContext context, String key) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    return switch (key) {
      'notes' => isRu ? 'Заметки' : 'Notes',
      'files' => isRu ? 'Файлы' : 'Files',
      'contacts' => isRu ? 'Контакты' : 'Contacts',
      'search' => isRu ? 'Поиск' : 'Search',
      'messenger' => isRu ? 'Мессенджер' : 'Messenger',
      _ => key,
    };
  }
}
