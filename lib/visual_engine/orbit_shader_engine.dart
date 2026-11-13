import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Manages and caches GPU Fragment Shaders for optical glass and lighting.
final class OrbitShaderEngine {
  OrbitShaderEngine._();

  static final OrbitShaderEngine instance = OrbitShaderEngine._();

  /// Feature flag for optical glass fragment shader on card borders.
  /// Default is false to eliminate unwanted bright border outlines on cards.
  static bool enableOpticalGlassShader = false;

  ui.FragmentProgram? _glassProgram;
  bool _loadAttempted = false;
  bool _available = false;
  int _shaderPaintsCount = 0;

  bool get isAvailable => _available && _glassProgram != null;
  bool get isActivelyRendering => isAvailable && _shaderPaintsCount > 0;
  int get shaderPaintsCount => _shaderPaintsCount;

  void recordShaderPaint() {
    _shaderPaintsCount++;
  }

  /// Pre-loads shaders asynchronously during app startup.
  Future<void> initialize() async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    try {
      _glassProgram = await ui.FragmentProgram.fromAsset(
        'shaders/optical_glass.frag',
      );
      _available = true;
    } catch (e) {
      debugPrint('[ORBIT Shaders] Shader loading fell back to Canvas: $e');
      _available = false;
      _glassProgram = null;
    }
  }

  /// Creates a GPU fragment shader instance for optical glass reflections.
  /// If shaders are unavailable or in tests, returns null to trigger Canvas fallback.
  ui.Shader? createGlassShader({
    required Size size,
    required Offset lightPos,
    required Color borderColor,
    double fresnelIntensity = 1.0,
    double time = 0.0,
  }) {
    if (!_available || _glassProgram == null || size.isEmpty) return null;
    try {
      final shader = _glassProgram!.fragmentShader();
      // uniform vec2 uResolution;
      shader.setFloat(0, size.width);
      shader.setFloat(1, size.height);
      // uniform vec2 uLightPos;
      shader.setFloat(2, lightPos.dx);
      shader.setFloat(3, lightPos.dy);
      // uniform float uTime;
      shader.setFloat(4, time);
      // uniform float uFresnelIntensity;
      shader.setFloat(5, fresnelIntensity);
      // uniform vec4 uBorderColor;
      shader.setFloat(6, borderColor.r);
      shader.setFloat(7, borderColor.g);
      shader.setFloat(8, borderColor.b);
      shader.setFloat(9, borderColor.a);
      return shader;
    } catch (e) {
      return null;
    }
  }
}
