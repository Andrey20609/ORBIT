import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/orbit_living_backdrop.dart';
import '../widgets/orbit_photoreal_scene.dart';
import 'appearance_settings.dart';
import 'orbit_palette.dart';

final class OrbitSceneBackground extends StatelessWidget {
  const OrbitSceneBackground({
    required this.palette,
    required this.quality,
    required this.motionEnabled,
    required this.child,
    this.settings,
    this.active = true,
    this.reduceEffects = false,
    super.key,
  });

  final OrbitPalette palette;
  final ResolvedQuality quality;
  final bool motionEnabled;
  final AppearanceSettings? settings;
  final Widget child;
  final bool active;
  final bool reduceEffects;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: orbitWallpaperController,
      builder: (context, _) {
        final isLiving = orbitWallpaperController.hasCustomWallpaper ||
            orbitWallpaperController.isLivingActive;

        if (isLiving) {
          return child;
        }

        return ColoredBox(
          color: palette.skyTop,
          child: Stack(
            fit: StackFit.expand,
            children: [
              OrbitPhotorealScene(
                palette: palette,
                quality: ResolvedQuality.static,
                motionEnabled: false,
                settings: settings,
                active: active,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.skyTop.withValues(
                        alpha: palette.isLight ? 0.02 : 0.06,
                      ),
                      palette.skyTop.withValues(
                        alpha: palette.isLight ? 0.05 : 0.10,
                      ),
                      palette.skyTop.withValues(
                        alpha: reduceEffects
                            ? 0.70
                            : (palette.isLight ? 0.20 : 0.28),
                      ),
                    ],
                    stops: const [0, 0.48, 1],
                  ),
                ),
              ),
              child,
            ],
          ),
        );
      },
    );
  }
}

final class OrbitSceneEngine extends StatefulWidget {
  const OrbitSceneEngine({
    required this.palette,
    required this.quality,
    required this.motionEnabled,
    this.active = true,
    super.key,
  });

  final OrbitPalette palette;
  final ResolvedQuality quality;
  final bool motionEnabled;
  final bool active;

  @override
  State<OrbitSceneEngine> createState() => _OrbitSceneEngineState();
}

final class _OrbitSceneEngineState extends State<OrbitSceneEngine>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  Offset _parallax = Offset.zero;
  bool _resumed = true;
  bool _tickerEnabled = true;
  int _lastPaintMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..addListener(_tick);
    _syncAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant OrbitSceneEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  bool get _shouldAnimate =>
      _resumed &&
      widget.active &&
      widget.motionEnabled &&
      widget.quality != ResolvedQuality.static &&
      _tickerEnabled;

  void _syncAnimation() {
    if (!mounted) return;
    if (_shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  void _tick() {
    final fps = widget.quality == ResolvedQuality.ultra ? 60 : 30;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPaintMs < 1000 ~/ fps) return;
    _lastPaintMs = now;
    if (mounted) setState(() {});
  }

  void _updateParallax(Offset position) {
    if (widget.quality == ResolvedQuality.static) return;
    final size = MediaQuery.sizeOf(context);
    final next = Offset(
      ((position.dx / size.width) - 0.5) * 13,
      ((position.dy / size.height) - 0.5) * 8,
    );
    if ((next - _parallax).distance < 0.15) return;
    setState(() => _parallax = next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  @override
  void didHaveMemoryPressure() {
    _controller.stop();
    _parallax = Offset.zero;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _updateParallax(event.localPosition),
      onPointerMove: (event) => _updateParallax(event.localPosition),
      onPointerHover: (event) => _updateParallax(event.localPosition),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _OrbitLandscapePainter(
            palette: widget.palette,
            phase: _shouldAnimate ? _controller.value : 0.14,
            quality: widget.quality,
            parallax: _parallax,
          ),
        ),
      ),
    );
  }
}

final class _OrbitLandscapePainter extends CustomPainter {
  const _OrbitLandscapePainter({
    required this.palette,
    required this.phase,
    required this.quality,
    required this.parallax,
  });

  final OrbitPalette palette;
  final double phase;
  final ResolvedQuality quality;
  final Offset parallax;

