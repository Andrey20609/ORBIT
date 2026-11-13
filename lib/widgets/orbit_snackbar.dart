import 'dart:async';
import 'package:flutter/material.dart';

import '../visual_engine/orbit_palette.dart';

/// Показывает премиальный плавающий баннер ORBIT, который гарантированно
/// исчезает по таймеру и не зависает бесконечно при включенных сервисах доступности.
void showOrbitBanner(
  BuildContext context, {
  required OrbitPalette palette,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  // Очищаем предыдущие баннеры
  messenger.clearSnackBars();

  final controller = messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: duration,
      backgroundColor: palette.surface.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: palette.accent.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(
              label: actionLabel,
              textColor: palette.accent,
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onAction();
              },
            )
          : null,
    ),
  );

  // Принудительный страховочный таймер для закрытия в обход Android Accessibility
  Timer? safetyTimer;
  safetyTimer = Timer(duration + const Duration(milliseconds: 200), () {
    try {
      controller.close();
    } catch (_) {}
  });
  controller.closed.whenComplete(() {
    safetyTimer?.cancel();
  });
}
