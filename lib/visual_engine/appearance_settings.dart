import 'package:flutter/material.dart';

enum OrbitProfile { one, atelier, flow, zen }

enum OrbitQuality { auto, eco, balanced, ultra }

enum OrbitDensity { compact, comfortable }

enum TodayRenderer { procedural, rive, filament }

enum ResolvedQuality { static, balanced, ultra }

enum AtmosphereMode { automatic, dawn, day, sunset, night }

enum GyroIntensity { off, subtle, enhanced }

@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.profile = OrbitProfile.one,
    this.quality = OrbitQuality.auto,
    this.themeMode = ThemeMode.system,
    this.accentColor = const Color(0xFF9B8CFF),
    this.languageCode = 'ru',
    this.density = OrbitDensity.comfortable,
    this.motionEnabled = true,
    this.renderer = TodayRenderer.procedural,
    this.textScale = 1,
    this.atmosphereMode = AtmosphereMode.automatic,
    this.gyroIntensity = GyroIntensity.enhanced,
    this.gyroEnabled = true,
  });

  final OrbitProfile profile;
  final OrbitQuality quality;
  final ThemeMode themeMode;
  final Color accentColor;
  final String languageCode;
  final OrbitDensity density;
  final bool motionEnabled;
  final TodayRenderer renderer;
  final double textScale;
  final AtmosphereMode atmosphereMode;
  final GyroIntensity gyroIntensity;
  final bool gyroEnabled;

  static const schemaVersion = 2;
  static const supportedTextScales = <double>[1, 1.15, 1.3];

  AppearanceSettings copyWith({
    OrbitProfile? profile,
    OrbitQuality? quality,
    ThemeMode? themeMode,
    Color? accentColor,
    String? languageCode,
    OrbitDensity? density,
    bool? motionEnabled,
    TodayRenderer? renderer,
    double? textScale,
    AtmosphereMode? atmosphereMode,
    GyroIntensity? gyroIntensity,
    bool? gyroEnabled,
  }) {
    final effectiveGyro = gyroIntensity ??
        (gyroEnabled != null
            ? (gyroEnabled ? GyroIntensity.enhanced : GyroIntensity.off)
            : this.gyroIntensity);
    return AppearanceSettings(
      profile: profile ?? this.profile,
      quality: quality ?? this.quality,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      languageCode: languageCode ?? this.languageCode,
      density: density ?? this.density,
      motionEnabled: motionEnabled ?? this.motionEnabled,
      renderer: renderer ?? this.renderer,
      textScale: textScale ?? this.textScale,
      atmosphereMode: atmosphereMode ?? this.atmosphereMode,
      gyroIntensity: effectiveGyro,
      gyroEnabled: effectiveGyro != GyroIntensity.off,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': schemaVersion,
    'profile': profile.name,
    'quality': quality.name,
    'themeMode': themeMode.name,
    'accentColor': accentColor.toARGB32(),
    'languageCode': languageCode,
    'density': density.name,
    'motionEnabled': motionEnabled,
    'renderer': renderer.name,
    'textScale': textScale,
    'atmosphereMode': atmosphereMode.name,
    'gyroIntensity': gyroIntensity.name,
    'gyroEnabled': gyroIntensity != GyroIntensity.off,
  };

  static void validateJson(Map<String, Object?> json) {
    if (json.isEmpty) return;
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported appearance schemaVersion');
    }
    final enums = <String, List<String>>{
      'profile': OrbitProfile.values.map((value) => value.name).toList(),
      'quality': OrbitQuality.values.map((value) => value.name).toList(),
      'themeMode': ThemeMode.values.map((value) => value.name).toList(),
      'density': OrbitDensity.values.map((value) => value.name).toList(),
      'renderer': TodayRenderer.values.map((value) => value.name).toList(),
      'atmosphereMode':
          AtmosphereMode.values.map((value) => value.name).toList(),
      'gyroIntensity':
          GyroIntensity.values.map((value) => value.name).toList(),
    };
    for (final entry in enums.entries) {
      final value = json[entry.key];
      if (value != null && !entry.value.contains(value)) {
        throw FormatException('${entry.key} has an unsupported value');
      }
    }
    if (json['accentColor'] != null && json['accentColor'] is! int) {
      throw const FormatException('accentColor must be an integer');
    }
    final language = json['languageCode'];
    if (language != null &&
        !const <String>['ru', 'en', 'de', 'fr', 'es'].contains(language)) {
      throw const FormatException('Unsupported languageCode');
    }
    if (json['motionEnabled'] != null && json['motionEnabled'] is! bool) {
      throw const FormatException('motionEnabled must be a bool');
    }
    if (json['gyroEnabled'] != null && json['gyroEnabled'] is! bool) {
      throw const FormatException('gyroEnabled must be a bool');
    }
    if (json['textScale'] != null && json['textScale'] is! num) {
      throw const FormatException('textScale must be numeric');
    }
  }

  static AppearanceSettings fromJson(Map<String, Object?> json) {
    T enumValue<T extends Enum>(List<T> values, Object? name, T fallback) {
      return values.firstWhere(
        (T value) => value.name == name,
        orElse: () => fallback,
      );
    }

    final rawAccent = json['accentColor'];
    final rawLanguage = json['languageCode'];
    final rawTextScale = json['textScale'];
    final languageCode =
        rawLanguage is String &&
            const <String>['ru', 'en', 'de', 'fr', 'es'].contains(rawLanguage)
        ? rawLanguage
        : 'ru';
    final textScale = rawTextScale is num
        ? supportedTextScales.reduce(
            (nearest, candidate) =>
                (candidate - rawTextScale).abs() <
                    (nearest - rawTextScale).abs()
                ? candidate
                : nearest,
          )
        : 1.0;
    return AppearanceSettings(
      profile: enumValue(
        OrbitProfile.values,
        json['profile'],
        OrbitProfile.one,
      ),
      quality: enumValue(
        OrbitQuality.values,
        json['quality'],
        OrbitQuality.auto,
      ),
      themeMode: enumValue(
        ThemeMode.values,
        json['themeMode'],
        ThemeMode.system,
      ),
      accentColor: rawAccent is int
          ? Color(rawAccent)
          : const Color(0xFF9B8CFF),
      languageCode: languageCode,
      density: enumValue(
        OrbitDensity.values,
        json['density'],
        OrbitDensity.comfortable,
      ),
      motionEnabled: json['motionEnabled'] is bool
          ? json['motionEnabled']! as bool
          : true,
      renderer: enumValue(
        TodayRenderer.values,
        json['renderer'],
        TodayRenderer.procedural,
      ),
      textScale: textScale,
      atmosphereMode: enumValue(
        AtmosphereMode.values,
        json['atmosphereMode'],
        AtmosphereMode.automatic,
      ),
      gyroIntensity: json['gyroIntensity'] != null
          ? enumValue(
              GyroIntensity.values,
              json['gyroIntensity'],
              GyroIntensity.enhanced,
            )
          : (json['gyroEnabled'] == false
              ? GyroIntensity.off
              : GyroIntensity.enhanced),
      gyroEnabled: json['gyroIntensity'] != null
          ? json['gyroIntensity'] != GyroIntensity.off.name
          : (json['gyroEnabled'] is bool ? json['gyroEnabled']! as bool : true),
    );
  }
}
