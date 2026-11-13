import 'package:flutter/material.dart';

import 'data/orbit_local_state_repository.dart';
import 'orbit_bootstrap.dart';
import 'state/app_state.dart';
import 'visual_engine/orbit_visual_engine.dart';

void main() {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[ORBIT FlutterError] ${details.exceptionAsString()}');
  };
  final style = OrbitStyleManager(SharedPreferencesAppearanceRepository());
  final quality = OrbitQualityManager();
  final appState = OrbitAppState(SharedPreferencesLocalStateRepository());
  debugPrint('[ORBIT startup] running branded shell');
  runApp(
    OrbitBootstrap(
      startup: startup,
      style: style,
      quality: quality,
      appState: appState,
    ),
  );
}
