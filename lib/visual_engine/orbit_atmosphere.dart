import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'appearance_settings.dart';
import 'orbit_palette.dart';

/// The astronomical time-of-day phase in the diurnal cycle.
enum OrbitTimeOfDay {
  dawn,
  day,
  sunset,
  night,
}

/// Atmospheric lighting conditions calculated dynamically from local solar time.
@immutable
final class OrbitAtmosphere {
  const OrbitAtmosphere({
    required this.timeOfDay,
    required this.sunAlignment,
    required this.sunColor,
    required this.sunRadius,
    required this.ambientSkyTint,
    required this.specularRimAngle,
    required this.starlightIntensity,
    this.colorMatrix = dayColorMatrix,
    this.skyColorMatrix = daySkyMatrix,
    this.skyGradientColors = daySkyGradient,
    this.skyGradientWeight = 0.35,
    this.celestialHaloRadius = 0.85,
    this.celestialHaloAlpha = 0.35,
  });

  static const List<double> dayColorMatrix = [
    1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ];

  static const List<double> daySkyMatrix = [
    1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ];

  static const List<Color> daySkyGradient = [
    Color(0xFF1565C0),
    Color(0xFF42A5F5),
    Color(0xFF90CAF9),
    Color(0xFFE3F2FD),
  ];

  static const List<double> dawnColorMatrix = [
    1.12, 0.06, 0.00, 0.0, 14.0,
    0.02, 0.96, 0.02, 0.0, 5.0,
    -0.04, 0.02, 0.86, 0.0, -8.0,
    0.00, 0.00, 0.00, 1.0, 0.0,
  ];

  static const List<double> dawnSkyMatrix = [
    1.18, 0.05, 0.00, 0.0, 20.0,
    0.02, 0.92, 0.02, 0.0, 8.0,
    -0.08, 0.00, 0.80, 0.0, -10.0,
    0.00, 0.00, 0.00, 1.0, 0.0,
  ];

  static const List<Color> dawnSkyGradient = [
    Color(0xFF263238),
    Color(0xFF455A64),
    Color(0xFFD38B78),
    Color(0xFFFFB59A),
    Color(0xFFFFE0B2),
  ];

  static const List<double> sunsetColorMatrix = [
    1.28, 0.10, -0.06, 0.0, 24.0,
    -0.02, 0.84, -0.05, 0.0, -12.0,
    -0.12, -0.02, 0.65, 0.0, -28.0,
    0.00, 0.00, 0.00, 1.0, 0.0,
  ];

  static const List<double> sunsetSkyMatrix = [
    1.35, 0.08, -0.05, 0.0, 32.0,
    0.00, 0.78, -0.04, 0.0, -16.0,
    -0.18, -0.05, 0.58, 0.0, -35.0,
    0.00, 0.00, 0.00, 1.0, 0.0,
  ];

  static const List<Color> sunsetSkyGradient = [
    Color(0xFF1A0A2A),
    Color(0xFF4A154B),
    Color(0xFF9C2742),
    Color(0xFFE65100),
    Color(0xFFFFB74D),
  ];

  static const List<double> nightColorMatrix = [
    0.18, 0.20, 0.08, 0.0, -42.0,
    0.14, 0.24, 0.12, 0.0, -38.0,
    0.22, 0.28, 0.50, 0.0, -14.0,
    0.00, 0.00, 0.00, 1.0, 0.0,
  ];

  static const List<double> nightSkyMatrix = [
    0.10, 0.12, 0.06, 0.0, -55.0,
    0.08, 0.14, 0.08, 0.0, -50.0,
    0.18, 0.22, 0.44, 0.0, -20.0,
    0.00, 0.00, 0.00, 1.0, 0.0,
  ];

  static const List<Color> nightSkyGradient = [
    Color(0xFF030611),
    Color(0xFF091224),
    Color(0xFF0E1B38),
    Color(0xFF16274D),
  ];

