import 'dart:math' as math;

// Camera following is independent of route guidance. An explicit recenter may
// use the last known fix even when stale; guidance still requires fresh GPS.
class FollowCamera {
  bool following = true;
  void browse() {
    following = false;
  }

  void recenter() {
    following = true;
  }

  static const pitch = 60.0;
  static double zoom({
    required double speedKmh,
    required bool navigating,
    double? turnMeters,
  }) {
    final speed = speedKmh.isFinite ? math.max(0.0, speedKmh) : 0.0;
    final base = speed <= 30
        ? 17.8
        : speed <= 60
        ? 17.8 - (speed - 30) / 30 * .9
        : speed <= 100
        ? 16.9 - (speed - 60) / 40
        : 15.9;
    if (!navigating || turnMeters == null || !turnMeters.isFinite) return base;
    final boost = turnMeters <= 60
        ? 18.5
        : turnMeters <= 150
        ? 18.2
        : turnMeters <= 350
        ? 17.7
        : turnMeters <= 700
        ? 17.0
        : base;
    return math.max(base, boost).clamp(15.5, 18.5);
  }
}
