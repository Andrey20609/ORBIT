// Standalone evidence generator for the STEP5-rework review kit. NOT part of
// the default test suite: run explicitly with
//   ORBIT_EVIDENCE_OUT=<abs path>.png flutter test tool/shell_evidence_test.dart
// The regular suite (test/) performs the same pixel assertions hermetically
// and writes nothing to disk; this tool only renders the approved artwork
// through the production decode path and saves the captured frame to the
// explicitly configured output path (directories are created as needed).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/orbit_bootstrap.dart';

const _backgroundSample = <int>[0x16, 0x18, 0x2C]; // #16182C

/// Minimal PNG encoder: truecolour RGB, one filter byte per scanline.
List<int> _encodePng(int width, int height, Uint8List rgba) {
  final raw = <int>[];
  for (var y = 0; y < height; y++) {
    raw.add(0); // filter type none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw.addAll([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  List<int> chunk(String type, List<int> body) {
    final len = body.length;
    final out = <int>[
      (len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF,
    ];
    final typeBytes = type.codeUnits;
    out.addAll(typeBytes);
    out.addAll(body);
    var crc = 0xFFFFFFFF;
    for (final b in [...typeBytes, ...body]) {
      crc ^= b;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
      }
    }
    crc ^= 0xFFFFFFFF;
    out.addAll([
      (crc >> 24) & 0xFF, (crc >> 16) & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF,
    ]);
    return out;
  }

  final ihdr = <int>[
    (width >> 24) & 0xFF, (width >> 16) & 0xFF, (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF, (height >> 16) & 0xFF, (height >> 8) & 0xFF,
    height & 0xFF,
    8, 2, 0, 0, 0, // bit depth 8, colour type 2 (RGB)
  ];
  final zlibData = ZLibEncoder(raw: false).convert(raw);
  final out = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  out.addAll(chunk('IHDR', ihdr));
  out.addAll(chunk('IDAT', zlibData));
  out.addAll(chunk('IEND', const []));
  return out;
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture the startup shell first frame with the actual '
      'artwork (pixel-asserted, explicit output path)', (tester) async {
    final artwork = await tester.runAsync(() => decodeBrandingArtworkAsset());
    expect(artwork, isNotNull);
    await tester.pumpWidget(OrbitStartupShell(artwork: artwork));
    await tester.pump();

    // Same pixel assertion as the hermetic suite: the frame must carry the
    // actual artwork, not an empty background.
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('orbit-startup-shell-mark')),
    );
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final pixels = bytes.buffer.asUint8List();
    var nonBackground = 0;
    for (var i = 0; i < pixels.length; i += 4) {
      final distance = (pixels[i] - _backgroundSample[0]).abs() +
          (pixels[i + 1] - _backgroundSample[1]).abs() +
          (pixels[i + 2] - _backgroundSample[2]).abs();
      if (distance > 40) nonBackground++;
    }
    final total = pixels.length ~/ 4;
    expect(nonBackground, greaterThan(total * 0.3),
        reason: 'the captured frame must show the approved artwork');

    final outPath = Platform.environment['ORBIT_EVIDENCE_OUT'];
    expect(outPath, isNotNull,
        reason: 'set ORBIT_EVIDENCE_OUT=<abs path>.png for this tool');
    final file = File(outPath!);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(
      _encodePng(image.width, image.height, pixels),
    );
    expect(file.existsSync(), isTrue);
    // ignore: avoid_print
    print('EVIDENCE_WRITTEN: ${file.path} (${file.lengthSync()} bytes, '
        '${image.width}x${image.height})');
  });
}