  static List<double> _lerpMatrix(List<double> a, List<double> b, double t) {
    return List<double>.generate(20, (i) {
      final vA = i < a.length ? a[i] : 0.0;
      final vB = i < b.length ? b[i] : 0.0;
      return vA + (vB - vA) * t;
    });
  }

  static List<Color> _lerpColors(List<Color> a, List<Color> b, double t) {
    final len = math.max(a.length, b.length);
    return List<Color>.generate(len, (i) {
      final cA = a[math.min(i, a.length - 1)];
      final cB = b[math.min(i, b.length - 1)];
      return Color.lerp(cA, cB, t)!;
    });
  }

  /// Calculates atmospheric lighting from [AppearanceSettings], respecting
  /// manual mode overrides (dawn, day, sunset, night) or local device time.
  factory OrbitAtmosphere.fromSettings(
    AppearanceSettings settings,
    OrbitPalette palette,
  ) {
    switch (settings.atmosphereMode) {
      case AtmosphereMode.dawn:
        return OrbitAtmosphere.fromDateTime(
          DateTime(2026, 1, 1, 7, 0),
          palette,
        );
      case AtmosphereMode.day:
        return OrbitAtmosphere.fromDateTime(
          DateTime(2026, 1, 1, 12, 0),
          palette,
        );
      case AtmosphereMode.sunset:
        return OrbitAtmosphere.fromDateTime(
          DateTime(2026, 1, 1, 18, 45),
          palette,
        );
      case AtmosphereMode.night:
        return OrbitAtmosphere.fromDateTime(
          DateTime(2026, 1, 1, 23, 30),
          palette,
        );
      case AtmosphereMode.automatic:
        return OrbitAtmosphere.fromDateTime(clock.now(), palette);
    }
  }

