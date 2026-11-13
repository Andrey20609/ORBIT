abstract interface class OrbitModule {
  String get id;
  String get displayName;
  Future<void> initialize();
  Future<void> dispose();
}

abstract interface class OrbitBrainService {
  Stream<OrbitBrainResponse> respond(
    OrbitBrainRequest request, {
    required String languageCode,
  });
}

final class OrbitBrainRequest {
  const OrbitBrainRequest({required this.prompt, this.localContext = const {}});
  final String prompt;
  final Map<String, Object?> localContext;
}

final class OrbitBrainResponse {
  const OrbitBrainResponse({required this.text, required this.isDemo});
  final String text;
  final bool isDemo;
}

abstract interface class OrbitSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
