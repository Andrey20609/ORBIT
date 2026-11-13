import 'package:flutter/material.dart';

import 'appearance_settings.dart';

@immutable
final class OrbitPalette {
  const OrbitPalette({
    required this.profile,
    required this.name,
    required this.subtitle,
    required this.skyTop,
    required this.skyBottom,
    required this.surface,
    required this.surfaceStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentSecondary,
    required this.mountainNear,
    required this.mountainFar,
    required this.sun,
    required this.isLight,
    required this.serif,
  });

  final OrbitProfile profile;
  final String name;
  final String subtitle;
  final Color skyTop;
  final Color skyBottom;
  final Color surface;
  final Color surfaceStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentSecondary;
  final Color mountainNear;
  final Color mountainFar;
  final Color sun;
  final bool isLight;
  final bool serif;

  static const one = OrbitPalette(
    profile: OrbitProfile.one,
    name: 'ORBIT One',
    subtitle: 'Универсальный · глубокий фокус',
    skyTop: Color(0xFF11152F),
    skyBottom: Color(0xFF5A497B),
    surface: Color(0x72191D38),
    surfaceStrong: Color(0xE61B2039),
    textPrimary: Color(0xFFF8F7FF),
    textSecondary: Color(0xB8C5C6DC),
    accent: Color(0xFF9B8CFF),
    accentSecondary: Color(0xFF78D9FF),
    mountainNear: Color(0xFF15182D),
    mountainFar: Color(0xFF514767),
    sun: Color(0xFFFFD2AB),
    isLight: false,
    serif: false,
  );

  static const atelier = OrbitPalette(
    profile: OrbitProfile.atelier,
    name: 'ORBIT Atelier',
    subtitle: 'Атмосферный · утончённая точность',
    skyTop: Color(0xFF14172B),
    skyBottom: Color(0xFFAD6E72),
    surface: Color(0x70241E2D),
    surfaceStrong: Color(0xE624202E),
    textPrimary: Color(0xFFFFF8F0),
    textSecondary: Color(0xC4D8C9C9),
    accent: Color(0xFFC4A8FF),
    accentSecondary: Color(0xFFFFC99B),
    mountainNear: Color(0xFF211E2C),
    mountainFar: Color(0xFF695066),
    sun: Color(0xFFFFD8A6),
    isLight: false,
    serif: true,
  );

  static const flow = OrbitPalette(
    profile: OrbitProfile.flow,
    name: 'ORBIT Flow',
    subtitle: 'Динамичный · живой цифровой поток',
    skyTop: Color(0xFF071B2A),
    skyBottom: Color(0xFF174E63),
    surface: Color(0x590B2B3A),
    surfaceStrong: Color(0xE60B2533),
    textPrimary: Color(0xFFF4FFFF),
    textSecondary: Color(0xC8D8F4F5),
    accent: Color(0xFF64E6D2),
    accentSecondary: Color(0xFF75C9FF),
    mountainNear: Color(0xFF092A35),
    mountainFar: Color(0xFF1B4E5D),
    sun: Color(0xFF9CF6E8),
    isLight: false,
    serif: false,
  );

  static const zen = OrbitPalette(
    profile: OrbitProfile.zen,
    name: 'ORBIT Zen',
    subtitle: 'Светлый · воздух и концентрация',
    skyTop: Color(0xFFE8E8F7),
    skyBottom: Color(0xFFFFE4D3),
    surface: Color(0xA8FFFFFF),
    surfaceStrong: Color(0xF5FAF9FF),
    textPrimary: Color(0xFF22243A),
    textSecondary: Color(0xFF696B83),
    accent: Color(0xFF8473E8),
    accentSecondary: Color(0xFF70A9C7),
    mountainNear: Color(0xFF98A3B9),
    mountainFar: Color(0xFFC4C3D3),
    sun: Color(0xFFFFF0C2),
    isLight: true,
    serif: false,
  );

  static const oneLight = OrbitPalette(
    profile: OrbitProfile.one,
    name: 'ORBIT One',
    subtitle: 'Универсальный · глубокий фокус',
    skyTop: Color(0xFFECEEFB),
    skyBottom: Color(0xFFD6D4EE),
    surface: Color(0xB8FFFFFF),
    surfaceStrong: Color(0xF2FAFAFF),
    textPrimary: Color(0xFF1A1C33),
    textSecondary: Color(0xFF5B5E78),
    accent: Color(0xFF6A5CE0),
    accentSecondary: Color(0xFF2FA9D6),
    mountainNear: Color(0xFFB9BFD6),
    mountainFar: Color(0xFFC9C7DE),
    sun: Color(0xFFF3B27A),
    isLight: true,
    serif: false,
  );

