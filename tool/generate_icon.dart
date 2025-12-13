import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

// Simple script to generate app icon with wallet design
// Run: dart run tool/generate_icon.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🎨 Generating SpendPal app icon...');

  // Create a 1024x1024 icon (required for app stores)
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = const Size(1024, 1024);

  // Background - Teal gradient
  final gradient = ui.Gradient.linear(
    const Offset(0, 0),
    const Offset(1024, 1024),
    [
      const Color(0xFF26A69A), // Teal accent
      const Color(0xFF00897B), // Darker teal
    ],
  );

  final paint = Paint()..shader = gradient;
  canvas.drawRect(Offset.zero & size, paint);

  // Draw wallet icon in white
  final iconPainter = TextPainter(
    text: const TextSpan(
      text: '💰', // Wallet emoji as fallback
      style: TextStyle(
        fontSize: 512,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  iconPainter.layout();
  iconPainter.paint(
    canvas,
    Offset(
      (1024 - iconPainter.width) / 2,
      (1024 - iconPainter.height) / 2,
    ),
  );

  // Convert to image
  final picture = recorder.endRecording();
  final image = await picture.toImage(1024, 1024);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();

  // Save to assets folder
  final assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    assetsDir.createSync();
  }

  final file = File('assets/app_icon.png');
  await file.writeAsBytes(buffer);

  print('✅ Icon generated: assets/app_icon.png');
  print('💡 Next step: Run "flutter pub run flutter_launcher_icons"');
}
