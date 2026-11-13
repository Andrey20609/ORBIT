import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_frame_watchdog.dart';

void main() {
  test('watchdog detects first-frame and advancing-frame stalls', () {
    final start = DateTime(2026, 11, 7, 12);
    final watchdog = OrbitFrameWatchdog()..start(start);
    expect(
      watchdog.isStalled(
        start.add(const Duration(seconds: 9)),
        resumed: true,
        tickerEnabled: true,
      ),
      isFalse,
    );
    expect(
      watchdog.isStalled(
        start.add(const Duration(seconds: 11)),
        resumed: true,
        tickerEnabled: true,
      ),
      isTrue,
    );

    watchdog.start(start);
    watchdog.record(12, start);
    expect(
      watchdog.isStalled(
        start.add(const Duration(seconds: 6)),
        resumed: true,
        tickerEnabled: true,
      ),
      isFalse,
    );
    expect(
      watchdog.isStalled(
        start.add(const Duration(seconds: 7)),
        resumed: true,
        tickerEnabled: true,
      ),
      isTrue,
    );
    expect(
      watchdog.isStalled(
        start.add(const Duration(seconds: 20)),
        resumed: false,
        tickerEnabled: true,
      ),
      isFalse,
    );
  });

  test('planned pause resets the inactivity window', () {
    final start = DateTime(2026, 11, 9, 12);
    final watchdog = OrbitFrameWatchdog()..start(start);
    watchdog.record(12, start);
    watchdog.pause(start.add(const Duration(seconds: 5)));
    expect(
      watchdog.isStalled(
        start.add(const Duration(seconds: 14)),
        resumed: true,
        tickerEnabled: true,
      ),
      isFalse,
    );
    watchdog.record(13, start.add(const Duration(seconds: 14)));
    expect(
      watchdog.isStalled(
        start.add(const Duration(seconds: 19)),
        resumed: true,
        tickerEnabled: true,
      ),
      isFalse,
    );
    expect(
      watchdog.isStalled(
        start.add(const Duration(seconds: 21)),
        resumed: true,
        tickerEnabled: true,
      ),
      isTrue,
    );
  });
}
