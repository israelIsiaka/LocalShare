/// Run this script once to generate the app icon PNG used by flutter_launcher_icons.
///
/// Usage:
///   flutter pub get
///   dart run scripts/generate_icon.dart
///   dart run flutter_launcher_icons
///
/// The script renders a 1024×1024 blue rounded-square with the LocalShare
/// swap-arrows symbol and writes it to assets/icon/app_icon.png.
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<void> main() async {
  // Bootstrap the Flutter binding so we can use Canvas / Picture.
  WidgetsFlutterBinding.ensureInitialized();

  const int size = 1024;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

  // ── Background: solid blue square (no rounding needed — launcher icons tool handles masking)
  final bgPaint = Paint()..color = const Color(0xFF1565C0);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    bgPaint,
  );

  // ── Draw two horizontal arrows (⇄) using paths
  final arrowPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  final double cx = size / 2;
  final double cy = size / 2;
  final double arrowW = size * 0.52;   // total arrow length
  final double headH = size * 0.10;    // arrowhead height
  final double headW = size * 0.10;    // arrowhead width
  final double shaftH = size * 0.055; // shaft thickness
  final double gap   = size * 0.09;   // gap between the two arrows

  // Top arrow: points right  ──►
  _drawArrow(canvas, arrowPaint,
    cx: cx, cy: cy - gap,
    width: arrowW, shaftH: shaftH, headH: headH, headW: headW,
    pointsRight: true,
  );

  // Bottom arrow: points left  ◄──
  _drawArrow(canvas, arrowPaint,
    cx: cx, cy: cy + gap,
    width: arrowW, shaftH: shaftH, headH: headH, headW: headW,
    pointsRight: false,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    stderr.writeln('Failed to encode PNG');
    exit(1);
  }

  final outFile = File('assets/icon/app_icon.png');
  await outFile.writeAsBytes(byteData.buffer.asUint8List());
  stdout.writeln('Icon written to ${outFile.path}');
}

void _drawArrow(
  Canvas canvas,
  Paint paint, {
  required double cx,
  required double cy,
  required double width,
  required double shaftH,
  required double headH,
  required double headW,
  required bool pointsRight,
}) {
  final double left  = cx - width / 2;
  final double right = cx + width / 2;
  final double shaftTop    = cy - shaftH / 2;
  final double shaftBottom = cy + shaftH / 2;

  final path = Path();

  if (pointsRight) {
    // Shaft from left to (right - headW)
    path.addRect(Rect.fromLTRB(left, shaftTop, right - headW, shaftBottom));
    // Arrowhead triangle pointing right
    path.moveTo(right - headW, cy - headH / 2);
    path.lineTo(right,         cy);
    path.lineTo(right - headW, cy + headH / 2);
    path.close();
  } else {
    // Shaft from (left + headW) to right
    path.addRect(Rect.fromLTRB(left + headW, shaftTop, right, shaftBottom));
    // Arrowhead triangle pointing left
    path.moveTo(left + headW, cy - headH / 2);
    path.lineTo(left,         cy);
    path.lineTo(left + headW, cy + headH / 2);
    path.close();
  }

  canvas.drawPath(path, paint);
}