  bool get _animated => quality != ResolvedQuality.static;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final middle = Color.lerp(palette.skyTop, palette.skyBottom, 0.58)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              palette.skyTop,
              Colors.black,
              palette.isLight ? 0 : 0.08,
            )!,
            palette.skyTop,
            middle,
            palette.skyBottom,
          ],
          stops: const [0, 0.28, 0.62, 1],
        ).createShader(rect),
    );

    if (palette.profile != OrbitProfile.zen) _drawStars(canvas, size);
    _drawSun(canvas, size);
    _drawCloudBanks(canvas, size);

    final horizon = size.height * 0.43;
    _drawMountainLayer(
      canvas,
      size,
      baseline: horizon + size.height * 0.01,
      height: size.height * 0.16,
      color: Color.lerp(palette.mountainFar, palette.skyBottom, 0.45)!,
      depth: 0.12,
      seed: 11,
      snow: palette.profile == OrbitProfile.atelier,
    );
    _drawHaze(canvas, size, horizon - 12, 94, 0.14);
    _drawMountainLayer(
      canvas,
      size,
      baseline: horizon + size.height * 0.09,
      height: size.height * 0.2,
      color: palette.mountainFar,
      depth: 0.28,
      seed: 23,
      snow: palette.profile != OrbitProfile.flow,
    );
    _drawHaze(canvas, size, horizon + 20, 110, 0.1);
    _drawMountainLayer(
      canvas,
      size,
      baseline: horizon + size.height * 0.18,
      height: size.height * 0.21,
      color: Color.lerp(palette.mountainFar, palette.mountainNear, 0.52)!,
      depth: 0.52,
      seed: 37,
      snow: palette.profile == OrbitProfile.atelier,
    );

    final hasLake = palette.profile != OrbitProfile.flow;
    if (hasLake) _drawLake(canvas, size);

    if (hasLake) {
      _drawForegroundBanks(canvas, size);
    } else {
      _drawMountainLayer(
        canvas,
        size,
        baseline: horizon + size.height * 0.35,
        height: size.height * 0.18,
        color: palette.mountainNear,
        depth: 0.9,
        seed: 51,
        snow: false,
        foreground: true,
      );
    }

    if (palette.profile == OrbitProfile.flow) _drawFlow(canvas, size);
    _drawVignette(canvas, size);
  }

  void _drawStars(Canvas canvas, Size size) {
    for (var i = 0; i < 72; i++) {
      final x = _hash(i, 3) * size.width;
      final y = _hash(i, 7) * size.height * 0.34;
      final pulse = _animated
          ? 0.72 + 0.28 * math.sin(i * 1.7 + phase * math.pi * 2)
          : 0.86;
      final alpha = (0.1 + _hash(i, 13) * 0.35) * pulse;
      final radius = i % 13 == 0 ? 1.15 : 0.35 + _hash(i, 17) * 0.55;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
      if (i % 19 == 0) {
        final glow = Rect.fromCircle(center: Offset(x, y), radius: 4);
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()
            ..shader = RadialGradient(
              colors: [
                palette.accentSecondary.withValues(alpha: 0.24),
                palette.accentSecondary.withValues(alpha: 0),
              ],
            ).createShader(glow),
        );
      }
    }
  }

  void _drawSun(Canvas canvas, Size size) {
    final drift = _animated ? math.sin(phase * math.pi * 2) * 3 : 0.0;
    final center = Offset(
      size.width * (palette.profile == OrbitProfile.zen ? 0.68 : 0.72) +
          parallax.dx * 0.18,
      size.height * 0.245 + drift + parallax.dy * 0.12,
    );
    for (final (scale, alpha) in const [(3.8, 0.2), (2.2, 0.26), (1.25, 0.3)]) {
      final radius = size.width * 0.12 * scale;
      final glowRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              palette.sun.withValues(alpha: alpha),
              palette.sun.withValues(alpha: alpha * 0.35),
              palette.sun.withValues(alpha: 0),
            ],
            stops: const [0, 0.36, 1],
          ).createShader(glowRect),
      );
    }
    final discRect = Rect.fromCircle(center: center, radius: 18);
    canvas.drawCircle(
      center,
      18,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            Colors.white.withValues(alpha: palette.isLight ? 0.82 : 0.64),
            palette.sun,
            palette.sun.withValues(alpha: 0.88),
          ],
        ).createShader(discRect),
    );
  }

  void _drawCloudBanks(Canvas canvas, Size size) {
    final count = palette.profile == OrbitProfile.zen ? 5 : 4;
    for (var i = 0; i < count; i++) {
      final direction = i.isEven ? 1.0 : -1.0;
      final travel = _animated ? phase * 22 * direction : 0.0;
      final center = Offset(
        size.width * (0.08 + i * 0.25) + travel + parallax.dx * 0.12,
        size.height * (0.16 + (i % 3) * 0.065),
      );
      final width = size.width * (0.34 + _hash(i, 21) * 0.18);
      final alpha = palette.isLight ? 0.19 : 0.065;
      for (var part = 0; part < 5; part++) {
        final partCenter = center.translate(
          (part - 2) * width * 0.16,
          (part % 2) * 5 - 2,
        );
        _softEllipse(
          canvas,
          partCenter,
          width * (0.5 - (part - 2).abs() * 0.045),
          18 + _hash(part, i + 31) * 17,
          Colors.white,
          alpha,
        );
      }
    }
  }

  void _softEllipse(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Color color,
    double alpha,
  ) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.52),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  void _drawMountainLayer(
    Canvas canvas,
    Size size, {
    required double baseline,
    required double height,
    required Color color,
    required double depth,
    required int seed,
    required bool snow,
    bool foreground = false,
  }) {
    const segments = 96;
    final points = <Offset>[];
    for (var i = -3; i <= segments + 3; i++) {
      final t = i / segments;
      final massif = _noise(t * 4.4, seed);
      final ridge = 1 - (_noise(t * 12.5, seed + 5) * 2 - 1).abs();
      final erosion = _noise(t * 23, seed + 9);
      final detail = _noise(t * 39, seed + 13);
      final shape =
          (massif * 0.56 + ridge * 0.25 + erosion * 0.14 + detail * 0.05)
              .clamp(0.12, 0.96)
              .toDouble();
      points.add(
        Offset(
          t * size.width + parallax.dx * depth,
          baseline - height * shape + parallax.dy * depth,
        ),
      );
    }

    final ridgePath = _smoothRidge(points);
    final path = Path.from(ridgePath)
      ..lineTo(points.last.dx, size.height + 20)
      ..lineTo(points.first.dx, size.height + 20)
      ..close();
    final top = points.map((p) => p.dy).reduce(math.min);
    final fillRect = Rect.fromLTRB(-20, top, size.width + 20, size.height + 20);
    final topColor = Color.lerp(
      color,
      palette.sun,
      palette.isLight ? 0.12 : 0.075,
    )!;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, color, Color.lerp(color, palette.skyTop, 0.32)!],
        ).createShader(fillRect),
    );

    // Restrained facets mark only broader local peaks. The smoothed silhouette
    // and atmospheric gradients carry the landscape instead of large triangles.
    if (snow) {
      for (var i = 3; i < points.length - 3; i += 3) {
        final peak = points[i];
        final isPeak = <Offset>[
          points[i - 3],
          points[i - 2],
          points[i - 1],
          points[i + 1],
          points[i + 2],
          points[i + 3],
        ].every((point) => peak.dy <= point.dy);
        if (!isPeak) continue;
        final left = points[i - 2];
        final right = points[i + 2];
        final facet = Path()
          ..moveTo(peak.dx, peak.dy)
          ..lineTo(right.dx, right.dy)
          ..lineTo(
            peak.dx + (right.dx - left.dx) * 0.35,
            peak.dy + height * 0.11,
          )
          ..close();
        canvas.drawPath(
          facet,
          Paint()
            ..color = palette.sun.withValues(
              alpha: palette.isLight ? 0.12 : 0.085,
            ),
        );
        final shade = Path()
          ..moveTo(peak.dx, peak.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(
            peak.dx - (right.dx - left.dx) * 0.2,
            peak.dy + height * 0.09,
          )
          ..close();
        canvas.drawPath(
          shade,
          Paint()..color = palette.skyTop.withValues(alpha: 0.09),
        );
      }
    }

    canvas.drawPath(
      ridgePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = foreground ? 0.55 : 0.85
        ..color = palette.sun.withValues(alpha: foreground ? 0.035 : 0.11),
    );

    if (foreground) {
      for (var i = 3; i < points.length - 3; i += 4) {
        final point = points[i];
        final slope = Path()
          ..moveTo(point.dx, point.dy + 3)
          ..quadraticBezierTo(
            point.dx + 9,
            point.dy + height * 0.18,
            point.dx + 20,
            baseline + height * 0.25,
          );
        canvas.drawPath(
          slope,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.65
            ..color = palette.accentSecondary.withValues(alpha: 0.045),
        );
      }
    }
  }

  Path _smoothRidge(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? 0 : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 < points.length ? i + 2 : points.length - 1];
      final control1 = p1 + (p2 - p0) / 6;
      final control2 = p2 - (p3 - p1) / 6;
      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        p2.dx,
        p2.dy,
      );
    }
    return path;
  }

  void _drawHaze(
    Canvas canvas,
    Size size,
    double top,
    double height,
    double alpha,
  ) {
    final rect = Rect.fromLTWH(0, top, size.width, height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.skyBottom.withValues(alpha: 0),
            palette.sun.withValues(alpha: alpha),
            palette.skyBottom.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  void _drawForegroundBanks(Canvas canvas, Size size) {
    _drawBank(canvas, size, left: true, seed: 51);
    _drawBank(canvas, size, left: false, seed: 67);
  }

  void _drawBank(
    Canvas canvas,
    Size size, {
    required bool left,
    required int seed,
  }) {
    const segments = 40;
    final baseline = size.height * 0.82;
    final height = size.height * 0.24;
    final startX = left ? -size.width * 0.08 : size.width * 0.5;
    final endX = left ? size.width * 0.5 : size.width * 1.08;
    final points = <Offset>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final taper = math.pow(left ? 1 - t : t, 0.72).toDouble();
      final broad = _noise(t * 3.4, seed);
      final ridge = 1 - (_noise(t * 10.5, seed + 4) * 2 - 1).abs();
      final shape = (0.1 + broad * 0.58 + ridge * 0.32) * taper;
      points.add(
        Offset(
          startX + (endX - startX) * t + parallax.dx * 0.9,
          baseline - height * shape + parallax.dy * 0.9,
        ),
      );
    }
    final ridgePath = _smoothRidge(points);
    final path = Path.from(ridgePath)
      ..lineTo(points.last.dx, size.height + 20)
      ..lineTo(points.first.dx, size.height + 20)
      ..close();
    final fillRect = Rect.fromLTRB(
      math.min(startX, endX),
      baseline - height,
      math.max(startX, endX),
      size.height,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(palette.mountainNear, palette.sun, 0.09)!,
            palette.mountainNear,
            Color.lerp(palette.mountainNear, palette.skyTop, 0.45)!,
          ],
        ).createShader(fillRect),
    );
    canvas.drawPath(
      ridgePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = palette.sun.withValues(alpha: 0.1),
    );
  }

  void _drawLake(Canvas canvas, Size size) {
    final top = size.height * 0.58;
    final rect = Rect.fromLTRB(0, top, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.skyBottom.withValues(alpha: 0.42),
            palette.mountainFar.withValues(alpha: 0.4),
            palette.mountainNear.withValues(alpha: 0.8),
          ],
        ).createShader(rect),
    );
    for (var i = 0; i < 24; i++) {
      final y = top + 8 + i * 5.1;
      final center = size.width * (0.18 + _hash(i, 91) * 0.64);
      final width = 12 + _hash(i, 93) * size.width * 0.2;
      canvas.drawLine(
        Offset(center - width / 2, y),
        Offset(center + width / 2, y),
        Paint()
          ..strokeWidth = 0.65
          ..color = palette.skyBottom.withValues(alpha: 0.1),
      );
    }
    final reflectionX = size.width * 0.72 + parallax.dx * 0.15;
    for (var i = 0; i < 26; i++) {
      final y = top + 5 + i * 4.2;
      final spread = 12 + i * 1.9;
      final jitter = (_hash(i, 71) - 0.5) * spread;
      final width = 8 + _hash(i, 73) * (18 + i * 1.3);
      final alpha = (0.12 * (1 - i / 30)).clamp(0.015, 0.12).toDouble();
      canvas.drawLine(
        Offset(reflectionX + jitter - width / 2, y),
        Offset(reflectionX + jitter + width / 2, y),
        Paint()
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round
          ..color = palette.sun.withValues(alpha: alpha),
      );
    }
  }

  void _drawFlow(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.66 + i * 0.07);
      final wave = _animated ? math.sin(phase * 6.28 + i * 0.8) * 18 : 8.0;
      final path = Path()
        ..moveTo(-50, y + 25)
        ..cubicTo(
          size.width * 0.18,
          y - 78 + wave,
          size.width * 0.63,
          y + 90 - wave,
          size.width + 50,
          y - 42,
        );
      final rect = Offset.zero & size;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24 - i * 4
          ..strokeCap = StrokeCap.round
          ..maskFilter = quality == ResolvedQuality.ultra
              ? const MaskFilter.blur(BlurStyle.normal, 11)
              : null
          ..shader = LinearGradient(
            colors: [
              palette.accent.withValues(alpha: 0),
              palette.accent.withValues(alpha: 0.16),
              palette.accentSecondary.withValues(alpha: 0.34),
              palette.sun.withValues(alpha: 0.2),
              palette.accent.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.11),
      );
    }
  }

  void _drawVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 1.15,
          colors: [
            palette.skyTop.withValues(alpha: 0),
            palette.skyTop.withValues(alpha: 0),
            palette.skyTop.withValues(alpha: palette.isLight ? 0.06 : 0.22),
          ],
          stops: const [0.35, 0.72, 1],
        ).createShader(rect),
    );
  }

  double _noise(double x, int seed) {
    final left = x.floor();
    final t = x - left;
    final smooth = t * t * (3 - 2 * t);
    return _hash(left, seed) * (1 - smooth) + _hash(left + 1, seed) * smooth;
  }

  double _hash(int value, int seed) {
    final n = math.sin(value * 127.1 + seed * 311.7) * 43758.5453123;
    return n - n.floor();
  }

  @override
  bool shouldRepaint(covariant _OrbitLandscapePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.palette != palette ||
      oldDelegate.quality != quality ||
      oldDelegate.parallax != parallax;
}
