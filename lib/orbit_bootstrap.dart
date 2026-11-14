import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rive/rive.dart' as rive;

import 'app.dart';
import 'state/app_state.dart';
import 'visual_engine/orbit_visual_engine.dart';
import 'visual_engine/rive_capability.dart';
import 'widgets/orbit_living_backdrop.dart';
import 'widgets/orbit_rive_mark.dart';

final class OrbitBootstrap extends StatefulWidget {
  const OrbitBootstrap({
    required this.startup,
    required this.style,
    required this.quality,
    required this.appState,
    this.initializeGraphics = true,
    this.initializeLocales = true,
    this.startupArtwork,
    super.key,
  });

  final Stopwatch startup;
  final OrbitStyleManager style;
  final OrbitQualityManager quality;
  final OrbitAppState appState;
  final bool initializeGraphics;
  final bool initializeLocales;

  /// Pre-decoded branding artwork (STEP5-rework); tests pass a ready image
  /// so the shell render is deterministic. Production decodes it in
  /// [_OrbitBootstrapState._decodeBrandingArtwork].
  final ui.Image? startupArtwork;

  @override
  State<OrbitBootstrap> createState() => _OrbitBootstrapState();
}

/// STEP5-rework test hook: becomes true once the approved branding artwork
/// is decoded and the deferred first frame is released. Read-only for
/// tests; production flows never read it.
@visibleForTesting
bool orbitStartupArtworkReady = false;

/// STEP5-rework test hook: true when the branding asset failed to load and
/// the diagnostic fallback is shown.
@visibleForTesting
bool orbitStartupShellLoadFailed = false;

