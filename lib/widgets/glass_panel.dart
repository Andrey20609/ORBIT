import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_palette.dart';
import '../visual_engine/orbit_shader_engine.dart';

final class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.palette,
    required this.child,
    this.padding,
    this.radius,
    this.quality = ResolvedQuality.balanced,
    this.onTap,
    super.key,
  });

  final OrbitPalette palette;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final ResolvedQuality quality;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        radius ??
        switch (palette.profile) {
          OrbitProfile.atelier => 14.0,
          OrbitProfile.flow => 26.0,
          OrbitProfile.zen => 10.0,
          OrbitProfile.one => 22.0,
        };
    final effectivePadding =
        padding ??
        switch (palette.profile) {
          OrbitProfile.atelier => const EdgeInsets.all(20),
          OrbitProfile.zen => const EdgeInsets.all(12),
          _ => const EdgeInsets.all(16),
        };
    final borderRadius = BorderRadius.circular(effectiveRadius);
    final paddedChild = Padding(padding: effectivePadding, child: child);
    final useShader = OrbitShaderEngine.enableOpticalGlassShader &&
        quality != ResolvedQuality.static &&
        OrbitShaderEngine.instance.isAvailable;
    final borderColor = palette.profile == OrbitProfile.flow
        ? palette.accentSecondary.withValues(
            alpha: palette.isLight ? 0.12 : 0.08,
          )
        : palette.accent.withValues(
            alpha: palette.isLight ? 0.08 : 0.05,
          );
    final content = Container(
      decoration: BoxDecoration(
        color: palette.profile == OrbitProfile.flow ? null : palette.surface,
        gradient: palette.profile == OrbitProfile.flow
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.accentSecondary.withValues(alpha: 0.12),
                  palette.surface,
                ],
              )
            : null,
        borderRadius: borderRadius,
        border: useShader ? null : Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: palette.skyTop.withValues(
              alpha: palette.isLight ? 0.08 : 0.18,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    palette.textPrimary.withValues(
                      alpha: palette.isLight ? 0.08 : 0.04,
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          CustomPaint(
            foregroundPainter: useShader
                ? _GlassOpticalBorderPainter(
                    palette: palette,
                    borderRadius: borderRadius,
                    quality: quality,
                  )
                : null,
            child: Material(
              color: Colors.transparent,
              child: onTap == null
                  ? paddedChild
                  : InkWell(
                      onTap: onTap,
                      borderRadius: borderRadius,
                      child: paddedChild,
                    ),
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: content,
    );
  }
}

final class _GlassOpticalBorderPainter extends CustomPainter {
  const _GlassOpticalBorderPainter({
    required this.palette,
    required this.borderRadius,
    required this.quality,
  });

  final OrbitPalette palette;
  final BorderRadius borderRadius;
  final ResolvedQuality quality;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final borderColor = palette.profile == OrbitProfile.flow
        ? palette.accentSecondary.withValues(
            alpha: palette.isLight ? 0.12 : 0.08,
          )
        : palette.accent.withValues(
            alpha: palette.isLight ? 0.08 : 0.05,
          );

    if (OrbitShaderEngine.enableOpticalGlassShader &&
        quality != ResolvedQuality.static &&
        OrbitShaderEngine.instance.isAvailable) {
      final shader = OrbitShaderEngine.instance.createGlassShader(
        size: size,
        lightPos: const Offset(0.75, 0.2),
        borderColor: borderColor,
        fresnelIntensity: 0.85,
      );
      if (shader != null) {
        OrbitShaderEngine.instance.recordShaderPaint();
        strokePaint.shader = shader;
        canvas.drawRRect(rrect, strokePaint);
        return;
      }
    }

    strokePaint.color = borderColor;
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _GlassOpticalBorderPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.quality != quality;
}

final class OrbitIconButton extends StatelessWidget {
  const OrbitIconButton({
    required this.palette,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
    super.key,
  });

  final OrbitPalette palette;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      key: Key('orbit-button-$tooltip'),
      onPressed: onTap,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 42),
        backgroundColor: filled
            ? palette.accent.withValues(alpha: 0.24)
            : palette.surface,
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.textPrimary.withValues(alpha: 0.09)),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

final class DemoLabel extends StatelessWidget {
  const DemoLabel({required this.palette, super.key});
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        AppLocalizations.of(context).demoLabel,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}
