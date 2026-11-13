import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'appearance_settings.dart';
import 'orbit_atmosphere.dart';

/// Diagnostics information for an individual scene asset layer.
/// Represents the unique, unified composite state of a rendered frame.
final class OrbitSceneKey {
  const OrbitSceneKey({
    required this.profile,
    required this.atmospherePeriod,
    required this.themeBrightness,
    required this.quality,
    required this.orientation,
  });

  final OrbitProfile profile;
  final OrbitTimeOfDay atmospherePeriod;
  final Brightness themeBrightness;
  final ResolvedQuality quality;
  final Orientation orientation;

  String get value =>
      '${profile.name}_${atmospherePeriod.name}_${themeBrightness.name}_${quality.name}_${orientation.name}';

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrbitSceneKey &&
          runtimeType == other.runtimeType &&
          profile == other.profile &&
          atmospherePeriod == other.atmospherePeriod &&
          themeBrightness == other.themeBrightness &&
          quality == other.quality &&
          orientation == other.orientation;

  @override
  int get hashCode => Object.hash(
        profile,
        atmospherePeriod,
        themeBrightness,
        quality,
        orientation,
      );
}

final class LayerResourceInfo {
  LayerResourceInfo({
    required this.layerName,
    required this.assetPath,
    this.loadStatus = 'loading',
    this.decodedWidth = 0,
    this.decodedHeight = 0,
    this.alphaCoverage = 0.0,
    this.nonTransparentPixelRatio = 0.0,
    this.luminanceVariance = 0.0,
    this.lastError,
    this.lastChecked,
  });

  final String layerName;
  final String assetPath;
  String loadStatus; // 'loading', 'ready', 'error'
  int decodedWidth;
  int decodedHeight;
  double alphaCoverage;
  double nonTransparentPixelRatio;
  double luminanceVariance;
  String? lastError;
  DateTime? lastChecked;

  bool get isReady => loadStatus == 'ready';
  bool get hasError => loadStatus == 'error';

  Map<String, Object?> toMap() => {
        'layerName': layerName,
        'assetPath': assetPath,
        'loadStatus': loadStatus,
        'decodedWidth': decodedWidth,
        'decodedHeight': decodedHeight,
        'alphaCoverage': alphaCoverage,
        'nonTransparentPixelRatio': nonTransparentPixelRatio,
        'luminanceVariance': luminanceVariance,
        'lastError': lastError,
        'lastChecked': lastChecked?.toIso8601String(),
      };
}

/// Service that performs rigorous bytecode inspection and runtime diagnostics
/// of all photoreal scene layer assets.
final class OrbitSceneDiagnostics {
  OrbitSceneDiagnostics._();

  static final OrbitSceneDiagnostics instance = OrbitSceneDiagnostics._();

