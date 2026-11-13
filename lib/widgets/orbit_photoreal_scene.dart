import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_atmosphere.dart';
import '../visual_engine/orbit_frame_metrics.dart';
import '../visual_engine/orbit_motion_service.dart';
import '../visual_engine/orbit_palette.dart';
import '../visual_engine/orbit_scene_diagnostics.dart';

final class OrbitPhotorealScene extends StatefulWidget {
  const OrbitPhotorealScene({
    required this.palette,
    required this.quality,
    required this.motionEnabled,
    this.settings,
    this.active = true,
    super.key,
  });

  static int get debugBuildCount => _OrbitPhotorealSceneState.debugBuildCount;
  static set debugBuildCount(int value) =>
      _OrbitPhotorealSceneState.debugBuildCount = value;

  /// Global notifier indicating whether any active scroll view is moving.
  /// When true, ambient phase ticks are suspended so 100% of GPU raster
  /// budget is reserved for buttery-smooth scrolling.
  static final ValueNotifier<bool> isScrollingNotifier = ValueNotifier<bool>(
    false,
  );

  /// Safety reserve in logical pixels kept between a moving layer and the
  /// viewport edge so rounding never exposes the background.
  @visibleForTesting
  static const double layerEdgeReserve = 0.5;

  /// Maximum absolute shift (dp) a layer scaled by [scale] may translate
  /// inside a viewport of [viewportExtent] without exposing its edge.
  static double layerShiftLimit(double scale, double viewportExtent) =>
      math.max(0.0, (scale - 1.0) / 2 * viewportExtent - layerEdgeReserve);

  /// Clamps a layer shift so a plane scaled by [scale] always covers the
  /// viewport of [viewportExtent], whatever the gyro/pointer extremes are.
  static double clampLayerShift(
    double shift,
    double scale,
    double viewportExtent,
  ) => shift.clamp(
    -layerShiftLimit(scale, viewportExtent),
    layerShiftLimit(scale, viewportExtent),
  );

  /// Helper to handle scroll notifications and toggle [isScrollingNotifier].
  static bool handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      isScrollingNotifier.value = true;
    } else if (notification is ScrollEndNotification) {
      isScrollingNotifier.value = false;
    } else if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      isScrollingNotifier.value = false;
    }
    return false;
  }

  final OrbitPalette palette;
  final ResolvedQuality quality;
  final bool motionEnabled;
  final AppearanceSettings? settings;
  final bool active;

  @override
  State<OrbitPhotorealScene> createState() => _OrbitPhotorealSceneState();
}