  static const atelierLight = OrbitPalette(
    profile: OrbitProfile.atelier,
    name: 'ORBIT Atelier',
    subtitle: 'Атмосферный · утончённая точность',
    skyTop: Color(0xFFF3ECF0),
    skyBottom: Color(0xFFE7D4D4),
    surface: Color(0xB8FFFFFF),
    surfaceStrong: Color(0xF4FBF8F8),
    textPrimary: Color(0xFF2A1F2C),
    textSecondary: Color(0xFF6E5A63),
    accent: Color(0xFF8A6FD6),
    accentSecondary: Color(0xFFD98A5A),
    mountainNear: Color(0xFFC9B9C2),
    mountainFar: Color(0xFFD6C6CB),
    sun: Color(0xFFE8A87C),
    isLight: true,
    serif: true,
  );

  static const flowLight = OrbitPalette(
    profile: OrbitProfile.flow,
    name: 'ORBIT Flow',
    subtitle: 'Динамичный · живой цифровой поток',
    skyTop: Color(0xFFE6F5F7),
    skyBottom: Color(0xFFD2E7EE),
    surface: Color(0xB8FFFFFF),
    surfaceStrong: Color(0xF4FAFBFF),
    textPrimary: Color(0xFF15303A),
    textSecondary: Color(0xFF526D75),
    accent: Color(0xFF168F8A),
    accentSecondary: Color(0xFF2479A8),
    mountainNear: Color(0xFF9ABDC7),
    mountainFar: Color(0xFFB5CED8),
    sun: Color(0xFF9CF6E8),
    isLight: true,
    serif: false,
  );

  static const zenDark = OrbitPalette(
    profile: OrbitProfile.zen,
    name: 'ORBIT Zen',
    subtitle: 'Тихий · воздух и концентрация',
    skyTop: Color(0xFF15172A),
    skyBottom: Color(0xFF2B2438),
    surface: Color(0x661B1D2E),
    surfaceStrong: Color(0xE61A1C2C),
    textPrimary: Color(0xFFEDEDF6),
    textSecondary: Color(0xB8B9C3D4),
    accent: Color(0xFFA89AF0),
    accentSecondary: Color(0xFF88C0D8),
    mountainNear: Color(0xFF20233A),
    mountainFar: Color(0xFF3A3A52),
    sun: Color(0xFFE8D7A4),
    isLight: false,
    serif: false,
  );

  OrbitPalette withAccent(Color value) {
    final hsl = HSLColor.fromColor(value);
    // Preserve custom hues without allowing low-contrast controls on light scenes.
    final effectiveValue = isLight && hsl.lightness > 0.48
        ? hsl
              .withLightness(0.48)
              .withSaturation(hsl.saturation > 0.65 ? 0.65 : hsl.saturation)
              .toColor()
        : value;
    return OrbitPalette(
      profile: profile,
      name: name,
      subtitle: subtitle,
      skyTop: skyTop,
      skyBottom: skyBottom,
      surface: surface,
      surfaceStrong: surfaceStrong,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: effectiveValue,
      accentSecondary: accentSecondary,
      mountainNear: mountainNear,
      mountainFar: mountainFar,
      sun: sun,
      isLight: isLight,
      serif: serif,
    );
  }

  static OrbitPalette of(OrbitProfile profile) => switch (profile) {
    OrbitProfile.one => one,
    OrbitProfile.atelier => atelier,
    OrbitProfile.flow => flow,
    OrbitProfile.zen => zen,
  };

  static OrbitPalette fromProfile(
    OrbitProfile profile, {
    bool isLight = false,
  }) => ofBrightness(profile, isLight ? Brightness.light : Brightness.dark);

  static OrbitPalette ofBrightness(
    OrbitProfile profile,
    Brightness brightness,
  ) => switch ((profile, brightness == Brightness.light)) {
    (OrbitProfile.one, true) => oneLight,
    (OrbitProfile.atelier, true) => atelierLight,
    (OrbitProfile.flow, true) => flowLight,
    (OrbitProfile.zen, true) => zen,
    (OrbitProfile.one, false) => one,
    (OrbitProfile.atelier, false) => atelier,
    (OrbitProfile.flow, false) => flow,
    (OrbitProfile.zen, false) => zenDark,
  };

  ThemeData themeData(Color accentOverride) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accentOverride,
      brightness: isLight ? Brightness.light : Brightness.dark,
      surface: surfaceStrong,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: accentOverride,
        onPrimary: isLight ? Colors.white : const Color(0xFF151329),
        surface: surfaceStrong,
        onSurface: textPrimary,
        secondary: accentSecondary,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: serif ? 'OrbitSerif' : 'OrbitSans',
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceStrong.withValues(alpha: isLight ? 0.95 : 0.88),
        contentTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontFamily: serif ? 'OrbitSerif' : 'OrbitSans',
        ),
        actionTextColor: accentOverride,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        elevation: 12,
        insetPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 92),
      ),
      dividerColor: textSecondary.withValues(alpha: 0.16),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: serif ? 38 : 32,
          height: 1.08,
          fontWeight: FontWeight.w500,
          letterSpacing: serif ? -0.4 : -1.1,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: serif ? 30 : 25,
          height: 1.15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.55,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: textPrimary),
        bodyMedium: TextStyle(
          fontSize: 13.5,
          height: 1.42,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
          color: textPrimary,
        ),
        labelSmall: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.35,
          color: textSecondary,
        ),
      ),
    );
  }
}