  final Map<String, LayerResourceInfo> _layers = <String, LayerResourceInfo>{};
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);
  bool _initialized = false;
  Completer<void>? _activeScan;

  AtmosphereMode selectedAtmosphereMode = AtmosphereMode.automatic;
  OrbitTimeOfDay activeAtmospherePeriod = OrbitTimeOfDay.day;
  String currentSceneKey = 'one_day_dark_balanced_portrait';
  Map<String, String> currentLayerAssetPaths = const {};
  String activeRenderer = 'Photoreal';
  int atmosphereApplicationCount = 0;
  DateTime? lastAtmosphereUpdateTime;
  final List<String> activeErrors = <String>[];

  Map<String, LayerResourceInfo> get layers => Map.unmodifiable(_layers);

  void recordAtmosphereApplication({
    required OrbitProfile profile,
    required AtmosphereMode mode,
    required OrbitTimeOfDay period,
    required Brightness brightness,
    required ResolvedQuality quality,
    required Orientation orientation,
    required String renderer,
    required Map<String, String> layerAssetPaths,
  }) {
    final key = '${profile.name}_${period.name}_${brightness.name}_${quality.name}_${orientation.name}';
    final bool changed = currentSceneKey != key ||
        selectedAtmosphereMode != mode ||
        activeAtmospherePeriod != period ||
        activeRenderer != renderer;

    selectedAtmosphereMode = mode;
    activeAtmospherePeriod = period;
    currentSceneKey = key;
    currentLayerAssetPaths = Map.unmodifiable(layerAssetPaths);
    activeRenderer = renderer;
    atmosphereApplicationCount++;
    lastAtmosphereUpdateTime = DateTime.now();

    activeErrors.clear();
    for (final entry in layerAssetPaths.entries) {
      final info = _layers[entry.key];
      if (info?.hasError == true) {
        activeErrors.add('${entry.key}: ${info?.lastError ?? "error"}');
      }
    }

    if (changed) {
      changeNotifier.value++;
    }
  }

  static const Map<String, String> mandatoryAssetsOne = {
    'one_sky': 'assets/photoreal/optimized/one_sky.webp',
    'one_sky_dawn': 'assets/photoreal/optimized/one_sky_dawn.webp',
    'one_sky_day': 'assets/photoreal/optimized/one_sky_day.webp',
    'one_sky_sunset': 'assets/photoreal/optimized/one_sky_sunset.webp',
    'one_sky_night': 'assets/photoreal/optimized/one_sky_night.webp',
    'one_far': 'assets/photoreal/optimized/one_far.webp',
    'one_mid': 'assets/photoreal/optimized/one_mid.webp',
    'one_fg': 'assets/photoreal/optimized/one_fg.webp',
  };

  static const Map<String, String> allSceneAssets = {
    'one_sky': 'assets/photoreal/optimized/one_sky.webp',
    'one_sky_dawn': 'assets/photoreal/optimized/one_sky_dawn.webp',
    'one_sky_day': 'assets/photoreal/optimized/one_sky_day.webp',
    'one_sky_sunset': 'assets/photoreal/optimized/one_sky_sunset.webp',
    'one_sky_night': 'assets/photoreal/optimized/one_sky_night.webp',
    'one_far': 'assets/photoreal/optimized/one_far.webp',
    'one_mid': 'assets/photoreal/optimized/one_mid.webp',
    'one_fg': 'assets/photoreal/optimized/one_fg.webp',
    'one_base': 'assets/photoreal/optimized/one.jpg',
    'atelier_base': 'assets/photoreal/optimized/atelier.jpg',
    'atelier_fg': 'assets/photoreal/optimized/atelier_foreground.webp',
    'zen_base': 'assets/photoreal/optimized/zen.jpg',
    'zen_fg': 'assets/photoreal/optimized/zen_foreground.webp',
    'flow_light': 'assets/photoreal/optimized/flow_light.jpg',
    'flow_dark': 'assets/photoreal/optimized/flow_dark.jpg',
  };

  /// Returns true if all mandatory layers for [profile] are verified ready.
  bool isProfileReady(OrbitProfile profile) {
    if (profile == OrbitProfile.one) {
      return mandatoryAssetsOne.keys.every((key) => _layers[key]?.isReady == true);
    } else if (profile == OrbitProfile.atelier) {
      return _layers['atelier_base']?.isReady == true &&
          _layers['atelier_fg']?.isReady == true;
    } else if (profile == OrbitProfile.zen) {
      return _layers['zen_base']?.isReady == true &&
          _layers['zen_fg']?.isReady == true;
    } else {
      return _layers['flow_dark']?.isReady == true ||
          _layers['flow_light']?.isReady == true;
    }
  }

  /// Returns the first error layer name for [profile] if any failed, or null.
  String? firstErrorForProfile(OrbitProfile profile) {
    final keys = switch (profile) {
      OrbitProfile.one => mandatoryAssetsOne.keys,
      OrbitProfile.atelier => ['atelier_base', 'atelier_fg'],
      OrbitProfile.zen => ['zen_base', 'zen_fg'],
      OrbitProfile.flow => ['flow_dark', 'flow_light'],
    };
    for (final k in keys) {
      if (_layers[k]?.hasError == true) return k;
    }
    return null;
  }

  /// Ensures verification has run at least once.
  Future<void> ensureVerified() async {
    if (_initialized) return;
    await verifyAll();
  }

  /// Verifies all assets, decoding dimensions, alpha coverage, and luminance variance.
  Future<void> verifyAll() async {
    if (_activeScan != null) return _activeScan!.future;
    final completer = Completer<void>();
    _activeScan = completer;

    try {
      for (final entry in allSceneAssets.entries) {
        final key = entry.key;
        final path = entry.value;
        final info = _layers.putIfAbsent(
          key,
          () => LayerResourceInfo(layerName: key, assetPath: path),
        );

        try {
          final ByteData data = await rootBundle.load(path);
          final Uint8List bytes = data.buffer.asUint8List();
          final ui.Codec codec = await ui.instantiateImageCodec(bytes);
          final ui.FrameInfo frame = await codec.getNextFrame();
          final ui.Image image = frame.image;

          info.decodedWidth = image.width;
          info.decodedHeight = image.height;

          // Sample pixels for alpha coverage and luminance variance
          final ByteData? byteData = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (byteData != null) {
            final Uint8List rawRgba = byteData.buffer.asUint8List();
            final totalPixels = rawRgba.length ~/ 4;
            // Step sample to keep analysis fast (< 10ms per image)
            final step = math.max(1, totalPixels ~/ 5000);
            int nonZeroAlpha = 0;
            int solidAlpha = 0;
            double sumLuma = 0.0;
            double sumLumaSq = 0.0;
            int samples = 0;

            for (int i = 0; i < rawRgba.length; i += step * 4) {
              final r = rawRgba[i];
              final g = rawRgba[i + 1];
              final b = rawRgba[i + 2];
              final a = rawRgba[i + 3];

              if (a > 0) nonZeroAlpha++;
              if (a > 12) solidAlpha++;

              final luma = 0.299 * r + 0.587 * g + 0.114 * b;
              sumLuma += luma;
              sumLumaSq += luma * luma;
              samples++;
            }

            info.alphaCoverage = samples > 0 ? nonZeroAlpha / samples : 0.0;
            info.nonTransparentPixelRatio = samples > 0 ? solidAlpha / samples : 0.0;
            if (samples > 1) {
              final mean = sumLuma / samples;
              info.luminanceVariance = (sumLumaSq / samples) - (mean * mean);
            }
          }

          info.loadStatus = 'ready';
          info.lastError = null;
          info.lastChecked = DateTime.now();
        } catch (e) {
          info.loadStatus = 'error';
          info.lastError = e.toString();
          info.lastChecked = DateTime.now();
          debugPrint('[ORBIT Scene Diagnostics] Failed layer $key ($path): $e');
        }
      }
      _initialized = true;
      changeNotifier.value++;
    } finally {
      _activeScan = null;
      completer.complete();
    }
  }

  /// Retries loading failed layers.
  Future<void> retry() async {
    _initialized = false;
    await verifyAll();
  }
}

/// Visible overlay shown when a scene layer fails to load.
/// Provides a clear ASSET_ERROR indicator and a Retry button.
class OrbitAssetErrorView extends StatelessWidget {
  const OrbitAssetErrorView({
    super.key,
    required this.layerName,
    this.errorMessage,
    this.onRetry,
  });

  final String layerName;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xE6141824),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF5252), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, color: Color(0xFFFF5252), size: 36),
            const SizedBox(height: 8),
            const Text(
              'ASSET_ERROR',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Не удалось загрузить слой: $layerName',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry ?? () => OrbitSceneDiagnostics.instance.retry(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Повторить попытку', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E384D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
