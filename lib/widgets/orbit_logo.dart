import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../visual_engine/orbit_palette.dart';

final class OrbitLogo extends StatefulWidget {
  const OrbitLogo({
    required this.palette,
    this.size = 30,
    this.animate = false,
    super.key,
  });

  final OrbitPalette palette;
  final double size;
  final bool animate;

  @override
  State<OrbitLogo> createState() => _OrbitLogoState();
}

final class _OrbitLogoState extends State<OrbitLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant OrbitLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          painter: _LogoPainter(widget.palette, _controller.value),
        ),
      ),
    );
  }
}

final class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.palette, this.phase);
  final OrbitPalette palette;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.34;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: math.pi * 1.5,
      colors: [
        palette.accentSecondary,
        palette.accent,
        palette.sun,
        palette.accentSecondary,
      ],
    ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi * 0.72,
      math.pi * 1.63,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.095
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
    final angle = -math.pi * 0.72 + phase * math.pi * 2;
    final satellite =
        center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(
      satellite,
      size.width * 0.07,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.palette != palette;
}

final class OrbitBrand extends StatelessWidget {
  const OrbitBrand({required this.palette, this.compact = false, super.key});
  final OrbitPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OrbitLogo(palette: palette, size: compact ? 25 : 30),
        const SizedBox(width: 9),
        Text(
          'ORBIT',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}
