import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/rive_capability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('orbit/system');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('missing or malformed capability response fails closed', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect(
      await shouldInitializeOrbitRive(
        channel: channel,
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isFalse,
    );

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <Object?, Object?>{},
    );
    expect(
      await shouldInitializeOrbitRive(
        channel: channel,
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isFalse,
    );
  });

  test('x86_64 release is blocked while debug and ARM64 are allowed', () async {
    Future<Map<Object?, Object?>> handler(MethodCall call) async =>
        <Object?, Object?>{
          'supportedAbis': <String>['x86_64'],
          'isDebug': false,
        };
    messenger.setMockMethodCallHandler(channel, handler);
    expect(
      await shouldInitializeOrbitRive(
        channel: channel,
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isFalse,
    );

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <Object?, Object?>{
        'supportedAbis': <String>['x86_64'],
        'isDebug': true,
      },
    );
    expect(
      await shouldInitializeOrbitRive(
        channel: channel,
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isTrue,
    );

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <Object?, Object?>{
        'supportedAbis': <String>['arm64-v8a'],
        'isDebug': false,
      },
    );
    expect(
      await shouldInitializeOrbitRive(
        channel: channel,
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isTrue,
    );
  });
}
