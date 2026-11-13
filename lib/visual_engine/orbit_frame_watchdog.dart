final class OrbitFrameWatchdog {
  DateTime? _createdAt;
  DateTime? _lastAdvanceAt;
  int _lastFrames = 0;

  void start(DateTime now) {
    _createdAt = now;
    _lastAdvanceAt = null;
    _lastFrames = 0;
  }

  void record(int frames, DateTime now) {
    if (frames > _lastFrames) _lastAdvanceAt = now;
    _lastFrames = frames;
  }

  void pause(DateTime now) => start(now);

  bool isStalled(
    DateTime now, {
    required bool resumed,
    required bool tickerEnabled,
  }) {
    if (!resumed || !tickerEnabled) return false;
    final created = _createdAt;
    final lastAdvance = _lastAdvanceAt;
    if (lastAdvance != null) {
      return now.difference(lastAdvance) > const Duration(seconds: 6);
    }
    return created != null &&
        now.difference(created) > const Duration(seconds: 10);
  }
}
