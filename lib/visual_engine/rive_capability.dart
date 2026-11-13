import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<bool> shouldInitializeOrbitRive({
  MethodChannel? channel,
  TargetPlatform? platform,
  bool? isWeb,
}) async {
  final currentPlatform = platform ?? defaultTargetPlatform;
  if ((isWeb ?? kIsWeb) || currentPlatform != TargetPlatform.android) {
    return true;
  }
  try {
    final info = await (channel ?? const MethodChannel('orbit/system'))
        .invokeMethod<Map<Object?, Object?>>('getSystemInfo')
        .timeout(const Duration(seconds: 3));
    final rawAbis = info?['supportedAbis'];
    final isDebug = info?['isDebug'];
    if (rawAbis is! List<Object?> || rawAbis.isEmpty || isDebug is! bool) {
      return false;
    }
    final abis = rawAbis.whereType<String>();
    return isDebug || !abis.contains('x86_64');
  } catch (error) {
    debugPrint('Renderer capability check failed; Static is active: $error');
    return false;
  }
}