final class _OrbitPhotorealSceneState extends State<OrbitPhotorealScene>
    with TickerProviderStateMixin {
  static const _metricsEnabled = bool.fromEnvironment('ORBIT_FRAME_METRICS');
  @visibleForTesting
  static int debugBuildCount = 0;

  late final AnimationController _controller;
  late final AnimationController _atmosphereController;
  OrbitAtmosphere? _fromAtmosphere;
  OrbitAtmosphere? _toAtmosphere;

  final OrbitFrameMetrics _frameMetrics = OrbitFrameMetrics();
  Offset _pointer = Offset.zero;
  Offset _sensorTilt = Offset.zero;
  double _phase = 0;
  int _lastFrameMs = 0;
  Timer? _metricsTimer;
  double _refreshRateHz = 60;
  bool _subscribedMotion = false;

  @override
  void initState() {
    super.initState();
    unawaited(OrbitSceneDiagnostics.instance.ensureVerified());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    )..addListener(_tick);
    _atmosphereController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    final views = SchedulerBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) _refreshRateHz = views.first.display.refreshRate;
    if (_metricsEnabled) {
      SchedulerBinding.instance.addTimingsCallback(_recordTimings);
      _metricsTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _logMetrics(),
      );
    }
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionSubscription();
  }

  void _syncMotionSubscription() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final gyroActive =
        widget.active &&
        widget.motionEnabled &&
        (widget.settings?.gyroEnabled ?? true) &&
        (widget.settings?.gyroIntensity != GyroIntensity.off) &&
        !reduceMotion;
    if (gyroActive && !_subscribedMotion) {
      _subscribedMotion = true;
      OrbitMotionService.instance.acquire();
      OrbitMotionService.instance.tiltNotifier.addListener(_onTiltChanged);
    } else if (!gyroActive && _subscribedMotion) {
      _subscribedMotion = false;
      OrbitMotionService.instance.tiltNotifier.removeListener(_onTiltChanged);
      OrbitMotionService.instance.release();
      _sensorTilt = Offset.zero;
    }
  }

  void _onTiltChanged() {
    if (!mounted || !widget.active || !_subscribedMotion) return;
    if (OrbitPhotorealScene.isScrollingNotifier.value) return;
    final tilt = OrbitMotionService.instance.tiltNotifier.value;
    setState(() => _sensorTilt = tilt);
  }

  void _recordTimings(List<FrameTiming> frames) {
    _frameMetrics.addAll(frames);
  }

  void _logMetrics() {
    final snapshot = _frameMetrics.snapshot(refreshRateHz: _refreshRateHz);
    debugPrint('[ORBIT frame metrics] ${jsonEncode(snapshot)}');
    _frameMetrics.clearWindow();
  }

  void _tick() {
    if (OrbitPhotorealScene.isScrollingNotifier.value) return;
    const interval = 100;
    final now = clock.now().millisecondsSinceEpoch;
    if (now - _lastFrameMs < interval) return;
    _lastFrameMs = now;
    if (mounted) setState(() => _phase = _controller.value * math.pi * 2);
  }

  @override
  void didUpdateWidget(covariant OrbitPhotorealScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotionSubscription();
    if (widget.settings?.atmosphereMode != oldWidget.settings?.atmosphereMode &&
        widget.settings != null &&
        oldWidget.settings != null) {
      if (widget.quality == ResolvedQuality.static ||
          MediaQuery.maybeOf(context)?.disableAnimations == true) {
        _fromAtmosphere = null;
        _toAtmosphere = null;
        _atmosphereController.value = 1.0;
        if (mounted) setState(() {});
      } else {
        _fromAtmosphere = OrbitAtmosphere.fromSettings(
          oldWidget.settings!,
          oldWidget.palette,
        );
        _toAtmosphere = OrbitAtmosphere.fromSettings(
          widget.settings!,
          widget.palette,
        );
        _atmosphereController.forward(from: 0.0);
      }
    }
    _sync();
  }

  void _sync() {
    final enabled =
        widget.active &&
        widget.motionEnabled &&
        widget.quality != ResolvedQuality.static;
    if (enabled) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    if (_subscribedMotion) {
      OrbitMotionService.instance.tiltNotifier.removeListener(_onTiltChanged);
      OrbitMotionService.instance.release();
      _subscribedMotion = false;
    }
    if (_metricsEnabled) {
      SchedulerBinding.instance.removeTimingsCallback(_recordTimings);
      _metricsTimer?.cancel();
    }
    _atmosphereController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugBuildCount++;
    final palette = widget.palette;
    final OrbitAtmosphere atmosphere;
    if (_atmosphereController.isAnimating &&
        _fromAtmosphere != null &&
        _toAtmosphere != null) {
      atmosphere = OrbitAtmosphere.lerp(
        _fromAtmosphere!,
        _toAtmosphere!,
        Curves.easeInOutCubic.transform(_atmosphereController.value),
      );
    } else {
      atmosphere = widget.settings != null
          ? OrbitAtmosphere.fromSettings(widget.settings!, palette)
          : OrbitAtmosphere.fromDateTime(clock.now(), palette);
    }
    final effectivePointer = Offset(
      (_pointer.dx + _sensorTilt.dx * 0.75).clamp(-0.85, 0.85),
      (_pointer.dy + _sensorTilt.dy * 0.75).clamp(-0.85, 0.85),
    );

    final orientation =
        MediaQuery.maybeOf(context)?.orientation ?? Orientation.portrait;
    final brightness = Theme.of(context).brightness;
    final mode = widget.settings?.atmosphereMode ?? AtmosphereMode.automatic;
    final Map<String, String> layerPaths = switch (palette.profile) {
      OrbitProfile.one => {
        'sky': atmosphere.skyAssetPath,
        'far': 'assets/photoreal/optimized/one_far.webp',
        'mid': 'assets/photoreal/optimized/one_mid.webp',
        'foreground': 'assets/photoreal/optimized/one_fg.webp',
      },
      OrbitProfile.atelier => {
        'base': 'assets/photoreal/optimized/atelier.jpg',
        'foreground': 'assets/photoreal/optimized/atelier_foreground.webp',
      },
      OrbitProfile.flow => {
        'light_field': palette.isLight
            ? 'assets/photoreal/optimized/flow_light.jpg'
            : 'assets/photoreal/optimized/flow_dark.jpg',
      },
      OrbitProfile.zen => {
        'base': 'assets/photoreal/optimized/zen.jpg',
        'foreground': 'assets/photoreal/optimized/zen_foreground.webp',
      },
    };

    OrbitSceneDiagnostics.instance.recordAtmosphereApplication(
      profile: palette.profile,
      mode: mode,
      period: atmosphere.timeOfDay,
      brightness: brightness,
      quality: widget.quality,
      orientation: orientation,
      renderer: 'Photoreal',
      layerAssetPaths: layerPaths,
    );

    return Listener(
      onPointerHover: (event) {
        if (!widget.active || !widget.motionEnabled) return;
        final size = MediaQuery.sizeOf(context);
        _pointer = Offset(
          (event.localPosition.dx / size.width - 0.5).clamp(-0.5, 0.5),
          (event.localPosition.dy / size.height - 0.5).clamp(-0.5, 0.5),
        );
      },
      onPointerDown: (event) {
        if (!widget.active || !widget.motionEnabled) return;
        final size = MediaQuery.sizeOf(context);
        _pointer = Offset(
          (event.localPosition.dx / size.width - 0.5).clamp(-0.5, 0.5),
          (event.localPosition.dy / size.height - 0.5).clamp(-0.5, 0.5),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (palette.profile == OrbitProfile.flow)
            _FlowLightField(
              palette: palette,
              phase: _phase,
              pointer: effectivePointer,
              atmosphere: atmosphere,
              motionEnabled: widget.motionEnabled,
            )
          else
            _PhotoEnvironment(
              palette: palette,
              phase: _phase,
              pointer: effectivePointer,
              atmosphere: atmosphere,
              motionEnabled: widget.motionEnabled,
              quality: widget.quality,
              settings: widget.settings,
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: palette.isLight
                    ? [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                        palette.skyTop.withValues(alpha: 0.20),
                      ]
                    : [
                        palette.skyTop.withValues(alpha: 0.10),
                        Colors.transparent,
                        palette.skyTop.withValues(alpha: 0.25),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _PhotoEnvironment extends StatelessWidget {
  const _PhotoEnvironment({
    required this.palette,
    required this.phase,
    required this.pointer,
    required this.atmosphere,
    required this.motionEnabled,
    required this.quality,
    this.settings,
  });

  final OrbitPalette palette;
  final double phase;
  final Offset pointer;
  final OrbitAtmosphere atmosphere;
  final bool motionEnabled;
  final ResolvedQuality quality;
  final AppearanceSettings? settings;

  @override
  Widget build(BuildContext context) {
    if (palette.profile == OrbitProfile.one &&
        motionEnabled &&
        quality != ResolvedQuality.static) {
      return _OrbitOnePhotorealPlanes(
        palette: palette,
        phase: phase,
        pointer: pointer,
        atmosphere: atmosphere,
        motionEnabled: motionEnabled,
        settings: settings,
      );
    }

    final asset = switch (palette.profile) {
      OrbitProfile.atelier => 'assets/photoreal/optimized/atelier.jpg',
      OrbitProfile.zen => 'assets/photoreal/optimized/zen.jpg',
      _ => 'assets/photoreal/optimized/one.jpg',
    };
    final foreground = asset.replaceAll('.jpg', '_foreground.webp');
    final dx = pointer.dx * 18 + math.sin(phase) * 2.5;
    final dy = pointer.dy * 12 + math.cos(phase) * 1.5;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Worst-case (smallest) scale each layer reaches while breathing, so
        // the shift limit always matches the layer's real coverage margin.
        final baseScaleMin = 1.12 - (motionEnabled ? 0.0015 : 0.0);
        final fgScaleMin = 1.16 - (motionEnabled ? 0.003 : 0.0);
        final viewport = constraints.biggest;
        final baseDx = OrbitPhotorealScene.clampLayerShift(
          dx * 0.32,
          baseScaleMin,
          viewport.width,
        );
        final baseDy = OrbitPhotorealScene.clampLayerShift(
          dy * 0.28,
          baseScaleMin,
          viewport.height,
        );
        final fgDxClamped = OrbitPhotorealScene.clampLayerShift(
          dx,
          fgScaleMin,
          viewport.width,
        );
        final fgDyClamped = OrbitPhotorealScene.clampLayerShift(
          dy,
          fgScaleMin,
          viewport.height,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: atmosphere.skyGradientColors,
                ),
              ),
            ),
            if (atmosphere.starlightIntensity > 0)
              CustomPaint(
                painter: _StarFieldPainter(
                  starlightIntensity: atmosphere.starlightIntensity,
                  phase: phase,
                ),
              ),
            RepaintBoundary(
              child: Transform.translate(
                offset: Offset(baseDx, baseDy),
                child: Transform.scale(
                  scale:
                      1.12 + (motionEnabled ? math.sin(phase) * 0.0015 : 0.0),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(atmosphere.colorMatrix),
                    child: Image.asset(
                      asset,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [palette.skyTop, palette.skyBottom],
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
            RepaintBoundary(
              child: Transform.translate(
                offset: Offset(fgDxClamped, fgDyClamped),
                child: Transform.scale(
                  scale: 1.16 + (motionEnabled ? math.sin(phase) * 0.003 : 0.0),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(atmosphere.colorMatrix),
                    child: Image.asset(
                      foreground,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            _AtmosphericLight(
              palette: palette,
              phase: phase,
              pointer: pointer,
              atmosphere: atmosphere,
              motionEnabled: motionEnabled,
            ),
          ],
        );
      },
    );
  }
}

final class _OrbitOnePhotorealPlanes extends StatelessWidget {
  const _OrbitOnePhotorealPlanes({
    required this.palette,
    required this.phase,
    required this.pointer,
    required this.atmosphere,
    required this.motionEnabled,
    this.settings,
  });

  /// Per-plane overscan factors. Each factor guarantees that the plane's
  /// half-margin ((scale - 1) / 2 * viewport width) covers its maximum
  /// parallax amplitude on screens as narrow as 320 dp:
  /// - sky amplitude ≤ 1.8 dp → 1.03 (margin 4.3 dp @320)
  /// - far amplitude ≤ 4.9 dp → 1.05 (margin 7.7 dp @320)
  /// - mid amplitude ≤ 11.2 dp → 1.085 (margin 13.1 dp @320)
  /// - fg amplitude ≤ 22.7 dp → 1.15 (margin 23.5 dp @320)
  static const double _skyOverscan = 1.03;
  static const double _farOverscan = 1.05;
  static const double _midOverscan = 1.085;
  static const double _fgOverscan = 1.15;

  final OrbitPalette palette;
  final double phase;
  final Offset pointer;
  final OrbitAtmosphere atmosphere;
  final bool motionEnabled;
  final AppearanceSettings? settings;

  @override
  Widget build(BuildContext context) {
    final intensity = settings?.gyroIntensity ?? GyroIntensity.enhanced;
    final multiplier = switch (intensity) {
      GyroIntensity.off => 0.0,
      GyroIntensity.subtle => 0.50,
      GyroIntensity.enhanced => 1.0,
    };

    final breathingX = motionEnabled ? math.sin(phase) * 1.2 : 0.0;
    final breathingY = motionEnabled ? math.cos(phase) * 0.8 : 0.0;

    // Amplitudes matching target specifications:
    // Sky: 1-2 dp
    // Far landscape: 4-6 dp
    // Midground: 10-14 dp
    // Foreground: 22-28 dp
    final skyDx = (pointer.dx * 1.5 * multiplier) + breathingX * 0.2;
    final skyDy = (pointer.dy * 1.0 * multiplier) + breathingY * 0.2;

    final farDx = (pointer.dx * 5.0 * multiplier) + breathingX * 0.5;
    final farDy = (pointer.dy * 3.5 * multiplier) + breathingY * 0.4;

    final midDx = (pointer.dx * 12.0 * multiplier) + breathingX * 0.8;
    final midDy = (pointer.dy * 8.0 * multiplier) + breathingY * 0.6;

    final fgDx = (pointer.dx * 25.0 * multiplier) + breathingX * 1.2;
    final fgDy = (pointer.dy * 16.0 * multiplier) + breathingY * 0.9;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        // Parallax shifts are clamped to each plane's overscan margin so no
        // gyro or pointer extreme can ever expose the viewport edge.
        Offset clamped(double dx, double dy, double scale) => Offset(
          OrbitPhotorealScene.clampLayerShift(dx, scale, viewport.width),
          OrbitPhotorealScene.clampLayerShift(dy, scale, viewport.height),
        );

        final skyShift = clamped(skyDx, skyDy, _skyOverscan);
        final farShift = clamped(farDx, farDy, _farOverscan);
        final midShift = clamped(midDx, midDy, _midOverscan);
        final fgShift = clamped(fgDx, fgDy, _fgOverscan);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Plane 1: Sky, Sun/Moon & Starlight
            RepaintBoundary(
              child: Transform.translate(
                offset: skyShift,
                child: Transform.scale(
                  scale: _skyOverscan,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: atmosphere.skyGradientColors,
                          ),
                        ),
                      ),
                      if (atmosphere.starlightIntensity > 0)
                        CustomPaint(
                          painter: _StarFieldPainter(
                            starlightIntensity: atmosphere.starlightIntensity,
                            phase: phase,
                          ),
                        ),
                      Opacity(
                        opacity: (1.0 - atmosphere.skyGradientWeight * 0.4)
                            .clamp(0.45, 0.95),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(
                            atmosphere.skyColorMatrix,
                          ),
                          child: Image.asset(
                            atmosphere.skyAssetPath,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) =>
                                OrbitAssetErrorView(
                                  layerName: 'one_sky',
                                  errorMessage: error.toString(),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Atmospheric Sun/Celestial Body & Sky Tint
            _AtmosphericLight(
              palette: palette,
              phase: phase,
              pointer: pointer,
              atmosphere: atmosphere,
              motionEnabled: motionEnabled,
            ),
            // Plane 2: Far Landscape (Horizon hills)
            RepaintBoundary(
              child: Transform.translate(
                offset: farShift,
                child: Transform.scale(
                  scale: _farOverscan,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(atmosphere.colorMatrix),
                    child: Image.asset(
                      'assets/photoreal/optimized/one_far.webp',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          OrbitAssetErrorView(
                            layerName: 'one_far',
                            errorMessage: error.toString(),
                          ),
                    ),
                  ),
                ),
              ),
            ),
            // Aerial Perspective Haze (Atmospheric depth between far hills and midground)
            RepaintBoundary(
              child: Transform.translate(
                offset: Offset(
                  (farShift.dx + midShift.dx) * 0.5,
                  (farShift.dy + midShift.dy) * 0.5,
                ),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          atmosphere.sunColor.withValues(alpha: 0.0),
                          atmosphere.sunColor.withValues(alpha: 0.03),
                          atmosphere.sunColor.withValues(alpha: 0.07),
                        ],
                        stops: const [0.45, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Plane 3: Midground (Trees & slopes)
            RepaintBoundary(
              child: Transform.translate(
                offset: midShift,
                child: Transform.scale(
                  scale: _midOverscan,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(atmosphere.colorMatrix),
                    child: Image.asset(
                      'assets/photoreal/optimized/one_mid.webp',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          OrbitAssetErrorView(
                            layerName: 'one_mid',
                            errorMessage: error.toString(),
                          ),
                    ),
                  ),
                ),
              ),
            ),
            // Plane 4: Foreground (Meadow & foreground details)
            RepaintBoundary(
              child: Transform.translate(
                offset: fgShift,
                child: Transform.scale(
                  scale: _fgOverscan,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(atmosphere.colorMatrix),
                    child: Image.asset(
                      'assets/photoreal/optimized/one_fg.webp',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          OrbitAssetErrorView(
                            layerName: 'one_fg',
                            errorMessage: error.toString(),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _AtmosphericLight extends StatelessWidget {
  const _AtmosphericLight({
    required this.palette,
    required this.phase,
    required this.pointer,
    required this.atmosphere,
    required this.motionEnabled,
  });

  final OrbitPalette palette;
  final double phase;
  final Offset pointer;
  final OrbitAtmosphere atmosphere;
  final bool motionEnabled;

  @override
  Widget build(BuildContext context) {
    final shift = motionEnabled
        ? math.sin(phase) * 0.025 + pointer.dx * 0.08
        : 0.0;
    final sunCenter = Alignment(
      (atmosphere.sunAlignment.x + shift).clamp(-1.0, 1.0),
      (atmosphere.sunAlignment.y + (motionEnabled ? pointer.dy * 0.05 : 0.0))
          .clamp(-1.0, 1.0),
    );
    final sunColor = atmosphere.sunColor;
    final sunRadius = atmosphere.sunRadius;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient / Solar glow
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: sunCenter,
                radius: sunRadius,
                colors: [
                  sunColor.withValues(
                    alpha:
                        (atmosphere.celestialHaloAlpha *
                                (palette.isLight ? 0.75 : 0.9))
                            .clamp(0.0, 1.0),
                  ),
                  sunColor.withValues(
                    alpha: (atmosphere.celestialHaloAlpha * 0.35).clamp(
                      0.0,
                      1.0,
                    ),
                  ),
                  sunColor.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Distinct Celestial Body (Sun or Moon)
          Align(
            alignment: sunCenter,
            child: _CelestialBodyWidget(
              atmosphere: atmosphere,
              palette: palette,
              phase: phase,
            ),
          ),
          if (atmosphere.ambientSkyTint.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: atmosphere.ambientSkyTint,
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.skyBottom.withValues(alpha: 0),
                      palette.skyBottom.withValues(
                        alpha: palette.isLight ? 0.08 : 0.12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (motionEnabled)
            CustomPaint(
              painter: _AtmosphericParticlePainter(
                phase: phase,
                pointer: pointer,
                atmosphere: atmosphere,
                palette: palette,
              ),
            ),
        ],
      ),
    );
  }
}

final class _CelestialBodyWidget extends StatelessWidget {
  const _CelestialBodyWidget({
    required this.atmosphere,
    required this.palette,
    required this.phase,
  });

  final OrbitAtmosphere atmosphere;
  final OrbitPalette palette;
  final double phase;

  @override
  Widget build(BuildContext context) {
    switch (atmosphere.timeOfDay) {
      case OrbitTimeOfDay.night:
        // Silvery-cyan luminous Moon
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.25, -0.25),
              radius: 0.85,
              colors: [Color(0xFFFFFFFF), Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF90CAF9).withValues(alpha: 0.65),
                blurRadius: 36,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.85),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
        );

      case OrbitTimeOfDay.sunset:
        // Fiery glowing vermilion-amber sunset orb
        return Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFFECB3), Color(0xFFFF9800), Color(0xFFFF3D00)],
              stops: [0.0, 0.45, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3D00).withValues(alpha: 0.80),
                blurRadius: 60,
                spreadRadius: 16,
              ),
              BoxShadow(
                color: const Color(0xFFFF9100).withValues(alpha: 0.65),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
        );

      case OrbitTimeOfDay.dawn:
        // Warm rose-golden rising morning sun
        return Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFFF3E0), Color(0xFFFFCCBC), Color(0xFFFF8A65)],
              stops: [0.0, 0.50, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8A65).withValues(alpha: 0.65),
                blurRadius: 45,
                spreadRadius: 12,
              ),
              BoxShadow(
                color: const Color(0xFFFFE0B2).withValues(alpha: 0.60),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
          ),
        );

      case OrbitTimeOfDay.day:
        // Brilliant radiant daytime sun
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFF9C4), Color(0xFFFFEE58)],
              stops: [0.0, 0.45, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFEE58).withValues(alpha: 0.55),
                blurRadius: 42,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.90),
                blurRadius: 18,
                spreadRadius: 3,
              ),
            ],
          ),
        );
    }
  }
}

