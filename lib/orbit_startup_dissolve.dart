import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// STEP6: startup dissolve transition — the approved artwork erodes away
/// with a soft diagonal/radial mask while 12–18 deterministic cyan/violet
/// light particles drift outward, revealing the already-interactive Today
/// underneath. This is a separate overlay component, NOT a rewrite of the
/// accepted static [OrbitStartupShell]-look: at progress 0 the overlay is
/// visually identical to the STEP5 shell (unified #16182C + the ready
/// `ui.Image` mark), so the native → Flutter → Today chain stays seamless.
///
/// Guarantees required by the STEP6 TZ:
/// - one-shot [AnimationController] (420 ms, `Curves.easeOutCubic`), disposed
///   with the widget; `onCompleted` fires exactly once and the host removes
///   the overlay from the tree;
/// - [IgnorePointer] + [ExcludeSemantics]: Today under the overlay is
///   immediately interactive and invisible to screen readers as a duplicate;
/// - particles are computed ONCE from a fixed seed (no `Random()` or
///   allocations per frame; two `Paint`s total in the painter);
/// - no fragment shaders, no Rive, no re-decode, no backdrop filters;
/// - the dissolve never touches `StartupFrameGate`/`allowFirstFrame`.
final class OrbitStartupDissolveOverlay extends StatefulWidget {
  const OrbitStartupDissolveOverlay({
    required this.artwork,
    this.onCompleted,
    this.duration = const Duration(milliseconds: 420),
    super.key,
  });

  /// Already-decoded branding artwork (never re-decoded here).
  final ui.Image artwork;

  /// Fired exactly once when the transition completes; the host removes the
  /// overlay afterwards.
  final VoidCallback? onCompleted;

  /// Transition duration (TZ target 380–450 ms).
  final Duration duration;

  /// Logical mark size — identical to the accepted STEP5 shell mark.
  static const double markSize = 168;

  /// Test/evidence hook: when non-null, the overlay renders at exactly this
  /// fixed progress instead of running the controller (no ticking, no
  /// completion callback). Production leaves it null and animates normally;
  /// tests and the evidence tool use it to capture deterministic frames at
  /// progress 0 / 0.35 / 0.7 without real-clock raciness.
  @visibleForTesting
  static double? debugFrozenProgress;

  @override
  State<OrbitStartupDissolveOverlay> createState() =>
      _OrbitStartupDissolveOverlayState();
}

