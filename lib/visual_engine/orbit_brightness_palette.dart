import 'package:flutter/material.dart';

import 'appearance_settings.dart';
import 'orbit_palette.dart';

final class OrbitBrightnessPalette {
  const OrbitBrightnessPalette._();

  static const int _cacheLimit = 64;
  static final Map<String, OrbitPalette> _cache = <String, OrbitPalette>{};

  static OrbitPalette variant(OrbitProfile profile, Brightness brightness) =>
      OrbitPalette.ofBrightness(profile, brightness);

  static OrbitPalette resolve(
    OrbitProfile profile,
    Brightness brightness,
    Color accent,
  ) {
    final key = '${profile.name}|${brightness.name}|${accent.toARGB32()}';
    final cached = _cache[key];
    if (cached != null) return cached;
    final resolved = variant(profile, brightness).withAccent(accent);
    if (_cache.length >= _cacheLimit) _cache.clear();
    _cache[key] = resolved;
    return resolved;
  }

  static Brightness effectiveBrightness(
    ThemeMode mode,
    Brightness platformBrightness,
  ) => switch (mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => platformBrightness,
  };

  static void debugClearCache() => _cache.clear();

  static int get debugCacheSize => _cache.length;
}
