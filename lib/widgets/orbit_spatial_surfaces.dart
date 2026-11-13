import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_motion_engine.dart';
import '../visual_engine/orbit_palette.dart';

/// Возвращает адаптивный радиус скругления под активный профиль ORBIT.
double orbitRadiusForProfile(OrbitProfile profile, {double offset = 0}) {
  final base = switch (profile) {
    OrbitProfile.one => 20.0,
    OrbitProfile.atelier => 14.0,
    OrbitProfile.flow => 24.0,
    OrbitProfile.zen => 12.0,
  };
  return (base + offset).clamp(6.0, 44.0);
}

/// 1. БИОЛЮМИНЕСЦЕНТНАЯ AI-СФЕРА (Living Shader-Like Orb)
final class OrbitLivingAiOrb extends StatefulWidget {
  const OrbitLivingAiOrb({
    required this.palette,
    this.size = 42.0,
    this.intensity = 1.0,
    super.key,
  });

  final OrbitPalette palette;
  final double size;
  final double intensity;

  @override
  State<OrbitLivingAiOrb> createState() => _OrbitLivingAiOrbState();
}

final class _OrbitLivingAiOrbState extends State<OrbitLivingAiOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _LivingOrbPainter(
              phase: _controller.value * 2 * math.pi,
              primary: widget.palette.accent,
              secondary: widget.palette.accentSecondary,
              intensity: widget.intensity,
            ),
          );
        },
      ),
    );
  }
}

final class _LivingOrbPainter extends CustomPainter {
  const _LivingOrbPainter({
    required this.phase,
    required this.primary,
    required this.secondary,
    required this.intensity,
  });

  final double phase;
  final Color primary;
  final Color secondary;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final outerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: 0.44 * intensity),
          secondary.withValues(alpha: 0.16 * intensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.15));
    canvas.drawCircle(center, radius * 1.15, outerGlow);

    final orbitOffset1 = Offset(
      center.dx + math.cos(phase) * radius * 0.22,
      center.dy + math.sin(phase) * radius * 0.22,
    );

    final corePaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        transform: GradientRotation(phase),
        colors: [
          primary,
          secondary,
          Colors.white.withValues(alpha: 0.82),
          primary,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.82));

    canvas.drawCircle(center, radius * 0.82, corePaint);

    final causticPaint = Paint()
      ..blendMode = BlendMode.plus
      ..color = Colors.white.withValues(alpha: 0.30);
    canvas.drawCircle(orbitOffset1, radius * 0.32, causticPaint);
  }

  @override
  bool shouldRepaint(covariant _LivingOrbPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.intensity != intensity;
}

/// 2. ПРОСТРАНСТВЕННАЯ КАРТОЧКА С ОПТИЧЕСКИМ ПРЕЛОМЛЕНИЕМ (GPU-Friendly Spatial Glass)
/// В списках работает без тяжелого BackdropFilter (useBlur: false),
/// рисуя направленный спектральный блик по грани.
@immutable
final class OrbitSpatialCard extends StatelessWidget {
  const OrbitSpatialCard({
    required this.palette,
    required this.child,
    this.radius = 20.0,
    this.padding = const EdgeInsets.all(16),
    this.tintColor,
    this.tintIntensity = 0.12,
    this.elevated = true,
    this.useBlur = false,
    this.blurSigma = 12.0,
    this.lightAngleRadians = 0.65,
    super.key,
  });

  final OrbitPalette palette;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final double tintIntensity;
  final bool elevated;
  final bool useBlur;
  final double blurSigma;
  final double lightAngleRadians;

