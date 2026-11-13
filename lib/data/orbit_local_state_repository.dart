import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'orbit_corrupt_data.dart';
import 'orbit_local_state_codec.dart';

typedef OrbitBackupWriter = Future<bool> Function(String key, String value);

abstract interface class OrbitLocalStateRepository {
  Future<Map<String, Object?>> load();
  Future<void> save(Map<String, Object?> state);
}

final class SharedPreferencesLocalStateRepository
    implements OrbitLocalStateRepository, OrbitCorruptDataRecovery {
  SharedPreferencesLocalStateRepository({
    SharedPreferences? preferences,
    OrbitBackupWriter? backupWriter,
  }) : _providedPreferences = preferences,
       _backupWriter = backupWriter;

  static const storageKey = 'orbit.local.state.v1';
  static const backupKey = '$storageKey.corruptBackup';
  final SharedPreferences? _providedPreferences;
  final OrbitBackupWriter? _backupWriter;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async => _preferences ??=
      _providedPreferences ?? await SharedPreferences.getInstance();

  @override
  Future<Map<String, Object?>> load() async {
    final raw = (await _store).getString(storageKey);
    if (raw == null || raw.isEmpty) return <String, Object?>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('ORBIT local state must be a JSON object');
      }
      OrbitLocalStateCodec.validate(decoded);
      return decoded;
    } on FormatException catch (error) {
      final backupWritten = _backupWriter != null
          ? await _backupWriter(backupKey, raw)
          : await (await _store).setString(backupKey, raw);
      if (!backupWritten) {
        throw StateError('ORBIT corrupt backup could not be written');
      }
      throw OrbitCorruptDataException(
        storageKey: storageKey,
        backupKey: backupKey,
        originalError: error,
      );
    }
  }

  @override
  Future<void> save(Map<String, Object?> state) async {
    final written = await (await _store).setString(
      storageKey,
      jsonEncode(state),
    );
    if (!written) throw StateError('ORBIT local state could not be persisted');
  }

  @override
  Future<void> resetCorruptData() async {
    if (!await (await _store).remove(storageKey)) {
      throw StateError('ORBIT corrupt local state could not be reset');
    }
  }

  @override
  Future<String> exportCorruptBackup() async {
    final raw =
        (await _store).getString(backupKey) ??
        (await _store).getString(storageKey);
    if (raw == null || raw.isEmpty) {
      throw StateError('No corrupt local backup is available');
    }
    final path = await const MethodChannel('orbit/qa').invokeMethod<String>(
      'exportText',
      <String, Object?>{
        'name': 'local-state',
        'directory': 'ORBIT_recovery',
        'text': raw,
      },
    );
    if (path == null || path.isEmpty) {
      throw StateError('Corrupt local backup export failed');
    }
    return path;
  }
}

final class MemoryLocalStateRepository implements OrbitLocalStateRepository {
  MemoryLocalStateRepository([Map<String, Object?>? initial])
    : _state = initial ?? <String, Object?>{};

  Map<String, Object?> _state;
  int saveCount = 0;
  bool failNextSave = false;

  @override
  Future<Map<String, Object?>> load() async =>
      jsonDecode(jsonEncode(_state)) as Map<String, Object?>;

  @override
  Future<void> save(Map<String, Object?> state) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Simulated local state write failure');
    }
    _state = jsonDecode(jsonEncode(state)) as Map<String, Object?>;
    saveCount += 1;
  }
}
