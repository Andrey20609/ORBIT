import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/demo_data.dart';
import '../visual_engine/orbit_visual_engine.dart';
import 'orbit_spatial_surfaces.dart';

/// Вызывает модальную шторку выбора папки ORBIT Mail поверх всего интерфейса (включая нижний док).
Future<OrbitMailFolder?> showOrbitMailFoldersSheet(
  BuildContext context, {
  required OrbitPalette palette,
  required OrbitProfile profile,
  required OrbitMailFolder currentFolder,
  required int Function(OrbitMailFolder folder) badgeBuilder,
  required ValueChanged<OrbitMailFolder> onFolderSelected,
}) {
  HapticFeedback.mediumImpact();

  return showModalBottomSheet<OrbitMailFolder>(
    context: context,
    useRootNavigator: true, // Гарантирует открытие поверх нижнего дока
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(
      alpha: palette.isLight ? 0.28 : 0.56,
    ),
    builder: (sheetCtx) => OrbitMailFoldersSheet(
      palette: palette,
      profile: profile,
      currentFolder: currentFolder,
      badgeBuilder: badgeBuilder,
      onFolderSelected: (folder) {
        HapticFeedback.lightImpact();
        onFolderSelected(folder);
        Navigator.of(sheetCtx, rootNavigator: true).pop(folder);
      },
    ),
  );
}

final class OrbitMailFoldersSheet extends StatelessWidget {
  const OrbitMailFoldersSheet({
    required this.palette,
    required this.profile,
    required this.currentFolder,
    required this.badgeBuilder,
    required this.onFolderSelected,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final OrbitMailFolder currentFolder;
  final int Function(OrbitMailFolder folder) badgeBuilder;
  final ValueChanged<OrbitMailFolder> onFolderSelected;

  double get _radius => orbitRadiusForProfile(profile);

  @override
  Widget build(BuildContext context) {
    final isLight = palette.isLight;
    final sheetRadius = _radius + 8.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(sheetRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: isLight ? 0.84 : 0.78),
              borderRadius: BorderRadius.circular(sheetRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: isLight ? 0.55 : 0.16),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.42),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: palette.textSecondary.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_special_rounded,
                          color: palette.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Папки почты',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final folder in OrbitMailFolder.values) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _FolderRowTile(
                          key: Key('mail-folder-item-${folder.name}'),
                          palette: palette,
                          radius: _radius * 0.78,
                          folder: folder,
                          isSelected: folder == currentFolder,
                          badgeCount: badgeBuilder(folder),
                          onTap: () => onFolderSelected(folder),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _FolderRowTile extends StatelessWidget {
  const _FolderRowTile({
    required this.palette,
    required this.radius,
    required this.folder,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
    super.key,
  });

  final OrbitPalette palette;
  final double radius;
  final OrbitMailFolder folder;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = palette.accent;
    final isLight = palette.isLight;

    return OrbitPressable(
      semanticLabel:
          '${folder.label}${badgeCount > 0 ? ", писем: $badgeCount" : ""}',
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: isLight ? 0.22 : 0.32),
                    palette.accentSecondary.withValues(
                      alpha: isLight ? 0.14 : 0.20,
                    ),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : palette.surface.withValues(alpha: isLight ? 0.65 : 0.48),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.65)
                : palette.textSecondary.withValues(alpha: 0.14),
            width: isSelected ? 1.2 : 0.9,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent
                    : accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(radius * 0.55),
              ),
              child: Icon(
                folder.icon,
                size: 19,
                color: isSelected ? Colors.white : accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                folder.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : palette.textSecondary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : palette.textPrimary,
                  ),
                ),
              ),
            ],
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
