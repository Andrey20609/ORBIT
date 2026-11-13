import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';

import '../l10n/orbit_localizations.dart';
import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_palette.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_spatial_surfaces.dart';

Future<void> showQuickActions(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const QuickActionsScreen(),
  );
}

final class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? route;
}

final class QuickActionsScreen extends StatelessWidget {
  const QuickActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final actionExtent = 96 * textScale;

    final primaryActions = <_QuickActionItem>[
      _QuickActionItem(
        icon: Icons.send_rounded,
        title: 'Новое письмо',
        subtitle: context.l10n.localDraft,
        color: const Color(0xFF82B9FF),
        route: '/mail/compose',
      ),
      _QuickActionItem(
        icon: Icons.check_circle_outline_rounded,
        title: 'Создать задачу',
        subtitle: context.l10n.toLocalList,
        color: const Color(0xFF52D093),
        route: '/tasks?add=1',
      ),
      _QuickActionItem(
        icon: Icons.calendar_today_rounded,
        title: 'Событие',
        subtitle: context.l10n.openCalendar,
        color: const Color(0xFFFFB366),
        route: '/calendar?add=1',
      ),
      _QuickActionItem(
        icon: Icons.edit_note_rounded,
        title: 'Заметка',
        subtitle: 'Быстрая запись',
        color: const Color(0xFFFFA066),
        route: '/notes?add=1',
      ),
      _QuickActionItem(
        icon: Icons.document_scanner_rounded,
        title: 'Скан документа',
        subtitle: 'Камера / PDF',
        color: const Color(0xFFA78BFA),
        route: '/files',
      ),
      _QuickActionItem(
        icon: Icons.cloud_download_rounded,
        title: 'Файл из облака',
        subtitle: 'Диск / Хранилище',
        color: const Color(0xFF60A5FA),
        route: '/files',
      ),
    ];

    final sheetRadius = switch (palette.profile) {
      OrbitProfile.atelier => 24.0,
      OrbitProfile.zen => 22.0,
      _ => 32.0,
    };

    final sheetColor = palette.isLight
        ? Colors.white.withValues(alpha: 0.94)
        : const Color(0xFF141722).withValues(alpha: 0.92);

    final borderColor = palette.isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.14);

    return Container(
      key: const Key('quick-actions-sheet'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: BorderRadius.circular(sheetRadius),
        border: Border.all(color: borderColor, width: 0.75),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: palette.isLight ? 0.12 : 0.45,
            ),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: palette.accent.withValues(
              alpha: palette.isLight ? 0.04 : 0.10,
            ),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(sheetRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.quickActions,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Сделайте больше одним касанием',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 12.5,
                                    color: palette.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: context.l10n.close,
                        child: Semantics(
                          button: true,
                          label: context.l10n.close,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: palette.surface.withValues(
                                    alpha: palette.isLight ? 0.6 : 0.3,
                                  ),
                                  border: Border.all(
                                    color: palette.isLight
                                        ? Colors.black.withValues(alpha: 0.08)
                                        : Colors.white.withValues(alpha: 0.12),
                                    width: 0.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GridView.builder(
                    itemCount: primaryActions.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: actionExtent,
                    ),
                    itemBuilder: (context, index) {
                      final item = primaryActions[index];
                      return _QuickActionSquircle(
                        item: item,
                        palette: palette,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          env.appState.registerQuickAction();
                          Navigator.of(context).pop();
                          if (item.route != null) {
                            GoRouter.of(context).push(item.route!);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ContextualBrainCard(
                    palette: palette,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      env.appState.registerQuickAction();
                      Navigator.of(context).pop();
                      GoRouter.of(context).push('/brain');
                    },
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    button: true,
                    label: context.l10n.close,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('quick-actions-close-circle'),
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.surface.withValues(
                              alpha: palette.isLight ? 0.85 : 0.45,
                            ),
                            border: Border.all(
                              color: palette.isLight
                                  ? Colors.black.withValues(alpha: 0.10)
                                  : Colors.white.withValues(alpha: 0.18),
                              width: 0.75,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: palette.isLight ? 0.06 : 0.25,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                      ),
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

final class _QuickActionSquircle extends StatelessWidget {
  const _QuickActionSquircle({
    required this.item,
    required this.palette,
    required this.onTap,
  });

  final _QuickActionItem item;
  final OrbitPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardBg = palette.isLight
        ? Colors.black.withValues(alpha: 0.035)
        : Colors.white.withValues(alpha: 0.06);

    final cardBorder = palette.isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.10);

    return Semantics(
      button: true,
      label: item.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.color.withValues(
                      alpha: palette.isLight ? 0.14 : 0.20,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(
                          alpha: palette.isLight ? 0.18 : 0.35,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(item.icon, size: 20, color: item.color),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: palette.textSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ContextualBrainCard extends StatelessWidget {
  const _ContextualBrainCard({required this.palette, required this.onTap});

  final OrbitPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ORBIT Brain',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette.isLight
                    ? [
                        palette.accent.withValues(alpha: 0.10),
                        palette.accentSecondary.withValues(alpha: 0.05),
                      ]
                    : [
                        palette.accent.withValues(alpha: 0.22),
                        palette.accentSecondary.withValues(alpha: 0.12),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.accent.withValues(
                  alpha: palette.isLight ? 0.15 : 0.25,
                ),
                width: 0.65,
              ),
            ),
            child: Row(
              children: [
                OrbitLivingAiOrb(palette: palette, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORBIT Brain',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'По контексту — встреча скоро начнётся, отправить повестку?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