  /// Calculates atmospheric lighting for a given [time] (or clock.now()).
  factory OrbitAtmosphere.fromDateTime(DateTime time, OrbitPalette palette) {
    final hour = time.hour + time.minute / 60.0 + time.second / 3600.0;

    final OrbitTimeOfDay timeOfDay;
    final Alignment sunAlignment;
    final Color sunColor;
    final double sunRadius;
    final List<Color> ambientSkyTint;
    final double specularRimAngle;
    final double starlightIntensity;
    final List<double> colorMatrix;
    final List<double> skyColorMatrix;
    final List<Color> skyGradientColors;
    final double skyGradientWeight;
    final double celestialHaloRadius;
    final double celestialHaloAlpha;

    if (hour >= 5.0 && hour < 8.5) {
      // Dawn (05:00 — 08:30)
      final progress = (hour - 5.0) / 3.5;
      timeOfDay = OrbitTimeOfDay.dawn;
      sunAlignment = Alignment(
        0.75 - progress * 0.35,
        0.28 - progress * 0.70,
      );
      sunColor = Color.lerp(
        const Color(0xFFFF9E79),
        palette.sun,
        progress,
      )!;
      sunRadius = 0.95;
      ambientSkyTint = [
        const Color(0x33FFB088),
        const Color(0x1AFF8066),
        Colors.transparent,
      ];
      specularRimAngle = math.pi * 0.25 - progress * 0.15;
      starlightIntensity = math.max(0.0, 1.0 - progress * 2.0);

      if (progress < 0.5) {
        final t = progress * 2.0;
        colorMatrix = _lerpMatrix(nightColorMatrix, dawnColorMatrix, t);
        skyColorMatrix = _lerpMatrix(nightSkyMatrix, dawnSkyMatrix, t);
        skyGradientColors = _lerpColors(nightSkyGradient, dawnSkyGradient, t);
      } else {
        final t = (progress - 0.5) * 2.0;
        colorMatrix = _lerpMatrix(dawnColorMatrix, dayColorMatrix, t);
        skyColorMatrix = _lerpMatrix(dawnSkyMatrix, daySkyMatrix, t);
        skyGradientColors = _lerpColors(dawnSkyGradient, daySkyGradient, t);
      }
      skyGradientWeight = 0.45;
      celestialHaloRadius = 0.95;
      celestialHaloAlpha = 0.55;
    } else if (hour >= 8.5 && hour < 17.0) {
      // Day (08:30 — 17:00)
      final progress = (hour - 8.5) / 8.5;
      timeOfDay = OrbitTimeOfDay.day;
      final arcAngle = math.pi * 0.15 + progress * math.pi * 0.7;
      sunAlignment = Alignment(
        math.cos(arcAngle) * 0.75,
        -0.55 - math.sin(arcAngle) * 0.2,
      );
      sunColor = palette.sun;
      sunRadius = 0.85;
      ambientSkyTint = const [Colors.transparent, Colors.transparent];
      specularRimAngle = arcAngle;
      starlightIntensity = 0.0;
      colorMatrix = dayColorMatrix;
      skyColorMatrix = daySkyMatrix;
      skyGradientColors = daySkyGradient;
      skyGradientWeight = 0.25;
      celestialHaloRadius = 0.85;
      celestialHaloAlpha = 0.35;
    } else if (hour >= 17.0 && hour < 20.5) {
      // Sunset / Golden Hour (17:00 — 20:30)
      final progress = (hour - 17.0) / 3.5;
      timeOfDay = OrbitTimeOfDay.sunset;
      sunAlignment = Alignment(
        -0.35 - progress * 0.45,
        -0.30 + progress * 0.55,
      );
      sunColor = Color.lerp(
        palette.sun,
        const Color(0xFFFF5224),
        progress,
      )!;
      sunRadius = 1.10;
      ambientSkyTint = [
        const Color(0x40FF6B4A),
        const Color(0x22FFAA55),
        Colors.transparent,
      ];
      specularRimAngle = math.pi * 0.85 + progress * 0.25;
      starlightIntensity = math.max(0.0, (progress - 0.6) * 2.5);

      if (progress < 0.6) {
        final t = progress / 0.6;
        colorMatrix = _lerpMatrix(dayColorMatrix, sunsetColorMatrix, t);
        skyColorMatrix = _lerpMatrix(daySkyMatrix, sunsetSkyMatrix, t);
        skyGradientColors = _lerpColors(daySkyGradient, sunsetSkyGradient, t);
      } else {
        final t = (progress - 0.6) / 0.4;
        colorMatrix = _lerpMatrix(sunsetColorMatrix, nightColorMatrix, t);
        skyColorMatrix = _lerpMatrix(sunsetSkyMatrix, nightSkyMatrix, t);
        skyGradientColors = _lerpColors(sunsetSkyGradient, nightSkyGradient, t);
      }
      skyGradientWeight = 0.60;
      celestialHaloRadius = 1.10;
      celestialHaloAlpha = 0.70;
    } else {
      // Deep Night (20:30 — 05:00)
      timeOfDay = OrbitTimeOfDay.night;
      sunAlignment = const Alignment(0.62, -0.68);
      sunColor = const Color(0xFFCBE3FF);
      sunRadius = 0.65;
      ambientSkyTint = [
        const Color(0x280D1E3A),
        const Color(0x15091428),
        Colors.transparent,
      ];
      specularRimAngle = math.pi * 0.25;
      starlightIntensity = 1.0;
      colorMatrix = nightColorMatrix;
      skyColorMatrix = nightSkyMatrix;
      skyGradientColors = nightSkyGradient;
      skyGradientWeight = 0.75;
      celestialHaloRadius = 0.65;
      celestialHaloAlpha = 0.55;
    }

    return OrbitAtmosphere(
      timeOfDay: timeOfDay,
      sunAlignment: sunAlignment,
      sunColor: sunColor,
      sunRadius: sunRadius,
      ambientSkyTint: ambientSkyTint,
      specularRimAngle: specularRimAngle,
      starlightIntensity: starlightIntensity,
      colorMatrix: colorMatrix,
      skyColorMatrix: skyColorMatrix,
      skyGradientColors: skyGradientColors,
      skyGradientWeight: skyGradientWeight,
      celestialHaloRadius: celestialHaloRadius,
      celestialHaloAlpha: celestialHaloAlpha,
    );
  }