final class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter({
    required this.starlightIntensity,
    required this.phase,
  });

  final double starlightIntensity;
  final double phase;

  static final List<_StarData> _stars = _generateStars();

  static List<_StarData> _generateStars() {
    final list = <_StarData>[];
    int seed = 421337;
    double rand() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    for (int i = 0; i < 48; i++) {
      final x = rand();
      final y = rand() * 0.58;
      final radius = 0.75 + rand() * 1.4;
      final phaseOffset = rand() * math.pi * 2;
      final baseAlpha = 0.45 + rand() * 0.5;
      list.add(
        _StarData(
          x: x,
          y: y,
          radius: radius,
          phaseOffset: phaseOffset,
          baseAlpha: baseAlpha,
        ),
      );
    }
    return list;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (starlightIntensity <= 0.0 || size.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final star in _stars) {
      final twinkle = 0.7 + 0.3 * math.sin(phase * 2.5 + star.phaseOffset);
      final alpha = (star.baseAlpha * twinkle * starlightIntensity).clamp(
        0.0,
        1.0,
      );
      paint.color = Color.fromRGBO(235, 245, 255, alpha);
      final center = Offset(star.x * size.width, star.y * size.height);
      canvas.drawCircle(center, star.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) =>
      oldDelegate.starlightIntensity != starlightIntensity ||
      oldDelegate.phase != phase;
}

final class _StarData {
  const _StarData({
    required this.x,
    required this.y,
    required this.radius,
    required this.phaseOffset,
    required this.baseAlpha,
  });

  final double x;
  final double y;
  final double radius;
  final double phaseOffset;
  final double baseAlpha;
}

final class _FlowLightField extends StatelessWidget {
  const _FlowLightField({
    required this.palette,
    required this.phase,
    required this.pointer,
    required this.atmosphere,
    required this.motionEnabled,
  });

  final OrbitPalette palette;
  final double phase;
  final Offset pointer;
  final OrbitAtmosphere atmosphere;
  final bool motionEnabled;

  @override
  Widget build(BuildContext context) {
    final asset = palette.isLight
        ? 'assets/photoreal/optimized/flow_light.jpg'
        : 'assets/photoreal/optimized/flow_dark.jpg';
    final offset = Offset(
      pointer.dx * 10 + math.sin(phase) * 2,
      pointer.dy * 7 + math.cos(phase) * 1.5,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: 1.035,
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(atmosphere.colorMatrix),
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: debugFlowGradientColors(palette),
                        stops: const [0, 0.38, 0.72, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _FlowPainter(
              palette: palette,
              phase: phase,
              pointer: pointer,
            ),
          ),
        ),
        if (motionEnabled)
          CustomPaint(
            painter: _AtmosphericParticlePainter(
              phase: phase,
              pointer: pointer,
              atmosphere: atmosphere,
              palette: palette,
            ),
          ),
      ],
    );
  }
}

