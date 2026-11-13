import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rive/rive.dart' as rive;

import 'app.dart';
import 'state/app_state.dart';
import 'visual_engine/orbit_visual_engine.dart';
import 'visual_engine/rive_capability.dart';
import 'widgets/orbit_living_backdrop.dart';
import 'widgets/orbit_logo.dart';
import 'widgets/orbit_rive_mark.dart';

final class OrbitBootstrap extends StatefulWidget {
  const OrbitBootstrap({
    required this.startup,
    required this.style,
    required this.quality,
    required this.appState,
    this.initializeGraphics = true,
    this.initializeLocales = true,
    super.key,
  });

  final Stopwatch startup;
  final OrbitStyleManager style;
  final OrbitQualityManager quality;
  final OrbitAppState appState;
  final bool initializeGraphics;
  final bool initializeLocales;

  @override
  State<OrbitBootstrap> createState() => _OrbitBootstrapState();
}

final class _OrbitBootstrapState extends State<OrbitBootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    OrbitRiveMark.runtimeAvailable = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        '[ORBIT startup] firstFrameMs=${widget.startup.elapsedMilliseconds}',
      );
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadLocales(),
      _loadAppearance(),
      _loadLocalState(),
      _loadShaders(),
      _loadLivingWallpaper(),
    ]);
    debugPrint(
      '[ORBIT startup] dataReadyMs=${widget.startup.elapsedMilliseconds}',
    );
    if (!mounted) return;
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        '[ORBIT startup] interactiveTodayMs=${widget.startup.elapsedMilliseconds}',
      );
      if (widget.initializeGraphics) unawaited(_initializeRive());
    });
  }

  Future<void> _loadLocales() async {
    if (!widget.initializeLocales) return;
    try {
      await Future.wait([
        for (final locale in const ['ru', 'en', 'de', 'fr', 'es'])
          initializeDateFormatting(locale),
      ]);
      debugPrint('[ORBIT startup] locale data ready');
    } on Object catch (error) {
      debugPrint('[ORBIT startup] locale initialization failed: $error');
    }
  }

  Future<void> _loadAppearance() async {
    try {
      await widget.style.load().timeout(const Duration(seconds: 5));
      debugPrint('[ORBIT startup] appearance ready');
    } on Object catch (error) {
      widget.style.setLoadError(error);
      debugPrint('[ORBIT startup] appearance restore failed: $error');
    }
  }

  Future<void> _loadLocalState() async {
    try {
      await widget.appState.load().timeout(const Duration(seconds: 5));
      debugPrint('[ORBIT startup] local state ready');
    } on Object catch (error) {
      widget.appState.setLoadError(error);
      debugPrint('[ORBIT startup] local state restore failed: $error');
    }
  }

  Future<void> _loadLivingWallpaper() async {
    try {
      await orbitWallpaperController
          .loadFromPreferences()
          .timeout(const Duration(seconds: 3));
      debugPrint('[ORBIT startup] living wallpaper ready');
    } on Object catch (error) {
      debugPrint('[ORBIT startup] living wallpaper restore notice: $error');
    }
  }

  Future<void> _loadShaders() async {
    try {
      await OrbitShaderEngine.instance.initialize();
      debugPrint('[ORBIT startup] shaders ready');
    } catch (e) {
      debugPrint('[ORBIT startup] shader initialization notice: $e');
    }
  }

  Future<void> _initializeRive() async {
    try {
      if (await shouldInitializeOrbitRive()) {
        await rive.RiveNative.init().timeout(const Duration(seconds: 8));
        OrbitRiveMark.runtimeAvailable = true;
        OrbitRiveMark.runtimeInitializationError = null;
        debugPrint('[ORBIT startup] Rive ready');
      } else {
        OrbitRiveMark.runtimeAvailable = false;
        OrbitRiveMark.runtimeInitializationError = StateError(
          'Rive native is disabled for the x86_64 release GPU driver; Static is active',
        );
        debugPrint(
          '[ORBIT startup] Rive skipped for release driver compatibility',
        );
      }
    } on Object catch (error) {
      OrbitRiveMark.runtimeAvailable = false;
      OrbitRiveMark.runtimeInitializationError = error;
      debugPrint('[ORBIT startup] Rive initialization failed: $error');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return OrbitVisualLabApp(
        style: widget.style,
        quality: widget.quality,
        appState: widget.appState,
      );
    }
    return const _OrbitStartupShell();
  }
}

final class _OrbitStartupShell extends StatelessWidget {
  const _OrbitStartupShell();

  @override
  Widget build(BuildContext context) {
    final palette = OrbitPalette.one;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: palette.themeData(palette.accent),
      home: Scaffold(
        key: const Key('orbit-startup-shell'),
        backgroundColor: palette.skyTop,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OrbitLogo(palette: palette, size: 92),
                const SizedBox(height: 20),
                Text(
                  'ORBIT',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontFamily: 'OrbitSans',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.accentSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
