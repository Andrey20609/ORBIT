import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'appearance_settings.dart';

final class OrbitMotionEngine {
  const OrbitMotionEngine._();

  static Duration duration(
    AppearanceSettings settings, {
    Duration normal = const Duration(milliseconds: 360),
  }) {
    return settings.motionEnabled ? normal : Duration.zero;
  }

  static const curve = Cubic(0.22, 1, 0.36, 1);

  static PageRouteBuilder<T> transition<T>({
    required Widget page,
    required AppearanceSettings settings,
  }) {
    return PageRouteBuilder<T>(
      transitionDuration: duration(settings),
      reverseTransitionDuration: duration(
        settings,
        normal: const Duration(milliseconds: 240),
      ),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, secondary, child) {
        final curved = CurvedAnimation(parent: animation, curve: curve);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0.018),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

final class OrbitPressable extends StatefulWidget {
  const OrbitPressable({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<OrbitPressable> createState() => _OrbitPressableState();
}

final class _OrbitPressableState extends State<OrbitPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    if (value) HapticFeedback.selectionClick();
  }

  @override
  void didUpdateWidget(covariant OrbitPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pressed) {
      _pressed = false;
    }
  }

  @override
  void deactivate() {
    _pressed = false;
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 140),
          curve: OrbitMotionEngine.curve,
          child: widget.child,
        ),
      ),
    );
  }
}

final class OrbitReveal extends StatelessWidget {
  const OrbitReveal({required this.child, this.index = 0, super.key});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 55).clamp(0, 330)),
      curve: OrbitMotionEngine.curve,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
