import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'appearance_settings.dart';

/// Lifecycle and operational state of the physical motion / gyro sensor pipeline.
enum MotionServiceState {
  disabledByUser,
  disabledByReduceMotion,
  disabledByQuality,
  notSubscribed,
  nativeListening,
  receivingData,
  noSensor,
  error,
}

/// Singleton service that listens to physical device orientation / gyro sensors
/// via the 'orbit/motion' EventChannel and delivers smoothed 2D tilt offsets [-1.0 .. 1.0].
///
/// Uses an Exponential Time-Decay filter with real-time continuous decay,
/// micro-jitter deadband threshold, and inactivity-based neutral return.
///
/// Theoretical settling characteristics for [neutralReturnTauSeconds] = 90 ms:
/// - at 250 ms: remaining offset ~6.2%
/// - at 315 ms: remaining offset ~3.0%
/// - at 414 ms: remaining offset < 1.0% (fully settled)
/// - settling window: 250–450 ms
final class OrbitMotionService {
  OrbitMotionService._();

  static final OrbitMotionService instance = OrbitMotionService._();

  static const _channel = EventChannel('orbit/motion');
  static const _systemChannel = MethodChannel('orbit/system');

  final ValueNotifier<Offset> tiltNotifier = ValueNotifier<Offset>(Offset.zero);

  StreamSubscription<dynamic>? _subscription;
  int _subscriberCount = 0;
  bool _appResumed = true;
  bool _isListening = false;
  Timer? _retryTimer;
  Timer? _neutralReturnTimer;
  int _retryAttempts = 0;

  int _eventCount = 0;
  DateTime? _lastEventTime;
  DateTime? _lastSignificantMotionTime;
  Offset _lastRawOffset = Offset.zero;
  MotionServiceState _state = MotionServiceState.notSubscribed;

  Offset _current = Offset.zero;
  Offset _target = Offset.zero;
  bool _hasFirstReading = false;
  int _lastTickMs = 0;

  /// Deadband threshold: changes smaller than this are filtered as sensor micro-jitter (< 1 dp drift).
  static const double deadbandThreshold = 0.003;

  /// Inactivity window: if no significant motion occurs for this duration while near center,
  /// neutral return is automatically engaged.
  static const int inactivityThresholdMs = 350;

  /// Maximum offset magnitude considered "near center" for automatic resting neutral return.
  static const double restingCenterRadius = 0.15;

  /// Time constant tau for active motion tracking (80 ms).
  static const double trackingTauSeconds = 0.080;

  /// Time constant tau for smooth neutral return (90 ms -> < 1% settling in ~414 ms, strictly within 250–450 ms).
  static const double neutralReturnTauSeconds = 0.090;

  int get subscribersCount => _subscriberCount;
  bool get isListening => _isListening;
  bool get isActive => _isListening;
  int get eventCount => _eventCount;
  DateTime? get lastEventTime => _lastEventTime;
  DateTime? get lastSignificantMotionTime => _lastSignificantMotionTime;
  Offset get lastRawOffset => _lastRawOffset;
  Offset get currentOffset => _current;
  Offset get targetOffset => _target;
  MotionServiceState get currentState => _state;

  /// Acquires a subscription reference to the motion stream.
  void acquire() {
    _subscriberCount++;
    _checkStreamState();
  }

  /// Releases a subscription reference. When count drops to 0, stream stops and smoothly returns to neutral.
  void release() {
    if (_subscriberCount > 0) {
      _subscriberCount--;
    }
    _checkStreamState();
  }

  /// Synchronizes app lifecycle state (e.g. from AppLifecycleListener or OrbitQualityManager).
  void setAppLifecycle({required bool resumed}) {
    if (_appResumed == resumed) return;
    _appResumed = resumed;
    _checkStreamState();
  }

  /// Backward-compatible start call: acquires a subscriber.
  void start() => acquire();

  /// Backward-compatible stop call: releases a subscriber.
  void stop() => release();

  void _checkStreamState() {
    final shouldListen = _subscriberCount > 0 && _appResumed;
    if (shouldListen && !_isListening) {
      _startStream();
    } else if (!shouldListen && _isListening) {
      _stopStream();
    }
  }