  @override
  Widget build(BuildContext context) {
    final isLight = palette.isLight;
    final baseSurface = palette.surface;
    final effectiveTint = tintColor ?? palette.accent;

    final topFill = Color.lerp(
      baseSurface.withValues(alpha: isLight ? 0.90 : 0.84),
      effectiveTint.withValues(alpha: isLight ? 0.92 : 0.86),
      tintIntensity.clamp(0.0, 0.40),
    )!;

    final bottomFill = Color.lerp(
      baseSurface.withValues(alpha: isLight ? 0.82 : 0.76),
      effectiveTint.withValues(alpha: isLight ? 0.84 : 0.78),
      (tintIntensity * 0.55).clamp(0.0, 0.30),
    )!;

    Widget content = CustomPaint(
      foregroundPainter: _RefractiveRimPainter(
        radius: radius,
        angle: lightAngleRadians,
        accent: effectiveTint,
        accentSecondary: palette.accentSecondary,
        isLight: isLight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topFill, bottomFill],
          ),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (useBlur) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

final class _RefractiveRimPainter extends CustomPainter {
  const _RefractiveRimPainter({
    required this.radius,
    required this.angle,
    required this.accent,
    required this.accentSecondary,
    required this.isLight,
  });

  final double radius;
  final double angle;
  final Color accent;
  final Color accentSecondary;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Деликатный сапфировый блик по периметру (без слепящей белой рамки)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95
      ..shader = SweepGradient(
        transform: GradientRotation(angle),
        colors: [
          Colors.white.withValues(alpha: isLight ? 0.46 : 0.18),
          accent.withValues(alpha: isLight ? 0.32 : 0.26),
          Colors.white.withValues(alpha: 0.04),
          accentSecondary.withValues(alpha: isLight ? 0.24 : 0.20),
          Colors.white.withValues(alpha: isLight ? 0.46 : 0.18),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _RefractiveRimPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.isLight != isLight;
}

/// 3. КНОПКА С ПОЛНЫМ ОБЪЕМНЫМ ЗАПОЛНЕНИЕМ (Full-Fill Spatial Button)
@immutable
final class OrbitFilledButton extends StatelessWidget {
  const OrbitFilledButton({
    required this.palette,
    required this.label,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.badge,
    this.primaryColor,
    this.secondaryColor,
    this.radius = 18.0,
    this.isPrimary = true,
    this.compact = false,
    this.buttonKey,
    super.key,
  });

  final OrbitPalette palette;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? subtitle;
  final String? badge;
  final Color? primaryColor;
  final Color? secondaryColor;
  final double radius;
  final bool isPrimary;
  final bool compact;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final isLight = palette.isLight;
    final c1 = primaryColor ?? palette.accent;
    final c2 = secondaryColor ?? palette.accentSecondary;

    final List<Color> gradientColors = isPrimary
        ? [c1, Color.lerp(c1, c2, 0.55)!]
        : [
            Color.lerp(
              palette.surface,
              c1,
              isLight ? 0.18 : 0.26,
            )!.withValues(alpha: 0.94),
            Color.lerp(
              palette.surface,
              c2,
              isLight ? 0.10 : 0.18,
            )!.withValues(alpha: 0.88),
          ];

    final foregroundColor = isPrimary ? Colors.white : palette.textPrimary;
    final secondaryForeground = isPrimary
        ? Colors.white.withValues(alpha: 0.84)
        : palette.textSecondary;

    return OrbitPressable(
      key: buttonKey,
      semanticLabel: subtitle != null ? '$label. $subtitle' : label,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(
            color: isPrimary
                ? Colors.white.withValues(alpha: 0.28)
                : c1.withValues(alpha: isLight ? 0.30 : 0.38),
            width: 0.95,
          ),
          boxShadow: [
            BoxShadow(
              color: c1.withValues(
                alpha: isPrimary ? (isLight ? 0.28 : 0.36) : 0.12,
              ),
              blurRadius: isPrimary ? 16 : 10,
              spreadRadius: -2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 16,
            vertical: compact ? 8 : 14,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: compact ? 26 : 38,
                  height: compact ? 26 : 38,
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.20)
                        : c1.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(radius * 0.55),
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 15 : 20,
                    color: isPrimary ? Colors.white : c1,
                  ),
                ),
                SizedBox(width: compact ? 6 : 12),
              ],
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 13.5 : 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: foregroundColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: secondaryForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.black.withValues(alpha: 0.22)
                        : c1.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isPrimary ? Colors.white : c1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 4. КАПСУЛА УВЕДОМЛЕНИЙ DYNAMIC ISLAND (Вместо зависающего белого SnackBar)
void showOrbitSpatialIsland(
  BuildContext context, {
  required OrbitPalette palette,
  required String title,
  String? actionLabel,
  VoidCallback? onAction,
  IconData icon = Icons.auto_awesome_rounded,
  Duration duration = const Duration(milliseconds: 3000),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.clearSnackBars();

  Timer? autoDismissTimer;

  final controller = messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 94),
      padding: EdgeInsets.zero,
      duration: duration,
      content: OrbitSpatialCard(
        palette: palette,
        radius: 99,
        tintIntensity: 0.22,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [palette.accent, palette.accentSecondary],
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              OrbitPressable(
                semanticLabel: actionLabel,
                onTap: () {
                  autoDismissTimer?.cancel();
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: palette.accent.withValues(alpha: 0.22),
                  ),
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: palette.accent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  // Принудительное закрытие через [duration] даже при активном Android Accessibility
  autoDismissTimer = Timer(duration, () {
    try {
      controller.close();
    } catch (_) {}
  });
  controller.closed.whenComplete(() {
    autoDismissTimer?.cancel();
  });
}

/// 5. ЕДИНЫЙ ХЕЛПЕР МОДАЛЬНЫХ ОКОН ORBIT (useRootNavigator = true)
/// Гарантирует, что модальные окна открываются поверх дока
/// и док не перекрывает их содержимое и не перехватывает нажатия.
Future<T?> showOrbitModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  Color backgroundColor = Colors.transparent,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    builder: builder,
  );
}
