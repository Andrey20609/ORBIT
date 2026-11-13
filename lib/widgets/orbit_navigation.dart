import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../l10n/app_localizations.dart';
import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_palette.dart';
import 'orbit_environment.dart';

@immutable
final class OrbitDestination {
  const OrbitDestination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

List<OrbitDestination> _destinations(
  AppLocalizations l10n, [
  OrbitProfile? profile,
]) {
  final moreIcon = switch (profile) {
    OrbitProfile.flow => Icons.layers_rounded,
    OrbitProfile.zen => Icons.person_outline_rounded,
    _ => Icons.grid_view_rounded,
  };
  return [
    OrbitDestination(l10n.today, Icons.home_outlined, Icons.home_rounded),
    OrbitDestination(l10n.mail, Icons.mail_outline_rounded, Icons.mail_rounded),
    OrbitDestination(
      l10n.calendar,
      Icons.calendar_today_outlined,
      Icons.calendar_month_rounded,
    ),
    OrbitDestination(
      l10n.tasks,
      Icons.check_circle_outline_rounded,
      Icons.check_circle_rounded,
    ),
    OrbitDestination(l10n.more, moreIcon, moreIcon),
  ];
}

final class OrbitNavigationRail extends StatelessWidget {
  const OrbitNavigationRail({
    required this.index,
    required this.onChanged,
    required this.extended,
    super.key,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final palette = OrbitEnvironment.of(
      context,
      aspect: OrbitEnvironment.appearanceAspect,
    ).palette;
    final destinations = _destinations(
      AppLocalizations.of(context),
      palette.profile,
    );
    return SafeArea(
      right: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        decoration: BoxDecoration(
          color: palette.surfaceStrong.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: NavigationRail(
          selectedIndex: index,
          onDestinationSelected: onChanged,
          extended: extended,
          minExtendedWidth: 176,
          groupAlignment: -0.72,
          backgroundColor: Colors.transparent,
          indicatorColor: palette.accent.withValues(alpha: 0.32),
          selectedIconTheme: IconThemeData(
            color: palette.textPrimary,
            size: 23,
          ),
          unselectedIconTheme: IconThemeData(
            color: palette.textPrimary,
            size: 22,
          ),
          selectedLabelTextStyle: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          destinations: [
            for (var i = 0; i < destinations.length; i++)
              NavigationRailDestination(
                icon: Tooltip(
                  message: destinations[i].label,
                  child: Icon(destinations[i].icon, key: Key('orbit-nav-$i')),
                ),
                selectedIcon: Tooltip(
                  message: destinations[i].label,
                  child: Icon(
                    destinations[i].selectedIcon,
                    key: Key('orbit-nav-$i'),
                  ),
                ),
                label: Text(destinations[i].label),
              ),
          ],
        ),
      ),
    );
  }
}

final class OrbitBottomNavigation extends StatelessWidget {
  const OrbitBottomNavigation({
    required this.index,
    required this.onChanged,
    super.key,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrbitEnvironment.of(
      context,
      aspect: OrbitEnvironment.appearanceAspect,
    ).palette;
    final destinations = _destinations(
      AppLocalizations.of(context),
      palette.profile,
    );
    final isReducedMotion = MediaQuery.of(context).disableAnimations;

    final dockRadius = switch (palette.profile) {
      OrbitProfile.atelier => 22.0,
      OrbitProfile.zen => 24.0,
      _ => 28.0,
    };

    final dockColor = palette.isLight ? Colors.white : const Color(0xFF131620);

    final borderColor = palette.isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.14);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: dockColor,
            borderRadius: BorderRadius.circular(dockRadius),
            border: Border.all(color: borderColor, width: 0.65),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: palette.isLight ? 0.08 : 0.40,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: palette.accent.withValues(
                  alpha: palette.isLight ? 0.05 : 0.12,
                ),
                blurRadius: 18,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(dockRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _DockItem(
                        key: Key('orbit-nav-$i'),
                        destination: destinations[i],
                        isSelected: i == index,
                        palette: palette,
                        disableAnimations: isReducedMotion,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
                          onChanged(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.isSelected,
    required this.palette,
    required this.disableAnimations,
    required this.onTap,
    super.key,
  });

  final OrbitDestination destination;
  final bool isSelected;
  final OrbitPalette palette;
  final bool disableAnimations;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeBg = isSelected
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.isLight
                  ? [
                      palette.accent.withValues(alpha: 0.22),
                      palette.accentSecondary.withValues(alpha: 0.12),
                    ]
                  : [
                      palette.accent.withValues(alpha: 0.42),
                      palette.accentSecondary.withValues(alpha: 0.24),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(
                  alpha: palette.isLight ? 0.25 : 0.50,
                ),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          )
        : null;

    final iconColor = isSelected
        ? (palette.isLight ? palette.accent : Colors.white)
        : palette.textSecondary.withValues(alpha: 0.7);

    return Tooltip(
      message: destination.label,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Center(
              child: AnimatedContainer(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: isSelected ? 48 : 36,
                height: isSelected ? 38 : 36,
                decoration: activeBg,
                child: Center(
                  child: Icon(
                    isSelected ? destination.selectedIcon : destination.icon,
                    size: isSelected ? 22 : 21,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