  void _startStream() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_isListening) return;
    _isListening = true;
    _hasFirstReading = false;
    _state = MotionServiceState.nativeListening;
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _state = MotionServiceState.noSensor;
      return;
    }
    try {
      _subscription = _channel
          .receiveBroadcastStream()
          .handleError((Object error) {
            _handleStreamError(error);
          })
          .listen(
            _onData,
            onError: (Object error) {
              _handleStreamError(error);
            },
            onDone: () {
              _isListening = false;
              _subscription = null;
              _state = _subscriberCount > 0
                  ? MotionServiceState.error
                  : MotionServiceState.notSubscribed;
            },
            cancelOnError: false,
          );
      _retryAttempts = 0;
    } on PlatformException catch (e) {
      if (e.code == 'NO_SENSOR') {
        _state = MotionServiceState.noSensor;
      } else {
        _state = MotionServiceState.error;
      }
    } on MissingPluginException {
      // Desktop / host environment fallback
      _isListening = true;
      _state = MotionServiceState.noSensor;
    } catch (e) {
      debugPrint('[ORBIT Motion] Channel not available on this platform: $e');
      _state = MotionServiceState.error;
      _scheduleRetry();
    }
  }

  void _handleStreamError(Object error) {
    debugPrint('[ORBIT Motion] Sensor stream error: $error');
    if (error is PlatformException && error.code == 'NO_SENSOR') {
      _state = MotionServiceState.noSensor;
      _subscription?.cancel();
      _subscription = null;
      _isListening = false;
      return;
    }
    _state = MotionServiceState.error;
    if (error is! MissingPluginException) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    try {
      _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    _isListening = false;
    if (_subscriberCount > 0 && _appResumed && _retryAttempts < 5) {
      _retryAttempts++;
      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(milliseconds: 600 * _retryAttempts), () {
        if (_subscriberCount > 0 && _appResumed) {
          _startStream();
        }
      });
    }
  }

  void _stopStream() {
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    _isListening = false;
    _state = MotionServiceState.notSubscribed;
    // Smoothly return to neutral
    setTarget(Offset.zero);
  }

  void _onData(dynamic data) {
    double? rawX;
    double? rawY;
    if (data is List && data.length >= 2) {
      rawX = (data[0] as num).toDouble();
      rawY = (data[1] as num).toDouble();
    } else if (data is Map) {
      rawX = ((data['dx'] ?? data['x']) as num?)?.toDouble();
      rawY = ((data['dy'] ?? data['y']) as num?)?.toDouble();
    }

    if (rawX != null && rawY != null) {
      _eventCount++;
      final now = DateTime.now();
      _lastEventTime = now;
      _state = MotionServiceState.receivingData;

      final x = rawX.clamp(-1.0, 1.0);
      final y = rawY.clamp(-1.0, 1.0);
      final raw = Offset(x, y);

      // Deadband check: ignore tremor if change is below threshold
      final deltaX = (raw.dx - _lastRawOffset.dx).abs();
      final deltaY = (raw.dy - _lastRawOffset.dy).abs();
      if (_hasFirstReading && deltaX < deadbandThreshold && deltaY < deadbandThreshold) {
        // Micro-jitter: check for inactivity-based neutral return
        _checkInactivityAndNeutralReturn(now);
        return;
      }

      _lastRawOffset = raw;
      _lastSignificantMotionTime = now;
      setTarget(raw);
    }
  }

  /// Exposed for testing native event dispatch through [_onData].
  @visibleForTesting
  void handleSensorDataForTesting(dynamic data) => _onData(data);

  @visibleForTesting
  void resetForTesting() {
    _lastRawOffset = Offset.zero;
    _current = Offset.zero;
    _target = Offset.zero;
    _hasFirstReading = false;
    _lastSignificantMotionTime = null;
    tiltNotifier.value = Offset.zero;
  }

  @visibleForTesting
  set lastSignificantMotionTimeForTesting(DateTime? time) =>
      _lastSignificantMotionTime = time;

  @visibleForTesting
  Offset get targetForTesting => _target;

  void _checkInactivityAndNeutralReturn(DateTime now) {
    if (_lastSignificantMotionTime == null) return;
    final elapsedMs = now.difference(_lastSignificantMotionTime!).inMilliseconds;
    if (elapsedMs >= inactivityThresholdMs && _current.distance <= restingCenterRadius) {
      // Inactivity near resting position: initiate neutral return
      if (_target != Offset.zero) {
        _target = Offset.zero;
        _startNeutralReturnTimer();
      }
    }
  }

  /// Sets the raw target offset and advances smoothing towards it.
  void setTarget(Offset target, [double? dtSeconds]) {
    _target = target;
    if (!_hasFirstReading) {
      // First event: snap directly to prevent sudden jump from neutral
      _current = target;
      _hasFirstReading = true;
      tiltNotifier.value = _current;
      _lastTickMs = DateTime.now().millisecondsSinceEpoch;
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final dt = dtSeconds ?? math.min(0.050, math.max(0.016, (now - _lastTickMs) / 1000.0));
    _lastTickMs = now;
    _applyStep(dt);

    if (_target == Offset.zero && _current != Offset.zero) {
      _startNeutralReturnTimer();
    } else {
      _stopNeutralReturnTimer();
    }
  }

  void _startNeutralReturnTimer() {
    if (_neutralReturnTimer != null) return;
    _neutralReturnTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final dt = math.min(0.050, math.max(0.016, (now - _lastTickMs) / 1000.0));
      _lastTickMs = now;
      _applyStep(dt);
      if (_current == Offset.zero) {
        _stopNeutralReturnTimer();
      }
    });
  }

  void _stopNeutralReturnTimer() {
    _neutralReturnTimer?.cancel();
    _neutralReturnTimer = null;
  }

  /// Advances the exponential decay by [dtSeconds].
  void _applyStep(double dtSeconds) {
    final tau = _target == Offset.zero
        ? neutralReturnTauSeconds
        : trackingTauSeconds;
    final factor = (1.0 - math.exp(-dtSeconds / tau)).clamp(0.0, 1.0);

    final nextX = _current.dx + (_target.dx - _current.dx) * factor;
    final nextY = _current.dy + (_target.dy - _current.dy) * factor;

    final dist = (_target - Offset(nextX, nextY)).distance;
    if (dist < 0.0005) {
      _current = _target;
      tiltNotifier.value = _current;
      if (_target == Offset.zero) {
        _stopNeutralReturnTimer();
      }
    } else {
      _current = Offset(nextX, nextY);
      tiltNotifier.value = _current;
    }
  }

  /// Calculates expected layer offsets (in dp) for a given tilt and gyro intensity.
  ///
  /// Reference at full normalized tilt (1.0, corresponding to 8–12° device tilt):
  /// - Sky: 1.5 dp (Target: 1–2 dp)
  /// - Far: 5.0 dp (Target: 4–6 dp)
  /// - Mid: 12.0 dp (Target: 10–14 dp)
  /// - Foreground: 25.0 dp (Target: 22–28 dp)
  Map<String, double> calculatePlaneOffsets({
    Offset? tilt,
    GyroIntensity intensity = GyroIntensity.enhanced,
  }) {
    final t = tilt ?? tiltNotifier.value;
    final mag = t.distance.clamp(0.0, 1.0);
    final multiplier = switch (intensity) {
      GyroIntensity.off => 0.0,
      GyroIntensity.subtle => 0.50,
      GyroIntensity.enhanced => 1.0,
    };
    return {
      'sky': mag * 1.5 * multiplier,
      'far': mag * 5.0 * multiplier,
      'mid': mag * 12.0 * multiplier,
      'foreground': mag * 25.0 * multiplier,
    };
  }

  /// Fetches sensor diagnostic information from the native Android engine.
  Future<Map<String, dynamic>> fetchDiagnostics() async {
    try {
      final result = await _systemChannel
          .invokeMapMethod<String, dynamic>('getSensorDiagnostics');
      return result ?? const {};
    } catch (_) {
      return const {};
    }
  }

  /// Manually injects an instant offset (useful for tests or pointer drags).
  void setOffsetInstant(Offset offset) {
    _current = offset;
    _target = offset;
    _hasFirstReading = true;
    _stopNeutralReturnTimer();
    tiltNotifier.value = offset;
  }

  /// Deterministically steps the simulation by [dtSeconds] for unit testing.
  @visibleForTesting
  void stepSimulation(double dtSeconds) {
    _applyStep(dtSeconds);
  }

  @visibleForTesting
  void reset() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _stopNeutralReturnTimer();
    _subscription?.cancel();
    _subscription = null;
    _subscriberCount = 0;
    _appResumed = true;
    _isListening = false;
    _retryAttempts = 0;
    _hasFirstReading = false;
    _eventCount = 0;
    _lastEventTime = null;
    _lastSignificantMotionTime = null;
    _lastRawOffset = Offset.zero;
    _state = MotionServiceState.notSubscribed;
    _current = Offset.zero;
    _target = Offset.zero;
    tiltNotifier.value = Offset.zero;
  }
}
