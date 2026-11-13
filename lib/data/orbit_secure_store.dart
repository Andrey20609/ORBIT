import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/module_interfaces.dart';

final class FlutterOrbitSecretStore implements OrbitSecretStore {
  const FlutterOrbitSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class MemoryOrbitSecretStore implements OrbitSecretStore {
  MemoryOrbitSecretStore([Map<String, String>? initial])
    : _store = initial != null ? Map.of(initial) : {};

  final Map<String, String> _store;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  bool containsKey(String key) => _store.containsKey(key);
  void clear() => _store.clear();
}
