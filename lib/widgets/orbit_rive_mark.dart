import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

import '../l10n/orbit_localizations.dart';
import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_palette.dart';
import 'orbit_environment.dart';
import 'orbit_logo.dart';

final class OrbitRiveMark extends StatefulWidget {
  static bool runtimeAvailable = true;
  static Object? runtimeInitializationError;

  const OrbitRiveMark({
    required this.palette,
    required this.quality,
    this.atmospheric = false,
    this.diagnosticsId = 'today',
    this.onError,
    this.onPulseReady,
    super.key,
  });

  final OrbitPalette palette;
  final ResolvedQuality quality;
  final bool atmospheric;
  final String diagnosticsId;
  final ValueChanged<Object>? onError;
  final ValueChanged<VoidCallback>? onPulseReady;

  @override
  State<OrbitRiveMark> createState() => _OrbitRiveMarkState();
}

final class _OrbitRiveMarkState extends State<OrbitRiveMark>
    with SingleTickerProviderStateMixin {
  rive.FileLoader? _loader;
  rive.RiveWidgetController? _controller;
  rive.TriggerInput? _pulse;
  Timer? _runtimeProbe;
  late final AnimationController _motion;
  bool _failureReported = false;
  int _pulseCount = 0;
  int _stateMachineAdvanceCount = 0;
  DateTime? _lastProbeAt;
  double _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _syncMotion();
  }

  void _syncMotion() {
    if (widget.quality == ResolvedQuality.static ||
        !OrbitRiveMark.runtimeAvailable) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant OrbitRiveMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  String get _asset => widget.atmospheric
      ? 'assets/rive/orbit_atmosphere.riv'
      : 'assets/rive/orbit_mark.riv';

  void _updateDiagnostics(Map<String, Object?> values) {
    if (!mounted) return;
    OrbitEnvironment.read(context).quality.updateRuntimeDiagnostics(
      widget.diagnosticsId,
      <String, Object?>{
        'requestedRenderer': 'rive',
        'rivFile': _asset,
        ...values,
      },
    );
  }

  void _bindController(rive.RiveWidgetController controller) {
    if (identical(_controller, controller)) return;
    _pulse?.dispose();
    _runtimeProbe?.cancel();
    _controller = controller;
    // The .riv files expose Pulse as a state-machine trigger. Data Binding is
    // not required for this single self-contained interaction.
    try {
      // ignore: deprecated_member_use
      _pulse = controller.stateMachine.trigger('Pulse');
      _updateDiagnostics(<String, Object?>{
        'actualRenderer': 'rive',
        'nativePending': false,
        'rivLoaded': true,
        'riveAssetLoaded': true,
        'nativeArtboardAnimationProven': false,
        'flutterTransformActive': _motion.isAnimating,
        'staticFallback': false,
        'artboardReady': true,
        'artboard': widget.atmospheric ? 'OrbitAtmosphere' : 'OrbitMark',
        'stateMachineReady': true,
        'stateMachine': controller.stateMachine.name,
        'controllerActive': controller.active,
        'tickerActive': controller.isTickerActive,
        'stateMachineAdvancing': false,
        'stateMachineAdvanceCount': _stateMachineAdvanceCount,
        'pulseAvailable': _pulse != null,
        'pulseCount': _pulseCount,
        'lastError': null,
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _probeRuntime());
      _runtimeProbe = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _probeRuntime(),
      );
      final callback = widget.onPulseReady;
      if (callback != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(_controller, controller)) {
            callback(_firePulse);
          }
        });
      }
    } catch (error) {
      _reportFailure(error);
    }
  }

  void _probeRuntime() {
    final controller = _controller;
    if (!mounted || controller == null || _failureReported) return;
    try {
      final now = DateTime.now();
      final previous = _lastProbeAt;
      final delta = previous == null
          ? 0.0
          : now.difference(previous).inMicroseconds / 1000000;
      _lastProbeAt = now;
      _elapsedSeconds += delta;
      final advancing = controller.stateMachine.advanceAndApply(delta);
      controller.scheduleRepaint();
      if (advancing) _stateMachineAdvanceCount++;
      _updateDiagnostics(<String, Object?>{
        'actualRenderer': advancing ? 'rive' : 'static',
        'nativePending': false,
        'visualMotionMode': 'flutter-transform-fallback',
        'nativeArtboardAnimationProven': false,
        'flutterTransformActive': _motion.isAnimating,
        'staticFallback': !advancing,
        'stateMachineAdvancing': advancing,
        'stateMachineAdvanceCount': _stateMachineAdvanceCount,
        'lastAdvanceSeconds': delta,
        'elapsedSeconds': _elapsedSeconds,
        'fallbackReason': advancing
            ? null
            : 'Rive state machine is not advancing',
      });
    } catch (error) {
      _reportFailure(error);
    }
  }

  void _firePulse() {
    if (_pulse != null) {
      _pulse!.fire();
      _pulseCount++;
      _updateDiagnostics(<String, Object?>{
        'actualRenderer': 'rive',
        'pulseAvailable': true,
        'pulseCount': _pulseCount,
        'lastPulseAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
    HapticFeedback.lightImpact();
  }

  void _reportFailure(Object error) {
    if (_failureReported) return;
    _failureReported = true;
    _runtimeProbe?.cancel();
    _updateDiagnostics(<String, Object?>{
      'actualRenderer': 'static',
      'nativePending': false,
      'rivLoaded': false,
      'riveAssetLoaded': false,
      'nativeArtboardAnimationProven': false,
      'flutterTransformActive': false,
      'staticFallback': true,
      'artboardReady': false,
      'stateMachineReady': false,
      'pulseAvailable': false,
      'fallbackReason': error.toString(),
      'lastError': error.toString(),
    });
    final callback = widget.onError;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(error);
    });
  }

  Widget _fallback({bool loading = false}) {
    if (widget.atmospheric) return const SizedBox.shrink();
    return Center(
      child: OrbitLogo(
        palette: widget.palette,
        size: loading ? 64 : 82,
        animate: loading,
      ),
    );
  }

  @override
  void dispose() {
    _runtimeProbe?.cancel();
    _pulse?.dispose();
    _loader?.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quality == ResolvedQuality.static) {
      _updateDiagnostics(<String, Object?>{
        'actualRenderer': 'static',
        'nativePending': false,
        'nativeArtboardAnimationProven': false,
        'flutterTransformActive': false,
        'staticFallback': true,
        'fallbackReason': 'Quality or system constraints',
      });
      return _fallback();
    }
    if (!OrbitRiveMark.runtimeAvailable) {
      _reportFailure(
        OrbitRiveMark.runtimeInitializationError ??
            'Rive native runtime is unavailable',
      );
      return _fallback();
    }
    _updateDiagnostics(<String, Object?>{
      'tickerModeEnabled': TickerMode.valuesOf(context).enabled,
    });
    return Semantics(
      label: widget.atmospheric
          ? context.l10n.riveAtmosphereSemantics
          : context.l10n.riveMarkSemantics,
      button: !widget.atmospheric,
      child: GestureDetector(
        key: Key(widget.atmospheric ? 'rive-atmosphere' : 'rive-mark'),
        behavior: HitTestBehavior.translucent,
        onTap: widget.atmospheric ? null : _firePulse,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, child) {
            final angle = widget.atmospheric
                ? (_motion.value - 0.5) * 0.06
                : _motion.value * 6.283185307179586;
            return Transform.rotate(angle: angle, child: child);
          },
          child: rive.RiveWidgetBuilder(
            fileLoader: _loader ??= rive.FileLoader.fromAsset(
              _asset,
              riveFactory: rive.Factory.flutter,
            ),
            stateMachineSelector: rive.StateMachineSelector.byName('OrbitLoop'),
            artboardSelector: rive.ArtboardSelector.byName(
              widget.atmospheric ? 'OrbitAtmosphere' : 'OrbitMark',
            ),
            builder: (context, state) {
              if (state is rive.RiveLoaded) {
                _bindController(state.controller);
                return RepaintBoundary(
                  child: rive.RiveWidget(
                    controller: state.controller,
                    fit: widget.atmospheric ? rive.Fit.cover : rive.Fit.contain,
                  ),
                );
              }
              if (state is rive.RiveFailed) {
                _reportFailure(state.error);
                return _fallback();
              }
              return _fallback(loading: true);
            },
          ),
        ),
      ),
    );
  }
}