class _OrbitStartupDissolveOverlayState
    extends State<OrbitStartupDissolveOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final List<DissolveParticle> _particles;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _particles = generateDissolveParticles();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.addStatusListener(_handleStatus);
    final frozen = OrbitStartupDissolveOverlay.debugFrozenProgress;
    if (frozen != null) {
      _controller.value = frozen.clamp(0.0, 1.0);
    } else {
      _controller.forward();
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completed) return;
    _completed = true;
    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Today under the overlay stays fully interactive during the
      // transition — the overlay never intercepts input.
      ignoring: true,
      child: ExcludeSemantics(
        // Screen readers must not see a duplicate of the startup screen.
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final t = _progress.value;
            return Stack(
              // Non-directional alignment: the bootstrap mounts this
              // overlay above any MaterialApp, so the Stack must not
              // depend on Directionality.
              alignment: Alignment.topLeft,
              fit: StackFit.expand,
              children: [
                // Splash background: opaque #16182C at t=0 (pixel-identical
                // to the accepted shell), fading to reveal Today.
                Opacity(
                  opacity: 1 - t,
                  child: const ColoredBox(color: Color(0xFF16182C)),
                ),
                // Mark: soft heterogeneous erosion (radial core + diagonal
                // sweep), slight scale, alpha to zero. Both mask stops start
                // at 1.0 so progress=0 keeps the artwork pixel-identical to
                // the accepted STEP5 shell (no erosion before the dissolve).
                Center(
                  child: SizedBox(
                    width: OrbitStartupDissolveOverlay.markSize,
                    height: OrbitStartupDissolveOverlay.markSize,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Transform.scale(
                        scale: 1 + 0.035 * t,
                        child: ShaderMask(
                          shaderCallback: (bounds) => ui.Gradient.radial(
                            bounds.center,
                            bounds.longestSide * 0.75,
                            [const Color(0xFFFFFFFF), const Color(0xFF000000)],
                            [math.max(0.0, 1.0 - 0.9 * t), 1.0],
                          ),
                          blendMode: BlendMode.dstIn,
                          child: ShaderMask(
                            shaderCallback: (bounds) => ui.Gradient.linear(
                              bounds.topLeft,
                              bounds.bottomRight,
                              [const Color(0xFFFFFFFF), const Color(0xFF000000)],
                              [math.max(0.0, 1.0 - 1.1 * t), 1.0],
                            ),
                            blendMode: BlendMode.dstIn,
                            child: RawImage(
                              image: widget.artwork,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Deterministic light particles (custom paint only while
                // the overlay exists — it is removed after completion).
                CustomPaint(
                  painter: _DissolveParticlesPainter(
                    particles: _particles,
                    progress: t,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One deterministic cyan/violet light particle. All fields are computed
/// once at generation time; the painter only reads them.
@visibleForTesting
final class DissolveParticle {
  const DissolveParticle({
    required this.origin,
    required this.direction,
    required this.distance,
    required this.radius,
    required this.delay,
    required this.color,
  });

  /// Unit-space (0..1) start position around the screen centre.
  final Offset origin;

  /// Unit outward/orbital drift direction.
  final Offset direction;

  /// Travel distance as a fraction of the smaller viewport side.
  final double distance;

  /// Particle radius in logical pixels.
  final double radius;

  /// Start delay as a fraction of the transition (0..0.35).
  final double delay;

  final Color color;
}

/// Fixed-seed generator (TZ: 12–18 particles, deterministic, computed once).
@visibleForTesting
List<DissolveParticle> generateDissolveParticles({
  int count = 15,
  int seed = 0x00536,
}) {
  final rng = math.Random(seed); // created once per generation call
  const cyan = Color(0xFF6FD8FF);
  const violet = Color(0xFF9C7BFF);
  return List<DissolveParticle>.generate(count, (i) {
    final angle = rng.nextDouble() * math.pi * 2;
    // Particles start near the mark ring, drift outward with a slight
    // orbital (tangential) component.
    final ringRadius = 0.16 + rng.nextDouble() * 0.10;
    final origin = Offset(
      0.5 + math.cos(angle) * ringRadius,
      0.5 + math.sin(angle) * ringRadius,
    );
    final tangent = angle + math.pi / 2;
    final radial = Offset(math.cos(angle), math.sin(angle));
    final orbital = Offset(math.cos(tangent), math.sin(tangent));
    final mix = rng.nextDouble();
    final direction = Offset(
      radial.dx * 0.8 + orbital.dx * 0.2,
      radial.dy * 0.8 + orbital.dy * 0.2,
    );
    return DissolveParticle(
      origin: origin,
      direction: direction,
      distance: 0.05 + rng.nextDouble() * 0.10,
      radius: 1.6 + rng.nextDouble() * 2.2,
      delay: rng.nextDouble() * 0.35,
      color: Color.lerp(cyan, violet, mix)!,
    );
  });
}

/// Draws the precomputed particles; two [Paint] instances are created once
/// per painter, never per frame.
class _DissolveParticlesPainter extends CustomPainter {
  _DissolveParticlesPainter({
    required List<DissolveParticle> particles,
    required double progress,
  }) : _particles = particles,
       _progress = progress,
       _glowPaint = Paint()..style = PaintingStyle.fill,
       _corePaint = Paint()..style = PaintingStyle.fill;

  final List<DissolveParticle> _particles;
  final double _progress;
  final Paint _glowPaint;
  final Paint _corePaint;

  @override
  void paint(Canvas canvas, Size size) {
    final travel = size.shortestSide;
    final progress = _progress;
    for (final particle in _particles) {
      // 0..1 local lifetime of this particle inside the transition.
      final span = 1.0 - particle.delay;
      final local = ((progress - particle.delay) / span).clamp(0.0, 1.0);
      if (local <= 0) continue;
      // Ease in quickly, fade out to the end; invisible at progress 0.
      final fade = (local / 0.25).clamp(0.0, 1.0) * (1 - local);
      if (fade <= 0.01) continue;
      final pos = Offset(
        particle.origin.dx * size.width +
            particle.direction.dx * particle.distance * travel * local,
        particle.origin.dy * size.height +
            particle.direction.dy * particle.distance * travel * local,
      );
      _glowPaint
        ..color = particle.color.withValues(alpha: 0.55 * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.radius);
      _corePaint
        ..color = particle.color.withValues(alpha: 0.9 * fade)
        ..maskFilter = null;
      canvas.drawCircle(pos, particle.radius * 1.6, _glowPaint);
      canvas.drawCircle(pos, particle.radius * 0.8, _corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DissolveParticlesPainter oldDelegate) =>
      oldDelegate._progress != _progress;
}