@visibleForTesting
List<Color> debugFlowGradientColors(OrbitPalette palette) => palette.isLight
    ? const [
        Color(0xFFF2FBFD),
        Color(0xFFD9EFF4),
        Color(0xFFEAE7F8),
        Color(0xFFF8FCFE),
      ]
    : const [
        Color(0xFF061B2A),
        Color(0xFF10384B),
        Color(0xFF171C3E),
        Color(0xFF07111F),
      ];

final class _FlowPainter extends CustomPainter {
  const _FlowPainter({
    required this.palette,
    required this.phase,
    required this.pointer,
  });

  final OrbitPalette palette;
  final double phase;
  final Offset pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeShader = LinearGradient(
      colors: [
        palette.textPrimary.withValues(alpha: 0),
        palette.textPrimary.withValues(alpha: palette.isLight ? 0.16 : 0.34),
        palette.accentSecondary.withValues(alpha: 0.22),
        palette.textPrimary.withValues(alpha: 0),
      ],
    ).createShader(rect);

    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.28 + i * 0.22);
      final drift = math.sin(phase + i * 0.9) * 16 + pointer.dx * 22;
      final lift = math.cos(phase * 0.7 + i) * 12 + pointer.dy * 14;
      final path = Path()
        ..moveTo(-size.width * 0.15, y + lift)
        ..cubicTo(
          size.width * 0.22,
          y - 60 + drift,
          size.width * 0.66,
          y + 68 - drift,
          size.width * 1.15,
          y - 24 + lift,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i.isEven ? 1.1 : 0.65
          ..strokeCap = StrokeCap.round
          ..shader = strokeShader,
      );
    }
    final glow = Rect.fromCircle(
      center: Offset(size.width * 0.76, size.height * 0.24),
      radius: size.shortestSide * 0.42,
    );
    canvas.drawCircle(
      glow.center,
      glow.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.accentSecondary.withValues(
              alpha: palette.isLight ? 0.08 : 0.12,
            ),
            palette.accentSecondary.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
  }

  @override
  bool shouldRepaint(covariant _FlowPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.pointer != pointer ||
      oldDelegate.palette.isLight != palette.isLight ||
      oldDelegate.palette.textPrimary != palette.textPrimary ||
      oldDelegate.palette.accent != palette.accent ||
      oldDelegate.palette.accentSecondary != palette.accentSecondary;
}