  /// Linearly interpolates between two [OrbitAtmosphere] conditions smoothly.
  static OrbitAtmosphere lerp(OrbitAtmosphere a, OrbitAtmosphere b, double t) {
    if (t <= 0.0) return a;
    if (t >= 1.0) return b;
    return OrbitAtmosphere(
      timeOfDay: t < 0.5 ? a.timeOfDay : b.timeOfDay,
      sunAlignment: Alignment(
        a.sunAlignment.x + (b.sunAlignment.x - a.sunAlignment.x) * t,
        a.sunAlignment.y + (b.sunAlignment.y - a.sunAlignment.y) * t,
      ),
      sunColor: Color.lerp(a.sunColor, b.sunColor, t)!,
      sunRadius: a.sunRadius + (b.sunRadius - a.sunRadius) * t,
      ambientSkyTint: [
        for (int i = 0;
            i < math.max(a.ambientSkyTint.length, b.ambientSkyTint.length);
            i++)
          Color.lerp(
            a.ambientSkyTint[math.min(i, a.ambientSkyTint.length - 1)],
            b.ambientSkyTint[math.min(i, b.ambientSkyTint.length - 1)],
            t,
          )!,
      ],
      specularRimAngle:
          a.specularRimAngle + (b.specularRimAngle - a.specularRimAngle) * t,
      starlightIntensity: a.starlightIntensity +
          (b.starlightIntensity - a.starlightIntensity) * t,
      colorMatrix: _lerpMatrix(a.colorMatrix, b.colorMatrix, t),
      skyColorMatrix: _lerpMatrix(a.skyColorMatrix, b.skyColorMatrix, t),
      skyGradientColors: _lerpColors(a.skyGradientColors, b.skyGradientColors, t),
      skyGradientWeight: a.skyGradientWeight +
          (b.skyGradientWeight - a.skyGradientWeight) * t,
      celestialHaloRadius: a.celestialHaloRadius +
          (b.celestialHaloRadius - a.celestialHaloRadius) * t,
      celestialHaloAlpha: a.celestialHaloAlpha +
          (b.celestialHaloAlpha - a.celestialHaloAlpha) * t,
    );
  }

  final OrbitTimeOfDay timeOfDay;
  final Alignment sunAlignment;
  final Color sunColor;
  final double sunRadius;
  final List<Color> ambientSkyTint;
  final double specularRimAngle;
  final double starlightIntensity;
  final List<double> colorMatrix;
  final List<double> skyColorMatrix;
  final List<Color> skyGradientColors;
  final double skyGradientWeight;
  final double celestialHaloRadius;
  final double celestialHaloAlpha;

  /// Path to the dedicated photographic sky asset for this diurnal period.
  String get skyAssetPath => switch (timeOfDay) {
        OrbitTimeOfDay.dawn => 'assets/photoreal/optimized/one_sky_dawn.webp',
        OrbitTimeOfDay.day => 'assets/photoreal/optimized/one_sky_day.webp',
        OrbitTimeOfDay.sunset => 'assets/photoreal/optimized/one_sky_sunset.webp',
        OrbitTimeOfDay.night => 'assets/photoreal/optimized/one_sky_night.webp',
      };

  bool get isNight => timeOfDay == OrbitTimeOfDay.night;
  bool get isDawn => timeOfDay == OrbitTimeOfDay.dawn;
  bool get isSunset => timeOfDay == OrbitTimeOfDay.sunset;
  bool get isDay => timeOfDay == OrbitTimeOfDay.day;
}
