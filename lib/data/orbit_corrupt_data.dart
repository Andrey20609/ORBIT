final class OrbitCorruptDataException implements Exception {
  const OrbitCorruptDataException({
    required this.storageKey,
    required this.backupKey,
    required this.originalError,
  });

  final String storageKey;
  final String backupKey;
  final Object originalError;

  @override
  String toString() =>
      'Corrupt ORBIT data at $storageKey; raw payload preserved at $backupKey: '
      '$originalError';
}

abstract interface class OrbitCorruptDataRecovery {
  Future<void> resetCorruptData();
  Future<String> exportCorruptBackup();
}