/// STEP5-rework: production decode path for the branding artwork — the
/// same rootBundle.load -> instantiateImageCodec chain the bootstrap runs
/// on real launches. Extracted so tests exercise the exact production
/// decode (success and failure) without the automated test binding.
@visibleForTesting
Future<ui.Image> decodeBrandingArtworkAsset([AssetBundle? bundle]) async {
  final assetBundle = bundle ?? rootBundle;
  final data = await assetBundle.load('assets/branding/orbit_splash_mark.png');
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// STEP5-rework: state machine for holding the native splash until the
/// branding artwork is ready. `hold` pairs with the platform
/// deferFirstFrame, `release` with allowFirstFrame (idempotent: a second
/// release is a no-op). Tests inject counters for onHold/onRelease so the
/// pairing is verified without the automated test binding.
@visibleForTesting
class StartupFrameGate {
  StartupFrameGate({void Function()? onHold, void Function()? onRelease})
    : _onHold = onHold,
      _onRelease = onRelease;

  final void Function()? _onHold;
  final void Function()? _onRelease;
  bool _held = false;

  bool get isHeld => _held;

  void hold() {
    if (_held) return;
    _held = true;
    _onHold?.call();
  }

  void release() {
    if (!_held) return;
    _held = false;
    _onRelease?.call();
  }
}

/// STEP5-rework: production presentation flow for the branding artwork —
/// decode via [decodeBrandingArtworkAsset], surface the result through
/// [onArtworkReady]/[onArtworkError] (the host setState) and release
/// [frameGate] on the next painted frame in BOTH paths, so the first shown
/// frame already contains the artwork and a failed asset can never leave
/// the app on a held frame. [_OrbitBootstrapState._decodeBrandingArtwork]
/// delegates here with rootBundle; tests inject a bundle (real or failing)
/// and counter-backed callbacks to verify the exact production
/// success/failure/release behaviour against the test binding.
@visibleForTesting
Future<void> decodeAndPresentStartupBranding({
  required StartupFrameGate frameGate,
  required void Function(ui.Image image) onArtworkReady,
  required void Function(Object error) onArtworkError,
  AssetBundle? bundle,
}) async {
  try {
    final image = await decodeBrandingArtworkAsset(bundle);
    onArtworkReady(image);
    WidgetsBinding.instance.addPostFrameCallback((_) => frameGate.release());
  } catch (error) {
    onArtworkError(error);
    WidgetsBinding.instance.addPostFrameCallback((_) => frameGate.release());
  }
}

final class _OrbitBootstrapState extends State<OrbitBootstrap> {
  bool _ready = false;
  late final StartupFrameGate _frameGate;
  ui.Image? _brandingArtwork;
  Object? _brandingError;

  @override
  void initState() {
    super.initState();
    OrbitRiveMark.runtimeAvailable = false;
    _brandingArtwork = widget.startupArtwork;
    // STEP5-rework: hold the native splash until the branding artwork is
    // decoded, so the first shown Flutter frame already contains it. The
    // startup shell releases the frame on success/error/dispose. The
    // automated test binding forces frames on every pump and resets the
    // deferred counter, so the hold applies to real runs only; tests verify
    // the identical gate/decode flow through decodeAndPresentStartupBranding
    // with injected callbacks instead.
    _frameGate = StartupFrameGate(
      onHold: () => WidgetsBinding.instance.deferFirstFrame(),
      onRelease: () => WidgetsBinding.instance.allowFirstFrame(),
    );
    final isTestBinding = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('Test');
    if (!isTestBinding) {
      _frameGate.hold();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        '[ORBIT startup] firstFrameMs=${widget.startup.elapsedMilliseconds}',
      );
    });
    unawaited(_initialize());
    // Branding decode runs next to readiness loading; it never blocks
    // Today readiness and never touches repositories or timings.
    unawaited(_decodeBrandingArtwork());
  }

  Future<void> _decodeBrandingArtwork() async {
    // The automated test binding cannot complete engine image decodes
    // (they would hang the fake-async test), so branding decode runs on
    // real launches only. The test suite exercises the identical
    // production flow through decodeAndPresentStartupBranding with an
    // injected bundle and counter-backed gate (see
    // test/drift_mail_step5_rework_test.dart).
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }
    await decodeAndPresentStartupBranding(
      frameGate: _frameGate,
      onArtworkReady: (image) {
        orbitStartupArtworkReady = true;
        if (!mounted) return;
        setState(() {
          _brandingArtwork = image;
          _brandingError = null;
        });
      },
      onArtworkError: (error) {
        // Explicit diagnostic: the startup shell shows its fallback
        // painter; the native splash background is never replaced by a
        // flash.
        debugPrint('[ORBIT startup] branding asset failed to load: $error');
        if (!mounted) return;
        setState(() {
          _brandingError = error;
          orbitStartupShellLoadFailed = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _frameGate.release();
    super.dispose();
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
      await orbitWallpaperController.loadFromPreferences().timeout(
        const Duration(seconds: 3),
      );
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
    return OrbitStartupShell(
      artwork: _brandingArtwork,
      loadError: _brandingError,
    );
  }
}

/// STEP5-rework: static startup shell that continues the native Android
/// splash — unified sampled background (#16182C from the approved
/// reference) and the approved artwork rendered from a ready [ui.Image].
/// The host bootstrap decodes the image BEFORE allowing the first frame
/// (deferFirstFrame/allowFirstFrame), so the first shown Flutter frame
/// already contains the mark. Fully static: no progress indicators, no
/// text, no animation; the transition to [OrbitVisualLabApp] stays the
/// existing instant switch.
///
/// Public so tests can mount the shell directly with a preloaded image.
final class OrbitStartupShell extends StatelessWidget {
  const OrbitStartupShell({super.key, this.artwork, this.loadError});

  /// Decoded branding artwork; null while decoding or on failure.
  final ui.Image? artwork;

  /// Set when the branding asset failed to load (diagnostic fallback).
  final Object? loadError;

  /// Logical size matching the native splash artwork (~168 dp).
  static const double markSize = 168;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        key: const Key('orbit-startup-shell'),
        backgroundColor: const Color(0xFF16182C),
        body: SafeArea(
          child: Center(
            child: RepaintBoundary(
              key: const Key('orbit-startup-shell-mark'),
              child: Container(
                color: const Color(0xFF16182C),
                child: SizedBox(
                  width: markSize,
                  height: markSize,
                  child: _buildMark(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMark() {
    final image = artwork;
    if (image != null) {
      return RawImage(
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }
    if (loadError != null) {
      // Diagnostic fallback: unified background plus a subtle placeholder
      // ring and (debug builds only) the loading error text.
      return CustomPaint(
        painter: _StartupMarkFallbackPainter(
          diagnostics: kDebugMode ? '$loadError' : null,
        ),
      );
    }
    // Artwork still decoding: keep the unified background so the native
    // splash visually continues without any flash or geometry change.
    return const SizedBox.expand();
  }
}

/// Synchronous diagnostic fallback used only when the branding asset fails
/// to load: unified background with a subtle placeholder ring and (debug
/// builds) the loading error text.
class _StartupMarkFallbackPainter extends CustomPainter {
  const _StartupMarkFallbackPainter({this.diagnostics});

  final String? diagnostics;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6C8CFF);
    canvas.drawCircle(center, size.width * 0.22, paint);
    if (diagnostics != null && kDebugMode) {
      final text = TextPainter(
        text: TextSpan(
          text:
              'branding asset failed; '
              'see orbit_0535_step5_report.md; '
              '$diagnostics',
          style: TextStyle(
            color: const Color(0xFFEAF0FF).withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width * 0.9);
      text.paint(
        canvas,
        Offset(center.dx - text.width / 2, center.dy + size.width * 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
