import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../l10n/orbit_localizations.dart';
import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_frame_watchdog.dart';
import '../visual_engine/orbit_motion_service.dart';
import '../visual_engine/orbit_palette.dart';
import 'orbit_environment.dart';

final class OrbitFilamentScene extends StatefulWidget {
  const OrbitFilamentScene({
    required this.palette,
    required this.quality,
    this.diagnosticsId = 'today',
    this.atmosphereMode,
    super.key,
  });

  final OrbitPalette palette;
  final ResolvedQuality quality;
  final String diagnosticsId;
  final AtmosphereMode? atmosphereMode;
  static void Function(PointerEvent event)? pointerHandler;

  static Widget unsupportedNotice(BuildContext context) {
    final palette = OrbitEnvironment.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        context.l10n.filamentUnsupported,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  @override
  State<OrbitFilamentScene> createState() => _OrbitFilamentSceneState();
}

final class _OrbitFilamentSceneState extends State<OrbitFilamentScene>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('orbit/filament');
  bool _resumed = true;
  bool _tickerEnabled = true;
  bool _failed = false;
  bool _acquiredMotion = false;
  int? _viewId;
  MethodChannel? _viewChannel;
  Timer? _statsTimer;
  bool _statsRequestInFlight = false;
  final OrbitFrameWatchdog _watchdog = OrbitFrameWatchdog();
  final List<({DateTime at, int frames})> _frameSamples =
      <({DateTime at, int frames})>[];

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OrbitFilamentScene.pointerHandler = _sendParallax;
  }

  AtmosphereMode? _lastAtmosphere;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionSubscription();
    final env = OrbitEnvironment.read(context);
    final currentAtmosphere =
        widget.atmosphereMode ?? env.appearanceSettings.atmosphereMode;
    if (_lastAtmosphere != currentAtmosphere) {
      _lastAtmosphere = currentAtmosphere;
      unawaited(_sendConfiguration());
    }
    if (_viewId == null && _supported) {
      OrbitEnvironment.read(context).quality
          .updateRuntimeDiagnostics(widget.diagnosticsId, <String, Object?>{
            'requestedRenderer': 'filament',
            'actualRenderer': 'static',
            'nativePending': true,
          });
    }
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled != enabled) {
      _tickerEnabled = enabled;
      if (!enabled) _watchdog.pause(DateTime.now());
      unawaited(_sendConfiguration());
    }
  }

  @override
  void didUpdateWidget(covariant OrbitFilamentScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotionSubscription();
    unawaited(_sendConfiguration());
  }

  void _syncMotionSubscription() {
    if (!mounted) return;
    final env = OrbitEnvironment.read(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        env.quality.reduceMotion;
    final gyroActive =
        env.appearanceSettings.motionEnabled &&
        env.appearanceSettings.gyroEnabled &&
        env.appearanceSettings.gyroIntensity != GyroIntensity.off &&
        !reduceMotion;
    if (gyroActive && !_acquiredMotion) {
      _acquiredMotion = true;
      OrbitMotionService.instance.acquire();
      OrbitMotionService.instance.tiltNotifier.addListener(_onTiltMotion);
    } else if (!gyroActive && _acquiredMotion) {
      _acquiredMotion = false;
      OrbitMotionService.instance.tiltNotifier.removeListener(_onTiltMotion);
      OrbitMotionService.instance.release();
    }
  }

  Future<void> _sendConfiguration() async {
    final viewId = _viewId;
    if (!_supported || _failed || viewId == null) return;
    try {
      final env = OrbitEnvironment.read(context);
      final effectiveAtmosphere =
          widget.atmosphereMode ?? env.appearanceSettings.atmosphereMode;
      final state = await _channel
          .invokeMethod<Map<Object?, Object?>>('configure', {
            'id': viewId,
            'profile': widget.palette.profile.name,
            'quality': widget.quality.name,
            'atmosphereMode': effectiveAtmosphere.name,
            'paused': !_resumed || !_tickerEnabled,
          })
          .timeout(const Duration(seconds: 3));
      if (!mounted) return;
      if (state != null) _registerStats(state);
      final error = state?['lastError'];
      if (error != null || state?['initialized'] == false) {
        _fallback(error ?? 'Native engine initialization failed');
      }
    } on MissingPluginException catch (error) {
      _fallback(error);
    } on PlatformException catch (error) {
      _fallback(error.message ?? error.code);
    } on TimeoutException catch (error) {
      _fallback('Native configuration timed out: $error');
    } catch (error) {
      _fallback(error);
    }
  }

  Future<void> _pollStats() async {
    final viewId = _viewId;
    if (!_supported ||
        _failed ||
        _statsRequestInFlight ||
        viewId == null ||
        !mounted) {
      return;
    }
    _statsRequestInFlight = true;
    try {
      final state = await _channel
          .invokeMethod<Map<Object?, Object?>>('stats', <String, Object?>{
            'id': viewId,
          })
          .timeout(const Duration(seconds: 2));
      if (state != null && mounted && viewId == _viewId) {
        _registerStats(state);
      }
    } on MissingPluginException catch (error) {
      _fallback('Native stats channel unavailable: $error');
    } on PlatformException catch (error) {
      _fallback('Native stats failed: ${error.message ?? error.code}');
    } on TimeoutException catch (error) {
      _fallback('Native stats timed out: $error');
    } finally {
      _statsRequestInFlight = false;
    }
  }

  void _registerStats(Map<Object?, Object?> state) {
    final stats = <String, Object?>{
      for (final entry in state.entries) entry.key.toString(): entry.value,
    };
    final frames = (stats['renderedFrames'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();
    _watchdog.record(frames, now);
    _frameSamples.add((at: now, frames: frames));
    _frameSamples.removeWhere(
      (sample) => now.difference(sample.at) > const Duration(seconds: 12),
    );
    int? delta5;
    for (final sample in _frameSamples) {
      if (now.difference(sample.at) >= const Duration(seconds: 5)) {
        delta5 = frames - sample.frames;
        break;
      }
    }
    final initialized = stats['initialized'] == true;
    final sceneReady = stats['sceneReady'] == true;
    final hasSwapChain = stats['hasSwapChain'] == true;
    final error = stats['lastError'];
    final nativePaused = stats['paused'] == true;
    if (nativePaused || !_tickerEnabled || !_resumed) _watchdog.pause(now);
    if (_watchdog.isStalled(
      now,
      resumed: _resumed && !nativePaused,
      tickerEnabled: _tickerEnabled,
    )) {
      _fallback('Native frame watchdog stopped the renderer');
      return;
    }
    final nativeActive =
        initialized &&
        sceneReady &&
        hasSwapChain &&
        frames > 0 &&
        error == null;
    OrbitEnvironment.read(
      context,
    ).quality.updateRuntimeDiagnostics(widget.diagnosticsId, <String, Object?>{
      ...stats,
      'requestedRenderer': 'filament',
      'actualRenderer': nativeActive ? 'filament' : 'static',
      'nativePending': !nativeActive && error == null,
      'framesDelta5Seconds': delta5,
      'frameSampleCount': _frameSamples.length,
      'fallbackReason': error?.toString(),
    });
  }

  Future<void> _handleViewSignal(MethodCall call) async {
    if (call.method != 'onError') return;
    final arguments = call.arguments as Map<Object?, Object?>?;
    _fallback(arguments?['message'] ?? 'Unknown native graphics error');
  }

  void _fallback(Object reason) {
    if (!mounted || _failed) return;
    _statsTimer?.cancel();
    setState(() => _failed = true);
    OrbitEnvironment.read(
      context,
    ).quality.updateRuntimeDiagnostics(widget.diagnosticsId, <String, Object?>{
      'requestedRenderer': 'filament',
      'actualRenderer': 'static',
      'nativePending': false,
      'fallbackReason': reason.toString(),
      'lastError': reason.toString(),
    });
    OrbitEnvironment.read(
      context,
    ).quality.reportGraphicsFallback('Filament', reason);
    final viewId = _viewId;
    if (viewId != null) {
      unawaited(
        _channel
            .invokeMethod<void>('release', {'id': viewId})
            .catchError((_) {}),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) _watchdog.start(DateTime.now());
    unawaited(_sendConfiguration());
  }

  @override
  void dispose() {
    if (_acquiredMotion) {
      OrbitMotionService.instance.tiltNotifier.removeListener(_onTiltMotion);
      OrbitMotionService.instance.release();
      _acquiredMotion = false;
    }
    if (identical(OrbitFilamentScene.pointerHandler, _sendParallax)) {
      OrbitFilamentScene.pointerHandler = null;
    }
    _statsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _viewChannel?.setMethodCallHandler(null);
    final viewId = _viewId;
    if (_supported && viewId != null) {
      unawaited(
        _channel
            .invokeMethod<void>('release', {'id': viewId})
            .catchError((_) {}),
      );
    }
    super.dispose();
  }

  void _onTiltMotion() {
    final viewId = _viewId;
    if (viewId == null || _failed || !_tickerEnabled || !mounted) return;
    final env = OrbitEnvironment.read(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        env.quality.reduceMotion;
    if (reduceMotion ||
        env.appearanceSettings.gyroIntensity == GyroIntensity.off ||
        !env.appearanceSettings.motionEnabled) {
      return;
    }
    final multiplier =
        env.appearanceSettings.gyroIntensity == GyroIntensity.subtle
            ? 0.45
            : 1.0;
    final tilt = OrbitMotionService.instance.tiltNotifier.value;
    unawaited(
      _channel
          .invokeMethod<void>('parallax', {
            'id': viewId,
            'x': (tilt.dx * 1.5 * multiplier).clamp(-1.5, 1.5),
            'y': (tilt.dy * 1.0 * multiplier).clamp(-1.0, 1.0),
          })
          .catchError((_) {}),
    );
  }

  void _sendParallax(PointerEvent event) {
    final viewId = _viewId;
    if (viewId == null || _failed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (event is! PointerDownEvent && now - _lastParallaxMs < 25) return;
    _lastParallaxMs = now;
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.hasSize == true
        ? renderBox!.size
        : MediaQuery.sizeOf(context);
    final localPos = renderBox != null && renderBox.hasSize
        ? renderBox.globalToLocal(event.position)
        : event.localPosition;
    final x = (((localPos.dx / size.width) - 0.5).clamp(-0.5, 0.5) * 2.0);
    final y = (((localPos.dy / size.height) - 0.5).clamp(-0.5, 0.5) * 2.0);
    unawaited(
      _channel
          .invokeMethod<void>('parallax', {'id': viewId, 'x': x, 'y': y})
          .catchError((_) {}),
    );
  }

  int _lastParallaxMs = 0;

  @override
  Widget build(BuildContext context) {
    if (!_supported || _failed || widget.quality == ResolvedQuality.static) {
      return const SizedBox.shrink();
    }
    return SizedBox.expand(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _sendParallax,
        onPointerMove: _sendParallax,
        child: AndroidView(
          key: const Key('filament-native-surface'),
          viewType: 'orbit/filament_scene',
          creationParams: <String, Object?>{
            'profile': widget.palette.profile.name,
            'quality': widget.quality.name,
            'atmosphereMode': (widget.atmosphereMode ??
                    OrbitEnvironment.read(context).appearanceSettings.atmosphereMode)
                .name,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) {
            _viewId = id;
            _watchdog.start(DateTime.now());
            _statsTimer?.cancel();
            _statsTimer = Timer.periodic(
              const Duration(seconds: 1),
              (_) => unawaited(_pollStats()),
            );
            _viewChannel = MethodChannel('orbit/filament/$id')
              ..setMethodCallHandler(_handleViewSignal);
            unawaited(_sendConfiguration());
          },
          hitTestBehavior: PlatformViewHitTestBehavior.translucent,
          // Horizontal gestures drive native parallax; vertical scrolling stays
          // with Flutter so the 3D background never blocks the shell.
          gestureRecognizers: {
            Factory<HorizontalDragGestureRecognizer>(
              HorizontalDragGestureRecognizer.new,
            ),
            Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
          },
        ),
      ),
    );
  }
}
