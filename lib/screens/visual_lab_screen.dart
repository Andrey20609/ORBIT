import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../l10n/orbit_localizations.dart';
import '../visual_engine/orbit_visual_engine.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_filament_scene.dart';
import '../widgets/orbit_page.dart';
import '../widgets/orbit_photoreal_scene.dart';
import '../widgets/orbit_rive_mark.dart';

final class VisualLabScreen extends StatefulWidget {
  const VisualLabScreen({super.key});

  @override
  State<VisualLabScreen> createState() => _VisualLabScreenState();
}

final class _VisualLabScreenState extends State<VisualLabScreen> {
  static const _diagnosticsId = 'visual-lab';
  static const _qaChannel = MethodChannel('orbit/qa');
  Timer? _diagnosticsTimer;
  bool _qaBusy = false;
  String _qaStatus = 'QA export: NOT RUN';
  String? _lastQaPath;
  VoidCallback? _rivePulse;
  Map<Object?, Object?> _systemInfo = const <Object?, Object?>{};

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _diagnosticsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_loadSystemInfo());
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selectRenderer(OrbitEnvironment.read(context).style.settings.renderer);
      }
    });
    unawaited(_loadSystemInfo());
  }

  Future<void> _loadSystemInfo() async {
    if (!_android || !io.Platform.isAndroid) return;
    try {
      final value = await const MethodChannel('orbit/system')
          .invokeMethod<Map<Object?, Object?>>('getSystemInfo')
          .timeout(const Duration(seconds: 3));
      if (mounted && value != null) setState(() => _systemInfo = value);
    } on Object catch (error) {
      debugPrint('Build metadata unavailable: $error');
    }
  }

  @override
  void dispose() {
    _diagnosticsTimer?.cancel();
    super.dispose();
  }

  void _selectRenderer(TodayRenderer renderer) {
    final env = OrbitEnvironment.read(context);
    _rivePulse = null;
    env.quality.clearRuntimeDiagnostics(_diagnosticsId);
    if (renderer == TodayRenderer.procedural) {
      env.quality.updateRuntimeDiagnostics(_diagnosticsId, {
        'requestedRenderer': 'static',
        'actualRenderer': 'static',
        'fallbackReason': null,
        'lastError': null,
      });
    } else if (renderer == TodayRenderer.rive) {
      env.quality.updateRuntimeDiagnostics(_diagnosticsId, {
        'requestedRenderer': 'rive',
        'actualRenderer': 'static',
        'nativePending': env.resolvedQuality != ResolvedQuality.static,
        'fallbackReason': env.resolvedQuality == ResolvedQuality.static
            ? 'Quality or system constraints'
            : null,
        'lastError': null,
      });
    } else if (renderer == TodayRenderer.filament &&
        (!_android || env.resolvedQuality == ResolvedQuality.static)) {
      env.quality.updateRuntimeDiagnostics(_diagnosticsId, {
        'requestedRenderer': 'filament',
        'actualRenderer': 'static',
        'nativePending': false,
        'fallbackReason': !_android
            ? 'Filament requires an Android device'
            : 'Quality or system constraints',
        'lastError': null,
      });
    }
    unawaited(env.style.setRenderer(renderer));
    setState(() {});
  }

  Future<void> _captureQaBundle() async {
    if (_qaBusy) return;
    final env = OrbitEnvironment.read(context);
    final style = env.style;
    final quality = env.quality;
    final original = style.settings;
    final captures = <Map<String, Object?>>[];
    final runtimeByRenderer = <String, Object?>{};
    setState(() {
      _qaBusy = true;
      _lastQaPath = null;
      _qaStatus = 'QA capture: preparing…';
    });

    try {
      // Capture is deliberately sequential and user initiated. No network or
      // background upload is involved; every requested/actual pair is stored.
      await style.setQuality(OrbitQuality.balanced);
      await style.setMotionEnabled(true);
      for (final renderer in TodayRenderer.values) {
        if (!mounted) return;
        _selectRenderer(renderer);
        final wait = switch (renderer) {
          TodayRenderer.procedural => const Duration(milliseconds: 900),
          TodayRenderer.rive => const Duration(seconds: 3),
          TodayRenderer.filament => const Duration(milliseconds: 6500),
        };
        setState(
          () => _qaStatus =
              'QA capture: ${renderer.name} (${wait.inSeconds}s runtime window)…',
        );
        await Future<void>.delayed(wait);
        if (!mounted) return;
        if (renderer == TodayRenderer.rive) {
          // The explicit QA action also exercises the real state-machine input.
          _rivePulse?.call();
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
        }
        final stats = quality.runtimeDiagnosticsFor(_diagnosticsId);
        runtimeByRenderer[renderer.name] = stats;
        final requestedRenderer = renderer == TodayRenderer.procedural
            ? 'static'
            : renderer.name;
        final capture = await _qaChannel.invokeMethod<Map<Object?, Object?>>(
          'captureWindow',
          <String, Object?>{
            'name': requestedRenderer,
            'requestedRenderer': requestedRenderer,
          },
        );
        if (capture == null || capture['path'] is! String) {
          throw StateError('Android returned no PNG for ${renderer.name}');
        }
        captures.add(<String, Object?>{
          'requestedRenderer': requestedRenderer,
          'path': capture['path'],
          'captureMethod': capture['captureMethod'],
          'width': capture['width'],
          'height': capture['height'],
          'actualRenderer': stats['actualRenderer'],
        });
      }
      if (!mounted) return;
      setState(() => _qaStatus = 'QA capture: creating local ZIP…');
      final rive = runtimeByRenderer['rive'] as Map<String, Object?>? ?? {};
      final filament =
          runtimeByRenderer['filament'] as Map<String, Object?>? ?? {};
      final riveProof =
          rive['actualRenderer'] == 'rive' &&
          rive['rivLoaded'] == true &&
          rive['artboardReady'] == true &&
          rive['stateMachineReady'] == true &&
          rive['stateMachineAdvancing'] == true &&
          (rive['stateMachineAdvanceCount'] as num? ?? 0) > 0 &&
          rive['pulseAvailable'] == true &&
          (rive['pulseCount'] as num? ?? 0) > 0;
      final filamentProof =
          filament['actualRenderer'] == 'filament' &&
          filament['initialized'] == true &&
          filament['sceneReady'] == true &&
          filament['hasSwapChain'] == true &&
          filament['lastError'] == null &&
          (filament['renderedFrames'] as num? ?? 0) > 0 &&
          (filament['framesDelta5Seconds'] as num? ?? 0) > 0;
      final nativeProofPassed = riveProof && filamentProof;
      final result = await _qaChannel.invokeMethod<Map<Object?, Object?>>(
        'exportQa',
        <String, Object?>{
          'captures': captures,
          'settingsJson': jsonEncode(<String, Object?>{
            'demoData': true,
            'originalSettings': original.toJson(),
          }),
          'runtimeStatsJson': jsonEncode(<String, Object?>{
            'renderers': runtimeByRenderer,
            'system': quality.diagnosticsSnapshot(),
          }),
          'checksJson': jsonEncode(<String, Object?>{
            'userInitiated': true,
            'externalUpload': false,
            'threePngCaptured': captures.length == 3,
            'riveRuntimeActive': rive['actualRenderer'] == 'rive',
            'rivLoaded': rive['rivLoaded'] == true,
            'artboardReady': rive['artboardReady'] == true,
            'stateMachineReady': rive['stateMachineReady'] == true,
            'stateMachineAdvancing': rive['stateMachineAdvancing'] == true,
            'stateMachineAdvanceCount':
                rive['stateMachineAdvanceCount'] as num? ?? 0,
            'pulseAvailable': rive['pulseAvailable'] == true,
            'pulseActivated': (rive['pulseCount'] as num? ?? 0) > 0,
            'filamentRuntimeActive': filament['actualRenderer'] == 'filament',
            'filamentInitialized': filament['initialized'] == true,
            'filamentSceneReady': filament['sceneReady'] == true,
            'filamentSwapChainReady': filament['hasSwapChain'] == true,
            'filamentFramesRendered':
                (filament['renderedFrames'] as num? ?? 0) > 0,
            'filamentFramesIncreasing':
                (filament['framesDelta5Seconds'] as num? ?? 0) > 0,
            'riveProofPassed': riveProof,
            'filamentProofPassed': filamentProof,
            'nativeProofPassed': nativeProofPassed,
            'nativeProofVerdict': nativeProofPassed ? 'PASS' : 'FAIL',
            'physicalPerformanceMeasured': false,
            'performanceVerdict': 'NOT MEASURED by QA capture',
          }),
        },
      );
      final path = result?['path'] as String?;
      if (path == null) throw StateError('Android returned no QA ZIP path');
      if (!mounted) return;
      setState(() {
        _lastQaPath = path;
        _qaStatus =
            'QA ZIP saved locally — native proof ${nativeProofPassed ? 'PASS' : 'FAIL'}\n'
            '${nativeProofPassed ? 'Rive and Filament runtime checks passed.' : 'Static fallback or missing runtime proof is not a native PASS.'}\n'
            'SHA-256: ${result?['sha256']}\n$path';
      });
    } on MissingPluginException {
      if (mounted) {
        setState(() => _qaStatus = 'QA export: ANDROID DEVICE REQUIRED');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _qaStatus = 'QA export FAILED: ${error.message ?? error.code}',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _qaStatus = 'QA export FAILED: $error');
    } finally {
      // Restoring the original user choices is part of the same explicit action.
      await style.setQuality(original.quality);
      await style.setMotionEnabled(original.motionEnabled);
      await style.setRenderer(original.renderer);
      quality.clearRuntimeDiagnostics(_diagnosticsId);
      quality.updateRuntimeDiagnostics(_diagnosticsId, {
        'requestedRenderer': original.renderer == TodayRenderer.procedural
            ? 'static'
            : original.renderer.name,
        'actualRenderer': 'static',
        'nativePending':
            original.renderer != TodayRenderer.procedural &&
            quality.resolve(original) != ResolvedQuality.static,
        'fallbackReason':
            quality.resolve(original) == ResolvedQuality.static &&
                original.renderer != TodayRenderer.procedural
            ? 'Quality or system constraints'
            : null,
      });
      if (mounted) setState(() => _qaBusy = false);
    }
  }

  Future<void> _shareQaBundle() async {
    final path = _lastQaPath;
    if (path == null) return;
    try {
      await _qaChannel.invokeMethod<void>('shareQa', <String, Object?>{
        'path': path,
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _qaStatus = 'Share unavailable: ${error.message ?? error.code}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final settings = env.style.settings;
    final stats = env.quality.runtimeDiagnosticsFor(_diagnosticsId);
    final requested = settings.renderer == TodayRenderer.procedural
        ? 'static'
        : settings.renderer.name;
    final actual =
        stats['actualRenderer']?.toString() ??
        (requested == 'static' ? 'static' : 'static (pending)');
    final isFallback = requested != 'static' && actual != requested;
    return OrbitPage(
      title: 'ORBIT Diagnostics / Visual Lab',
      subtitle: context.l10n.visualLabSubtitle,
      leading: OrbitBackButton(onTap: () => context.pop()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.activeRenderer,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.rendererDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  key: const Key('renderer-selector'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final renderer in TodayRenderer.values)
                      ChoiceChip(
                        key: Key('renderer-${renderer.name}'),
                        selected: settings.renderer == renderer,
                        onSelected: _qaBusy
                            ? null
                            : (_) => _selectRenderer(renderer),
                        label: Text(switch (renderer) {
                          TodayRenderer.procedural => 'Static / Eco',
                          TodayRenderer.rive => 'Rive',
                          TodayRenderer.filament => 'Filament 3D',
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            palette: palette,
            quality: ResolvedQuality.static,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                key: const Key('selected-renderer-preview'),
                height: 220,
                child: _SelectedPreview(
                  renderer: settings.renderer,
                  diagnosticsId: _diagnosticsId,
                  onPulseReady: (callback) => _rivePulse = callback,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            palette: palette,
            quality: ResolvedQuality.static,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isFallback
                            ? 'Fallback: Static'
                            : 'Actual: ${actual.toUpperCase()}',
                        key: const Key('actual-renderer-status'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: isFallback
                                  ? palette.textPrimary
                                  : palette.accentSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (stats['nativePending'] == true)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetricRow('Requested renderer', requested),
                const Divider(height: 18),
                _MetricRow('Actual renderer', actual),
                const Divider(height: 18),
                if (settings.renderer == TodayRenderer.filament) ...[
                  _MetricRow('initialized', _boolValue(stats['initialized'])),
                  const Divider(height: 18),
                  _MetricRow('sceneReady', _boolValue(stats['sceneReady'])),
                  const Divider(height: 18),
                  _MetricRow('hasSwapChain', _boolValue(stats['hasSwapChain'])),
                  const Divider(height: 18),
                  _MetricRow(
                    'renderedFrames',
                    '${stats['renderedFrames'] ?? 'N/A'}',
                  ),
                  const Divider(height: 18),
                  _MetricRow(
                    'Δ frames / 5 seconds',
                    '${stats['framesDelta5Seconds'] ?? 'collecting…'}',
                  ),
                ] else if (settings.renderer == TodayRenderer.rive) ...[
                  _MetricRow('.riv loaded', _boolValue(stats['rivLoaded'])),
                  const Divider(height: 18),
                  _MetricRow('Artboard', '${stats['artboard'] ?? 'NOT READY'}'),
                  const Divider(height: 18),
                  _MetricRow(
                    'State machine',
                    '${stats['stateMachine'] ?? 'NOT READY'}',
                  ),
                  const Divider(height: 18),
                  _MetricRow(
                    'Native state-machine advances',
                    '${_boolValue(stats['stateMachineAdvancing'])} / ${stats['stateMachineAdvanceCount'] ?? 0}',
                  ),
                  const Divider(height: 18),
                  _MetricRow(
                    'Pulse (available / activations)',
                    '${_boolValue(stats['pulseAvailable'])} / ${stats['pulseCount'] ?? 0}',
                  ),
                ] else
                  const _MetricRow('Native engine', 'NOT REQUESTED'),
                if (stats['lastError'] != null) ...[
                  const Divider(height: 18),
                  _MetricRow('lastError', '${stats['lastError']}'),
                ],
                if (stats['fallbackReason'] != null) ...[
                  const Divider(height: 18),
                  _MetricRow('Fallback reason', '${stats['fallbackReason']}'),
                ],
              ],
            ),
          ),
          if (settings.renderer == TodayRenderer.filament && !_android) ...[
            const SizedBox(height: 12),
            OrbitFilamentScene.unsupportedNotice(context),
          ],
          if (env.quality.graphicsDiagnostics.isNotEmpty) ...[
            const SizedBox(height: 14),
            GlassPanel(
              palette: palette,
              quality: ResolvedQuality.static,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.graphicsLog,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final entry
                      in env.quality.graphicsDiagnostics.reversed.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        entry,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('capture-qa-bundle'),
                onPressed: !_android || _qaBusy ? null : _captureQaBundle,
                icon: _qaBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(_qaBusy ? 'Capturing…' : 'Capture QA ZIP'),
              ),
              OutlinedButton.icon(
                key: const Key('share-qa-bundle'),
                onPressed: _lastQaPath == null || _qaBusy
                    ? null
                    : _shareQaBundle,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Share local ZIP'),
              ),
              FilledButton.tonalIcon(
                key: const Key('open-today-lab'),
                onPressed: _qaBusy ? null : () => context.go('/today'),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(context.l10n.openToday),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Three PNGs, device/build info, settings, native stats, checks, '
            'filtered logcat and SHA-256. Local only; no background upload.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            _qaStatus,
            key: const Key('qa-export-status'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          OrbitSectionTitle('Interactive Testing'),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            quality: ResolvedQuality.static,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atmosphere Mode Test',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SegmentedButton<AtmosphereMode>(
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: AtmosphereMode.automatic,
                        label: Text('Auto'),
                      ),
                      ButtonSegment(
                        value: AtmosphereMode.dawn,
                        label: Text('Dawn'),
                      ),
                      ButtonSegment(
                        value: AtmosphereMode.day,
                        label: Text('Day'),
                      ),
                      ButtonSegment(
                        value: AtmosphereMode.sunset,
                        label: Text('Sunset'),
                      ),
                      ButtonSegment(
                        value: AtmosphereMode.night,
                        label: Text('Night'),
                      ),
                    ],
                    selected: {settings.atmosphereMode},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) {
                        OrbitEnvironment.read(context).style.setAtmosphereMode(set.first);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gyro Parallax Intensity Test',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SegmentedButton<GyroIntensity>(
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: GyroIntensity.off,
                        label: Text('Off'),
                      ),
                      ButtonSegment(
                        value: GyroIntensity.subtle,
                        label: Text('Subtle'),
                      ),
                      ButtonSegment(
                        value: GyroIntensity.enhanced,
                        label: Text('Enhanced'),
                      ),
                    ],
                    selected: {settings.gyroIntensity},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) {
                        OrbitEnvironment.read(context).style.setGyroIntensity(set.first);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Optical Glass Card Border Shader'),
                  subtitle: Text(
                    (OrbitShaderEngine.enableOpticalGlassShader &&
                          OrbitShaderEngine.instance.isAvailable &&
                          OrbitShaderEngine.instance.shaderPaintsCount > 0)
                        ? 'ENABLED (Testing: Custom Shader Border)'
                        : 'DISABLED (Default: Classic Border, No White Outline)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: OrbitShaderEngine.enableOpticalGlassShader,
                  onChanged: (val) {
                    setState(() => OrbitShaderEngine.enableOpticalGlassShader = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OrbitSectionTitle(context.l10n.measurementStatus),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            quality: ResolvedQuality.static,
            child: Column(
              children: [
                _MetricRow(
                  'Version / versionCode',
                  '${_systemInfo['versionName'] ?? '0.5.30'} / ${_systemInfo['versionCode'] ?? 36}',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Build flavor',
                  '${_systemInfo['buildFlavor'] ?? 'premium-reliability'}',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Git hash',
                  '${_systemInfo['gitHash'] ?? '6cc857e'}',
                ),
                const Divider(height: 18),
                _MetricRow('Actual renderer', actual),
                const Divider(height: 18),
                _MetricRow('Resolved quality', env.resolvedQuality.name),
                const Divider(height: 18),
                _MetricRow(
                  'Reduce motion',
                  '${MediaQuery.maybeOf(context)?.disableAnimations ?? false}',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Selected Atmosphere Mode',
                  settings.atmosphereMode.name.toUpperCase(),
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Active Atmosphere Period',
                  OrbitSceneDiagnostics.instance.activeAtmospherePeriod.name.toUpperCase(),
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Unified Scene Key',
                  OrbitSceneDiagnostics.instance.currentSceneKey,
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Layer Asset Paths',
                  OrbitSceneDiagnostics.instance.currentLayerAssetPaths.isEmpty
                      ? 'one_sky_day.webp, one_far.webp, one_mid.webp, one_fg.webp'
                      : OrbitSceneDiagnostics.instance.currentLayerAssetPaths.entries
                          .map((e) => '${e.key}: ${e.value.split("/").last}')
                          .join(' | '),
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Atmosphere Applications',
                  '${OrbitSceneDiagnostics.instance.atmosphereApplicationCount}',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Last Atmosphere Update',
                  OrbitSceneDiagnostics.instance.lastAtmosphereUpdateTime != null
                      ? '${OrbitSceneDiagnostics.instance.lastAtmosphereUpdateTime!.hour.toString().padLeft(2, "0")}:${OrbitSceneDiagnostics.instance.lastAtmosphereUpdateTime!.minute.toString().padLeft(2, "0")}:${OrbitSceneDiagnostics.instance.lastAtmosphereUpdateTime!.second.toString().padLeft(2, "0")}.${OrbitSceneDiagnostics.instance.lastAtmosphereUpdateTime!.millisecond.toString().padLeft(3, "0")}'
                      : 'None',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Asset Errors',
                  OrbitSceneDiagnostics.instance.activeErrors.isEmpty
                      ? 'None'
                      : OrbitSceneDiagnostics.instance.activeErrors.join(', '),
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Native Sensor Type',
                  '${_systemInfo['nativeSensorType'] ?? 'NONE'}',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Native Listener Registered',
                  '${_systemInfo['nativeListenerRegistered'] ?? false}',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Native Sensor Events',
                  '${_systemInfo['nativeSensorEventCount'] ?? 0}',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Dart Motion State',
                  OrbitMotionService.instance.currentState.name,
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Dart Motion Subscribers',
                  '${OrbitMotionService.instance.subscribersCount}',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Dart Motion Events',
                  '${OrbitMotionService.instance.eventCount}',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Last Event Timestamp',
                  OrbitMotionService.instance.lastEventTime != null
                      ? '${OrbitMotionService.instance.lastEventTime!.hour.toString().padLeft(2, '0')}:${OrbitMotionService.instance.lastEventTime!.minute.toString().padLeft(2, '0')}:${OrbitMotionService.instance.lastEventTime!.second.toString().padLeft(2, '0')}.${OrbitMotionService.instance.lastEventTime!.millisecond.toString().padLeft(3, '0')}'
                      : 'None',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Tilt (X, Y)',
                  '(${OrbitMotionService.instance.tiltNotifier.value.dx.toStringAsFixed(3)}, ${OrbitMotionService.instance.tiltNotifier.value.dy.toStringAsFixed(3)})',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Raw Offset (X, Y)',
                  '(${OrbitMotionService.instance.lastRawOffset.dx.toStringAsFixed(3)}, ${OrbitMotionService.instance.lastRawOffset.dy.toStringAsFixed(3)})',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Plane Offsets (Sky/Far/Mid/FG)',
                  () {
                    final offsets = OrbitMotionService.instance.calculatePlaneOffsets(
                      intensity: settings.gyroIntensity,
                    );
                    return 'Sky: ${offsets['sky']!.toStringAsFixed(1)} dp | Far: ${offsets['far']!.toStringAsFixed(1)} dp | Mid: ${offsets['mid']!.toStringAsFixed(1)} dp | FG: ${offsets['foreground']!.toStringAsFixed(1)} dp';
                  }(),
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Optical Glass Shader',
                  (OrbitShaderEngine.enableOpticalGlassShader &&
                          OrbitShaderEngine.instance.isAvailable &&
                          OrbitShaderEngine.instance.shaderPaintsCount > 0)
                      ? 'ACTIVE'
                      : 'DISABLED (Default: No White Borders)',
                ),
                const Divider(height: 18),
                _MetricRow(
                  'Shader Paints Count',
                  '${OrbitShaderEngine.instance.shaderPaintsCount}',
                ),
                const Divider(height: 18),
                const _MetricRow(
                  'Filament HDR IBL',
                  'NOT IMPLEMENTED (Spherical Harmonics active)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.performanceMethod,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  static String _boolValue(Object? value) => switch (value) {
    true => 'true',
    false => 'false',
    _ => 'N/A',
  };
}

final class _SelectedPreview extends StatelessWidget {
  const _SelectedPreview({
    required this.renderer,
    required this.diagnosticsId,
    required this.onPulseReady,
  });

  final TodayRenderer renderer;
  final String diagnosticsId;
  final ValueChanged<VoidCallback> onPulseReady;

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (renderer == TodayRenderer.filament) {
          OrbitFilamentScene.pointerHandler?.call(event);
        }
      },
      onPointerMove: (event) {
        if (renderer == TodayRenderer.filament) {
          OrbitFilamentScene.pointerHandler?.call(event);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          OrbitPhotorealScene(
            palette: palette,
            quality: ResolvedQuality.static,
            motionEnabled: false,
            settings: env.style.settings,
          ),
          if (renderer == TodayRenderer.rive)
            OrbitRiveMark(
              key: const Key('lab-rive-runtime'),
              palette: palette,
              quality: env.resolvedQuality,
              atmospheric: true,
              diagnosticsId: diagnosticsId,
              onPulseReady: onPulseReady,
              onError: (error) =>
                  env.quality.reportGraphicsFallback('Rive', error),
            ),
          if (renderer == TodayRenderer.filament &&
              !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android)
            OrbitFilamentScene(
              key: const Key('lab-filament-runtime'),
              palette: palette,
              quality: env.resolvedQuality,
              diagnosticsId: diagnosticsId,
              atmosphereMode: env.appearanceSettings.atmosphereMode,
            ),
          Positioned(
            left: 14,
            bottom: 12,
            child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surfaceStrong.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                switch (renderer) {
                  TodayRenderer.procedural => context.l10n.staticRendererTitle,
                  TodayRenderer.rive => 'Rive • tap for Pulse',
                  TodayRenderer.filament => context.l10n.nativePbr,
                },
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: palette.textPrimary),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}

final class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(label),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
