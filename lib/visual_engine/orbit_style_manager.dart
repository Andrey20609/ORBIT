import 'dart:async';

import 'package:flutter/material.dart';

import '../data/orbit_corrupt_data.dart';
import '../data/orbit_load_status.dart';
import 'appearance_settings.dart';
import 'orbit_appearance_repository.dart';

final class OrbitStyleManager extends ChangeNotifier {
  OrbitStyleManager(this._repository);

  final OrbitAppearanceRepository _repository;
  AppearanceSettings _settings = const AppearanceSettings();
  Object? _lastPersistenceError;
  Object? _lastLoadError;
  AppearanceSettings? _retrySettings;
  OrbitLoadStatus _loadStatus = OrbitLoadStatus.unloaded;
  int _revision = 0;
  Future<void> _saveQueue = Future<void>.value();

  OrbitAppearanceRepository get repository => _repository;
  AppearanceSettings get settings => _settings;
  Object? get lastPersistenceError => _lastPersistenceError;
  Object? get lastLoadError => _lastLoadError;
  OrbitLoadStatus get loadStatus => _loadStatus;
  bool get isLoaded => _loadStatus == OrbitLoadStatus.loaded;

  void setLoadError(Object? error) {
    _loadStatus = error == null
        ? OrbitLoadStatus.unloaded
        : OrbitLoadStatus.transientFailure;
    _lastLoadError = error;
    notifyListeners();
  }

  Future<void> load() async {
    if (isLoaded) return;
    _loadStatus = OrbitLoadStatus.loading;
    final revision = _revision;
    try {
      final restored = await _repository.load();
      if (isLoaded) return;
      if (revision != _revision) {
        _loadStatus = OrbitLoadStatus.loaded;
        _lastLoadError = null;
        if (_retrySettings != null) await retryPersistence();
        return;
      }
      _settings = restored;
      _loadStatus = OrbitLoadStatus.loaded;
      _lastLoadError = null;
    } catch (error) {
      _loadStatus = error is OrbitCorruptDataException
          ? OrbitLoadStatus.corrupt
          : OrbitLoadStatus.transientFailure;
      _lastLoadError = error;
    }
    notifyListeners();
  }

  Future<void> retryPersistence() => _commit(_retrySettings ?? _settings);

  Future<void> setProfile(OrbitProfile value) =>
      _commit(_settings.copyWith(profile: value));

  Future<void> setQuality(OrbitQuality value) =>
      _commit(_settings.copyWith(quality: value));

  Future<void> setThemeMode(ThemeMode value) =>
      _commit(_settings.copyWith(themeMode: value));

  Future<void> setAccentColor(Color value) =>
      _commit(_settings.copyWith(accentColor: value));

  Future<void> setLanguage(String value) =>
      _commit(_settings.copyWith(languageCode: value));

  Future<void> setDensity(OrbitDensity value) =>
      _commit(_settings.copyWith(density: value));

  Future<void> setMotionEnabled(bool value) =>
      _commit(_settings.copyWith(motionEnabled: value));

  Future<void> setRenderer(TodayRenderer value) =>
      _commit(_settings.copyWith(renderer: value));

  Future<void> setAtmosphereMode(AtmosphereMode value) =>
      _commit(_settings.copyWith(atmosphereMode: value));

  Future<void> setGyroIntensity(GyroIntensity value) =>
      _commit(_settings.copyWith(gyroIntensity: value, gyroEnabled: value != GyroIntensity.off));

  Future<void> setGyroEnabled(bool value) =>
      _commit(_settings.copyWith(
        gyroEnabled: value,
        gyroIntensity: value ? GyroIntensity.enhanced : GyroIntensity.off,
      ));

  Future<void> setTextScale(double value) {
    if (!AppearanceSettings.supportedTextScales.contains(value)) {
      return Future<void>.value();
    }
    return _commit(_settings.copyWith(textScale: value));
  }

  Future<void> _commit(AppearanceSettings next) async {
    final previous = _settings;
    final revision = ++_revision;
    _settings = next;
    _retrySettings = next;
    _lastPersistenceError = null;
    notifyListeners();
    if (!isLoaded) {
      _lastPersistenceError = StateError(
        'Appearance cannot be saved before a successful load: $_loadStatus',
      );
      notifyListeners();
      return;
    }
    // SharedPreferences writes are serialized. Without this queue a slow old
    // write could finish after a newer one and restore stale settings on the
    // next launch, even though the optimistic UI already shows the new value.
    final save = _saveQueue.then((_) => _repository.save(next));
    _saveQueue = save.catchError((_) {});
    try {
      await save;
      if (revision == _revision) _retrySettings = null;
    } catch (error) {
      if (revision == _revision) {
        _settings = previous;
        _lastPersistenceError = error;
        notifyListeners();
      }
    }
  }

  Future<void> resetCorruptData() async {
    if (_repository is! OrbitCorruptDataRecovery) {
      throw StateError('Appearance recovery is unavailable');
    }
    _loadStatus = OrbitLoadStatus.resetPending;
    notifyListeners();
    await (_repository as OrbitCorruptDataRecovery).resetCorruptData();
    _loadStatus = OrbitLoadStatus.unloaded;
    _retrySettings = null;
    _lastLoadError = null;
    _lastPersistenceError = null;
    await load();
  }
}
