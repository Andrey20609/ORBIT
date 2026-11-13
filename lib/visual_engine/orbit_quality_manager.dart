import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'appearance_settings.dart';

final class OrbitQualityManager extends ChangeNotifier {
  OrbitQualityManager() {
    _channel.setMethodCallHandler(_handleNativeSignal);
  }

  static const _channel = MethodChannel('orbit/system');
  bool _powerSaveMode = false;
  bool _lowMemory = false;
  bool _reduceMotion = false;
  bool _appResumed = true;
  final List<String> _graphicsDiagnostics = <String>[];
  final Map<String, Map<String, Object?>> _runtimeDiagnostics =
      <String, Map<String, Object?>>{};

  bool get powerSaveMode => _powerSaveMode;
  bool get lowMemory => _lowMemory;
  bool get reduceMotion => _reduceMotion;
  bool get appResumed => _appResumed;
  String? get graphicsFallbackReason =>
      _graphicsDiagnostics.isEmpty ? null : _graphicsDiagnostics.last;
  List<String> get graphicsDiagnostics =>
      List<String>.unmodifiable(_graphicsDiagnostics);

  /// Runtime proof is updated by renderer widgets without notifying the root
  /// app. The diagnostics screen polls it once per second, avoiding a full
  /// scene rebuild on every native frame counter update.
  Map<String, Object?> runtimeDiagnosticsFor(String surface) =>
      Map<String, Object?>.unmodifiable(
        _runtimeDiagnostics[surface] ?? const <String, Object?>{},
      );

  void updateRuntimeDiagnostics(String surface, Map<String, Object?> values) {
    _runtimeDiagnostics[surface] = <String, Object?>{
      ...?_runtimeDiagnostics[surface],
      ...values,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  void clearRuntimeDiagnostics(String surface) {
    _runtimeDiagnostics.remove(surface);
  }

  Map<String, Object?> diagnosticsSnapshot() => <String, Object?>{
    for (final entry in _runtimeDiagnostics.entries)
      entry.key: Map<String, Object?>.unmodifiable(entry.value),
    'appResumed': _appResumed,
    'lowMemory': _lowMemory,
    'powerSaveMode': _powerSaveMode,
    'reduceMotion': _reduceMotion,
    'graphicsDiagnostics': List<String>.from(_graphicsDiagnostics),
  };

  void reportGraphicsFallback(String renderer, Object reason) {
    final entry = '$renderer → Static/Eco: $reason';
    _graphicsDiagnostics.add(entry);
    if (_graphicsDiagnostics.length > 20) _graphicsDiagnostics.removeAt(0);
    debugPrint('[ORBIT graphics] $entry');
    notifyListeners();
  }

  void clearGraphicsDiagnostics() {
    if (_graphicsDiagnostics.isEmpty) return;
    _graphicsDiagnostics.clear();
    notifyListeners();
  }

  ResolvedQuality resolve(AppearanceSettings settings) {
    if (!_appResumed ||
        _lowMemory ||
        _powerSaveMode ||
        _reduceMotion ||
        !settings.motionEnabled ||
        settings.quality == OrbitQuality.eco) {
      return ResolvedQuality.static;
    }
    if (settings.quality == OrbitQuality.ultra) return ResolvedQuality.ultra;
    if (settings.quality == OrbitQuality.balanced) {
      return ResolvedQuality.balanced;
    }
    // Auto is deliberately conservative. Ultra is an explicit opt-in until
    // device capability and sustained stability have actually been measured.
    return ResolvedQuality.balanced;
  }

  int targetFps(AppearanceSettings settings) => switch (resolve(settings)) {
    ResolvedQuality.static => 0,
    ResolvedQuality.balanced => 30,
    ResolvedQuality.ultra => 60,
  };

  Future<void> _handleNativeSignal(MethodCall call) async {
    switch (call.method) {
      case 'powerSaveMode':
        _powerSaveMode = call.arguments == true;
      case 'lowMemory':
        _lowMemory = true;
      case 'memoryRecovered':
        _lowMemory = false;
    }
    notifyListeners();
  }

  void setAppLifecycle({required bool resumed}) {
    if (_appResumed == resumed) return;
    _appResumed = resumed;
    notifyListeners();
  }

  void setReduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
  }

  Future<void> requestNativeStatus() async {
    try {
      await _channel.invokeMethod<void>('refreshSystemStatus');
    } on MissingPluginException {
      // Expected on web and in widget tests.
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
