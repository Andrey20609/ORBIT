import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_motion_engine.dart';
import '../visual_engine/orbit_palette.dart';
import 'glass_panel.dart';

@immutable
final class OrbitHubTelemetry {
  const OrbitHubTelemetry({
    this.notesCount = 24,
    this.storageUsedMb = 18.4,
    this.storageQuotaMb = 50.0,
    this.contactsCount = 142,
    this.brainStatus = 'Активен · Локальный индекс',
  });

  final int notesCount;
  final double storageUsedMb;
  final double storageQuotaMb;
  final int contactsCount;
  final String brainStatus;

  double get storageProgress =>
      (storageUsedMb / storageQuotaMb).clamp(0.0, 1.0);
}

Future<void> showOrbitAppHub(
  BuildContext context, {
  required OrbitPalette palette,
  required OrbitProfile profile,
  OrbitHubTelemetry telemetry = const OrbitHubTelemetry(),
}) {
  HapticFeedback.mediumImpact();

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: palette.isLight ? 0.28 : 0.56),
    builder: (sheetContext) => OrbitAppHubSheet(
      palette: palette,
      profile: profile,
      telemetry: telemetry,
    ),
  );
}

final class OrbitAppHubSheet extends StatelessWidget {
  const OrbitAppHubSheet({
    required this.palette,
    required this.profile,
    this.telemetry = const OrbitHubTelemetry(),
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final OrbitHubTelemetry telemetry;

  double get _baseRadius => switch (profile) {
    OrbitProfile.one => 20.0,
    OrbitProfile.atelier => 14.0,
    OrbitProfile.flow => 24.0,
    OrbitProfile.zen => 12.0,
  };

  double get _sheetRadius => _baseRadius + 8.0;

  void _navigateTo(BuildContext context, String route) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isLargeText = textScale > 1.25;
    final isLight = palette.isLight;

    final Color sheetFill = palette.surface.withValues(
      alpha: isLight ? 0.78 : 0.72,
    );
    final Color borderHighlight = isLight
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.14);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_sheetRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: sheetFill,
              borderRadius: BorderRadius.circular(_sheetRadius),
              border: Border.all(color: borderHighlight, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) > 180) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isLargeText) _buildGrabber(isLight),
                          if (!isLargeText) const SizedBox(height: 12),
                          _buildHeader(context, isLargeText),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SearchBentoBar(
                            palette: palette,
                            radius: _baseRadius,
                            onTap: () => _navigateTo(context, '/search'),
                          ),
                          const SizedBox(height: 12),
                          _BrainHeroTile(
                            palette: palette,
                            radius: _baseRadius,
                            statusText: telemetry.brainStatus,
                            onTap: () => _navigateTo(context, '/brain'),
                          ),
                          const SizedBox(height: 16),
                          _SectionLabel(title: 'ВСЕ СЕРВИСЫ', palette: palette),
                          const SizedBox(height: 10),
                          _buildServicesBentoGrid(context, isLargeText),
                          const SizedBox(height: 18),
                          _SectionLabel(
                            title: 'СИСТЕМА И ПРОФИЛЬ',
                            palette: palette,
                          ),
                          const SizedBox(height: 10),
                          _buildQuickActionsSection(context, isLargeText),
                        ],
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

  Widget _buildGrabber(bool isLight) {
    return Center(
      child: Container(
        width: 38,
        height: 4.5,
        decoration: BoxDecoration(
          color: palette.textSecondary.withValues(alpha: isLight ? 0.25 : 0.35),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLargeText) {
    final isLight = palette.isLight;
    final profileName = switch (profile) {
      OrbitProfile.one => 'ORBIT ONE',
      OrbitProfile.atelier => 'ATELIER',
      OrbitProfile.flow => 'FLOW',
      OrbitProfile.zen => 'ZEN',
    };

    final closeButton = IconButton(
      key: const Key('close-app-hub-sheet-button'),
      icon: Icon(Icons.close_rounded, color: palette.textSecondary, size: 22),
      tooltip: 'Закрыть',
      onPressed: () => Navigator.of(context).pop(),
    );

    // Материальный guidance: крупные заголовки не обязаны масштабироваться
    // линейно. Ограничиваем эффективный размер 30 px: при scale > 1.5 слово
    // «экосистемы» помещается в строку и не рвётся по буквам, оставаясь
    // читабельным заголовком шторки.
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final titleEffective = (20.0 * scale).clamp(20.0, 30.0);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Хаб экосистемы',
          style: TextStyle(
            fontSize: titleEffective / scale,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Быстрый доступ к модулям и ядру',
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
        ),
      ],
    );

    final profileBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(_baseRadius * 0.6),
        border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        profileName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: palette.accent,
        ),
      ),
    );

    // При крупном тексте фиксированный кластер «бейдж + кнопка» сжимал
    // Expanded-колонку заголовка до посимвольного вертикального переноса.
    // Бейдж переносится на отдельную строку под заголовком, а строка
    // управления остаётся «Expanded-заголовок + кнопка закрытия».
    if (isLargeText) {
      // Крупный текст: кнопка закрытия встаёт в ряд граббера, чтобы
      // заголовок занял полную ширину шторки и не рвался по буквам.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Center(child: _buildGrabber(isLight))),
              closeButton,
            ],
          ),
          const SizedBox(height: 8),
          titleBlock,
          const SizedBox(height: 8),
          profileBadge,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 8),
        profileBadge,
        const SizedBox(width: 4),
        closeButton,
      ],
    );
  }

  Widget _buildServicesBentoGrid(BuildContext context, bool isLargeText) {
    final notesTile = _BentoServiceTile(
      palette: palette,
      radius: _baseRadius,
      icon: Icons.edit_note_rounded,
      accentColor: palette.accent,
      title: 'Заметки',
      subtitle: 'Идеи и черновики',
      badgeText: '${telemetry.notesCount}',
      onTap: () => _navigateTo(context, '/notes'),
    );

    final contactsTile = _BentoServiceTile(
      palette: palette,
      radius: _baseRadius,
      icon: Icons.people_alt_outlined,
      accentColor: palette.accentSecondary,
      title: 'Контакты',
      subtitle: 'Люди и связи',
      badgeText: '${telemetry.contactsCount}',
      onTap: () => _navigateTo(context, '/contacts'),
    );

    final filesTile = _FilesStorageTile(
      palette: palette,
      radius: _baseRadius,
      usedMb: telemetry.storageUsedMb,
      quotaMb: telemetry.storageQuotaMb,
      progress: telemetry.storageProgress,
      onTap: () => _navigateTo(context, '/files'),
    );

    final messengerTile = _BentoServiceTile(
      palette: palette,
      radius: _baseRadius,
      icon: Icons.chat_bubble_outline_rounded,
      accentColor: const Color(0xFF0EA5E9),
      title: 'Мессенджер',
      subtitle: 'WSS & IMAP мост',
      badgeText: 'Live',
      onTap: () => _navigateTo(context, '/messenger'),
    );

    if (isLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          notesTile,
          const SizedBox(height: 10),
          contactsTile,
          const SizedBox(height: 10),
          filesTile,
          const SizedBox(height: 10),
          messengerTile,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: notesTile),
              const SizedBox(width: 10),
              Expanded(child: contactsTile),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: filesTile),
              const SizedBox(width: 10),
              Expanded(child: messengerTile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context, bool isLargeText) {
    final actions = [
      (label: 'Настройки', icon: Icons.tune_rounded, route: '/settings'),
      (
        label: 'Стиль и тема',
        icon: Icons.palette_outlined,
        route: '/settings/personalization',
      ),
      (
        label: 'Visual Lab',
        icon: Icons.compare_arrows_rounded,
        route: '/settings/lab',
      ),
    ];

    if (isLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _QuickActionPill(
              palette: palette,
              radius: _baseRadius * 0.75,
              icon: actions[i].icon,
              label: actions[i].label,
              onTap: () => _navigateTo(context, actions[i].route),
            ),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _QuickActionPill(
                palette: palette,
                radius: _baseRadius * 0.75,
                icon: actions[i].icon,
                label: actions[i].label,
                isCompact: true,
                onTap: () => _navigateTo(context, actions[i].route),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.palette});

  final String title;
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: palette.textSecondary.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

final class _SearchBentoBar extends StatelessWidget {
  const _SearchBentoBar({
    required this.palette,
    required this.radius,
    required this.onTap,
  });

  final OrbitPalette palette;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return OrbitPressable(
      semanticLabel: 'Сквозной поиск по экосистеме ORBIT',
      onTap: onTap,
      child: GlassPanel(
        palette: palette,
        radius: radius,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: palette.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                largeText
                    ? 'Сквозной поиск'
                    : 'Сквозной поиск: письма, задачи, файлы…',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: palette.textSecondary,
                ),
              ),
            ),
            if (!largeText) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.textSecondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⌘K',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _BrainHeroTile extends StatelessWidget {
  const _BrainHeroTile({
    required this.palette,
    required this.radius,
    required this.statusText,
    required this.onTap,
  });

  final OrbitPalette palette;
  final double radius;
  final String statusText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = palette.accent;
    final accentSec = palette.accentSecondary;
    final isLight = palette.isLight;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;

    return OrbitPressable(
      semanticLabel: 'Открыть ORBIT Brain',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: isLight ? 0.18 : 0.26),
              accentSec.withValues(alpha: isLight ? 0.10 : 0.16),
            ],
          ),
          border: Border.all(
            color: accent.withValues(alpha: isLight ? 0.35 : 0.45),
            width: 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(radius * 0.65),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'ORBIT Brain',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: largeText ? 12 : 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statusText,
                    maxLines: largeText ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!largeText) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: palette.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _BentoServiceTile extends StatelessWidget {
  const _BentoServiceTile({
    required this.palette,
    required this.radius,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.onTap,
  });

  final OrbitPalette palette;
  final double radius;
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String badgeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OrbitPressable(
      semanticLabel: '$title. $subtitle. Количество: $badgeText',
      onTap: onTap,
      child: GlassPanel(
        palette: palette,
        radius: radius,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(radius * 0.55),
                  ),
                  child: Icon(icon, color: accentColor, size: 21),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badgeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _FilesStorageTile extends StatelessWidget {
  const _FilesStorageTile({
    required this.palette,
    required this.radius,
    required this.usedMb,
    required this.quotaMb,
    required this.progress,
    required this.onTap,
  });

  final OrbitPalette palette;
  final double radius;
  final double usedMb;
  final double quotaMb;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = palette.accent;

    return OrbitPressable(
      semanticLabel:
          'Файлы и Документы. Занято ${usedMb.toStringAsFixed(1)} из ${quotaMb.toInt()} мегабайт',
      onTap: onTap,
      child: GlassPanel(
        palette: palette,
        radius: radius,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(radius * 0.55),
                  ),
                  child: Icon(
                    Icons.folder_copy_outlined,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Файлы и Документы',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Локальное хранилище ORBIT Vault',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${usedMb.toStringAsFixed(1)} / ${quotaMb.toInt()} МБ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: palette.textSecondary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _QuickActionPill extends StatelessWidget {
  const _QuickActionPill({
    required this.palette,
    required this.radius,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isCompact = false,
  });

  final OrbitPalette palette;
  final double radius;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return OrbitPressable(
      semanticLabel: label,
      onTap: onTap,
      child: GlassPanel(
        palette: palette,
        radius: radius,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 14,
          vertical: 12,
        ),
        child: isCompact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: palette.textPrimary),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(icon, size: 20, color: palette.textPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                ],
              ),
      ),
    );
  }
}
