import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../l10n/app_localizations.dart';

import '../visual_engine/orbit_visual_engine.dart';
import 'glass_panel.dart';
import 'orbit_environment.dart';
import 'orbit_persistence_warning.dart';
import 'orbit_photoreal_scene.dart';

final class OrbitPage extends StatelessWidget {
  const OrbitPage({
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.scrollable = true,
    this.reduceEffects = false,
    this.padding,
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget body;
  final bool scrollable;
  final bool reduceEffects;
  final EdgeInsetsGeometry? padding;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(
      context,
      aspect: OrbitEnvironment.appearanceAspect,
    );
    OrbitEnvironment.of(context, aspect: OrbitEnvironment.qualityAspect);
    final header = Padding(
      padding: padding ?? OrbitLayoutEngine.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              ?leading,
              if (leading != null) const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    key: Key('page-title-$title'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 14),
          DemoLabel(palette: env.palette),
          const OrbitPersistenceWarning(),
        ],
      ),
    );

    final content = OrbitLayoutEngine.centered(
      context,
      scrollable
          ? SingleChildScrollView(
              key: const Key('orbit-page-scroll'),
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                0,
                0,
                0,
                (OrbitLayoutEngine.useNavigationRail(context) ? 36 : 124) +
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      OrbitLayoutEngine.pagePadding(context).left,
                      18,
                      OrbitLayoutEngine.pagePadding(context).right,
                      0,
                    ),
                    child: body,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Expanded(
                  child: Padding(
                    padding: padding ?? OrbitLayoutEngine.pagePadding(context),
                    child: body,
                  ),
                ),
              ],
            ),
    );
    final pageContent = floatingActionButton == null
        ? content
        : Stack(
            children: [
              content,
              Positioned(
                right: OrbitLayoutEngine.pagePadding(context).right,
                bottom: (OrbitLayoutEngine.useNavigationRail(context) ? 24 : 96) +
                    MediaQuery.paddingOf(context).bottom,
                child: floatingActionButton!,
              ),
            ],
          );
    return OrbitSceneBackground(
      palette: env.palette,
      quality: env.resolvedQuality,
      motionEnabled: env.style.settings.motionEnabled,
      settings: env.style.settings,
      reduceEffects: reduceEffects,
      child: NotificationListener<ScrollNotification>(
        onNotification: OrbitPhotorealScene.handleScrollNotification,
        child: SafeArea(bottom: false, child: pageContent),
      ),
    );
  }
}

final class OrbitFab extends StatelessWidget {
  const OrbitFab({
    required this.palette,
    required this.onTap,
    this.icon = Icons.add_rounded,
    this.tooltip,
    this.semanticsLabel,
    this.buttonKey,
    super.key,
  });

  final OrbitPalette palette;
  final VoidCallback onTap;
  final IconData icon;
  final String? tooltip;
  final String? semanticsLabel;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: semanticsLabel ?? tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: buttonKey,
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.accent,
                    palette.accentSecondary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(
                      alpha: palette.isLight ? 0.35 : 0.55,
                    ),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class OrbitBackButton extends StatelessWidget {
  const OrbitBackButton({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrbitEnvironment.of(
      context,
      aspect: OrbitEnvironment.appearanceAspect,
    ).palette;
    return OrbitIconButton(
      palette: palette,
      icon: Icons.arrow_back_ios_new_rounded,
      tooltip: AppLocalizations.of(context).back,
      onTap: onTap,
    );
  }
}

final class OrbitSectionTitle extends StatelessWidget {
  const OrbitSectionTitle(this.title, {this.action, super.key});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    );
  }
}
