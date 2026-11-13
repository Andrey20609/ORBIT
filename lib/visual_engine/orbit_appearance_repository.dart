import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/orbit_corrupt_data.dart';
import 'appearance_settings.dart';

abstract interface class OrbitAppearanceRepository {
  Future<AppearanceSettings> load();
  Future<void> save(AppearanceSettings settings);
}

final class SharedPreferencesAppearanceRepository
    implements OrbitAppearanceRepository, OrbitCorruptDataRecovery {
  SharedPreferencesAppearanceRepository({SharedPreferences? preferences})
    : _providedPreferences = preferences;

  static const storageKey = 'orbit.visual.appearance.v1';
  static const backupKey = '$storageKey.corruptBackup';
  final SharedPreferences? _providedPreferences;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async => _preferences ??=
      _providedPreferences ?? await SharedPreferences.getInstance();

  @override
  Future<AppearanceSettings> load() async {
    final raw = (await _store).getString(storageKey);
    if (raw == null || raw.isEmpty) return const AppearanceSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('ORBIT appearance must be a JSON object');
      }
      AppearanceSettings.validateJson(decoded);
      return AppearanceSettings.fromJson(decoded);
    } on FormatException catch (error) {
      final backupWritten = await (await _store).setString(backupKey, raw);
      if (!backupWritten) {
        throw StateError(
          'ORBIT corrupt appearance backup could not be written',
        );
      }
      throw OrbitCorruptDataException(
        storageKey: storageKey,
        backupKey: backupKey,
        originalError: error,
      );
    } on TypeError catch (error) {
      final backupWritten = await (await _store).setString(backupKey, raw);
      if (!backupWritten) {
        throw StateError(
          'ORBIT corrupt appearance backup could not be written',
        );
      }
      throw OrbitCorruptDataException(
        storageKey: storageKey,
        backupKey: backupKey,
        originalError: error,
      );
    }
  }

  @override
  Future<void> save(AppearanceSettings settings) async {
    final encoded = jsonEncode(settings.toJson());
    final written = await (await _store).setString(storageKey, encoded);
    if (!written) {
      throw StateError('ORBIT appearance settings could not be persisted');
    }
  }

  @override
  Future<void> resetCorruptData() async {
    if (!await (await _store).remove(storageKey)) {
      throw StateError('ORBIT corrupt appearance could not be reset');
    }
  }

  @override
  Future<String> exportCorruptBackup() async {
    final raw =
        (await _store).getString(backupKey) ??
        (await _store).getString(storageKey);
    if (raw == null || raw.isEmpty) {
      throw StateError('No corrupt appearance backup is available');
    }
    final path = await const MethodChannel('orbit/qa').invokeMethod<String>(
      'exportText',
      <String, Object?>{
        'name': 'appearance',
        'directory': 'ORBIT_recovery',
        'text': raw,
      },
    );
    if (path == null || path.isEmpty) {
      throw StateError('Corrupt appearance backup export failed');
    }
    return path;
  }
}

final class MemoryAppearanceRepository implements OrbitAppearanceRepository {
  MemoryAppearanceRepository([AppearanceSettings? initial])
    : value = initial ?? const AppearanceSettings();

  AppearanceSettings value;
  int saveCount = 0;
  bool failNextSave = false;

  @override
  Future<AppearanceSettings> load() async => value;

  @override
  Future<void> save(AppearanceSettings settings) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Simulated storage failure');
    }
    value = settings;
    saveCount += 1;
  }
}