final class _AtmosphericParticlePainter extends CustomPainter {
  const _AtmosphericParticlePainter({
    required this.phase,
    required this.pointer,
    required this.atmosphere,
    required this.palette,
  });

  final double phase;
  final Offset pointer;
  final OrbitAtmosphere atmosphere;
  final OrbitPalette palette;

  static const _particles =
      <({double x, double y, double radius, double speed, double drift})>[
        (x: 0.18, y: 0.22, radius: 1.8, speed: 0.7, drift: 0.3),
        (x: 0.32, y: 0.45, radius: 1.2, speed: 0.9, drift: 0.6),
        (x: 0.48, y: 0.15, radius: 2.4, speed: 0.5, drift: 0.2),
        (x: 0.65, y: 0.38, radius: 1.5, speed: 1.1, drift: 0.8),
        (x: 0.78, y: 0.52, radius: 2.0, speed: 0.8, drift: 0.4),
        (x: 0.85, y: 0.28, radius: 1.1, speed: 1.3, drift: 0.5),
        (x: 0.24, y: 0.68, radius: 1.7, speed: 0.6, drift: 0.7),
        (x: 0.55, y: 0.72, radius: 2.2, speed: 0.7, drift: 0.3),
        (x: 0.72, y: 0.82, radius: 1.3, speed: 1.0, drift: 0.9),
        (x: 0.12, y: 0.85, radius: 1.6, speed: 0.8, drift: 0.2),
        (x: 0.42, y: 0.33, radius: 2.1, speed: 0.6, drift: 0.5),
        (x: 0.61, y: 0.19, radius: 1.4, speed: 1.2, drift: 0.4),
        (x: 0.88, y: 0.64, radius: 1.9, speed: 0.7, drift: 0.6),
        (x: 0.38, y: 0.58, radius: 1.0, speed: 1.4, drift: 0.3),
        (x: 0.74, y: 0.12, radius: 2.3, speed: 0.5, drift: 0.7),
        (x: 0.29, y: 0.88, radius: 1.5, speed: 0.9, drift: 0.4),
        (x: 0.52, y: 0.48, radius: 1.8, speed: 0.8, drift: 0.6),
        (x: 0.82, y: 0.75, radius: 1.2, speed: 1.1, drift: 0.5),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final particleColor = atmosphere.timeOfDay == OrbitTimeOfDay.night
        ? const Color(0xFFE2E8F0)
        : atmosphere.sunColor;

    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final driftX =
          math.sin(phase * p.speed + i) * 14 * p.drift +
          pointer.dx * (18 * p.radius);
      final driftY =
          math.cos(phase * p.speed * 0.8 + i * 1.5) * 10 * p.drift +
          pointer.dy * (14 * p.radius);
      final px = (p.x * size.width + driftX) % size.width;
      final py = (p.y * size.height + driftY) % size.height;

      final pulse = (math.sin(phase * 1.2 + i * 2) * 0.5 + 0.5);
      final baseAlpha = atmosphere.timeOfDay == OrbitTimeOfDay.night
          ? (0.05 + pulse * 0.12)
          : (palette.isLight ? 0.03 + pulse * 0.06 : 0.04 + pulse * 0.08);

      paint.color = particleColor.withValues(alpha: baseAlpha);
      canvas.drawCircle(Offset(px, py), p.radius * 0.75, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphericParticlePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.pointer != pointer ||
      oldDelegate.atmosphere.timeOfDay != atmosphere.timeOfDay;
}
