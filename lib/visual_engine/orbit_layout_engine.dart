import 'package:flutter/widgets.dart';

import 'appearance_settings.dart';

final class OrbitLayoutEngine {
  const OrbitLayoutEngine._();

  static double maxContentWidth(double width) {
    if (width >= 1200) return 1120;
    if (width >= 840) return 760;
    return width;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return EdgeInsets.symmetric(horizontal: width >= 840 ? 32 : 18);
  }

  static double gap(BuildContext context, AppearanceSettings settings) {
    final compact = settings.density == OrbitDensity.compact;
    return compact ? 8 : 12;
  }

  static bool useNavigationRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 840;

  static Widget centered(BuildContext context, Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxContentWidth(MediaQuery.sizeOf(context).width),
        ),
        child: child,
      ),
    );
  }
}
