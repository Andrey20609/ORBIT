import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_quality_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runtime diagnostics merge, snapshot and clear without root notify', () {
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);
    var notifications = 0;
    quality.addListener(() => notifications++);

    quality.updateRuntimeDiagnostics('visual-lab', {
      'requestedRenderer': 'filament',
      'actualRenderer': 'static',
      'renderedFrames': 0,
    });
    quality.updateRuntimeDiagnostics('visual-lab', {
      'initialized': true,
      'sceneReady': true,
      'hasSwapChain': true,
      'renderedFrames': 42,
      'framesDelta5Seconds': 150,
      'actualRenderer': 'filament',
    });

    final stats = quality.runtimeDiagnosticsFor('visual-lab');
    expect(stats['requestedRenderer'], 'filament');
    expect(stats['actualRenderer'], 'filament');
    expect(stats['initialized'], isTrue);
    expect(stats['sceneReady'], isTrue);
    expect(stats['hasSwapChain'], isTrue);
    expect(stats['renderedFrames'], 42);
    expect(stats['framesDelta5Seconds'], 150);
    expect(stats['updatedAt'], isA<String>());
    expect(notifications, 0, reason: 'Counters must not rebuild the app root');

    final snapshot = quality.diagnosticsSnapshot();
    expect(snapshot['visual-lab'], isA<Map<String, Object?>>());
    expect(snapshot['appResumed'], isTrue);
    quality.clearRuntimeDiagnostics('visual-lab');
    expect(quality.runtimeDiagnosticsFor('visual-lab'), isEmpty);
  });
}
