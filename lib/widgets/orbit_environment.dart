import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../visual_engine/orbit_brightness_palette.dart';
import '../visual_engine/orbit_visual_engine.dart';

final class OrbitEnvironment extends InheritedModel<String> {
  const OrbitEnvironment({
    required this.style,
    required this.quality,
    required this.appState,
    required this.appearanceSettings,
    required this.resolvedQuality,
    required this.dataRevision,
    required this.graphicsFallbackReason,
    this.appearancePersistenceError,
    this.appearanceLoadError,
    this.platformBrightness = Brightness.dark,
    required super.child,
    super.key,
  });

  static const appearanceAspect = 'appearance';
  static const qualityAspect = 'quality';
  static const dataAspect = 'data';

  final OrbitStyleManager style;
  final OrbitQualityManager quality;
  final OrbitAppState appState;
  final AppearanceSettings appearanceSettings;
  final ResolvedQuality resolvedQuality;
  final int dataRevision;
  final String? graphicsFallbackReason;
  final Object? appearancePersistenceError;
  final Object? appearanceLoadError;
  final Brightness platformBrightness;

  static OrbitEnvironment of(BuildContext context, {String? aspect}) {
    final result = maybeOf(context, aspect: aspect);
    assert(result != null, 'OrbitEnvironment is missing from the widget tree');
    return result!;
  }

  static OrbitEnvironment? maybeOf(BuildContext context, {String? aspect}) {
    return InheritedModel.inheritFrom<OrbitEnvironment>(
      context,
      aspect: aspect,
    );
  }

  static OrbitEnvironment read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<OrbitEnvironment>();
    assert(element != null, 'OrbitEnvironment is missing from the widget tree');
    return element!.widget as OrbitEnvironment;
  }

  Brightness get effectiveBrightness =>
      OrbitBrightnessPalette.effectiveBrightness(
        appearanceSettings.themeMode,
        platformBrightness,
      );

  OrbitPalette get palette => OrbitBrightnessPalette.resolve(
    appearanceSettings.profile,
    effectiveBrightness,
    appearanceSettings.accentColor,
  );

  bool _appearanceChanged(OrbitEnvironment oldWidget) =>
      appearanceSettings != oldWidget.appearanceSettings ||
      appearancePersistenceError != oldWidget.appearancePersistenceError ||
      appearanceLoadError != oldWidget.appearanceLoadError ||
      platformBrightness != oldWidget.platformBrightness;

  bool _qualityChanged(OrbitEnvironment oldWidget) =>
      resolvedQuality != oldWidget.resolvedQuality ||
      graphicsFallbackReason != oldWidget.graphicsFallbackReason;

  @override
  bool updateShouldNotify(covariant OrbitEnvironment oldWidget) =>
      _appearanceChanged(oldWidget) ||
      _qualityChanged(oldWidget) ||
      dataRevision != oldWidget.dataRevision;

  @override
  bool updateShouldNotifyDependent(
    covariant OrbitEnvironment oldWidget,
    Set<String> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);
    return (dependencies.contains(appearanceAspect) &&
            _appearanceChanged(oldWidget)) ||
        (dependencies.contains(qualityAspect) && _qualityChanged(oldWidget)) ||
        (dependencies.contains(dataAspect) &&
            dataRevision != oldWidget.dataRevision);
  }

  @override
  bool isSupportedAspect(Object aspect) =>
      aspect == appearanceAspect ||
      aspect == qualityAspect ||
      aspect == dataAspect;
}
