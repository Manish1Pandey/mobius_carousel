import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobius_carousel_example/bird_palette.dart';

/// Encodes a [width]x[height] PNG by painting [paint] onto a canvas.
Future<Uint8List> _png(
  int width,
  int height,
  void Function(Canvas canvas, Size size) paint,
) async {
  final recorder = ui.PictureRecorder();
  final size = Size(width.toDouble(), height.toDouble());
  paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Hue distance in degrees, wrapping across 0/360.
double _hueDelta(Color a, Color b) {
  final ha = HSVColor.fromColor(a).hue;
  final hb = HSVColor.fromColor(b).hue;
  final raw = (ha - hb).abs();
  return raw > 180 ? 360 - raw : raw;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns the hue of a solid image', () async {
    final bytes = await _png(
      32,
      32,
      (canvas, size) => canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF1565C0), // blue
      ),
    );

    final color = await dominantColorOfBytes(bytes);

    expect(_hueDelta(color, const Color(0xFF1565C0)), lessThan(12));
  });

  test('ignores a large pale background in favour of a small vivid subject',
      () async {
    // 90% washed-out sky, 10% saturated scarlet: the "bird in a big frame"
    // case that a naive average-of-all-pixels gets wrong.
    final bytes = await _png(64, 64, (canvas, size) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFDCE8F2), // pale sky
      );
      canvas.drawRect(
        const Rect.fromLTWH(24, 24, 20, 20),
        Paint()..color = const Color(0xFFD32F2F), // scarlet plumage
      );
    });

    final color = await dominantColorOfBytes(bytes);

    expect(_hueDelta(color, const Color(0xFFD32F2F)), lessThan(15));
  });

  test('ignores black and white pixels', () async {
    final bytes = await _png(60, 60, (canvas, size) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 60, 20),
        Paint()..color = Colors.black,
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 40, 60, 12),
        Paint()..color = const Color(0xFF2E7D32), // green
      );
    });

    final color = await dominantColorOfBytes(bytes);

    expect(_hueDelta(color, const Color(0xFF2E7D32)), lessThan(15));
  });

  test('separates adjacent hues: orange stays orange, not red', () async {
    final bytes = await _png(
      32,
      32,
      (canvas, size) => canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFF57C00), // orange
      ),
    );

    final color = await dominantColorOfBytes(bytes);
    final hue = HSVColor.fromColor(color).hue;

    expect(hue, greaterThan(20));
    expect(hue, lessThan(45));
  });

  test('falls back when the image has no colourful pixels', () async {
    final bytes = await _png(
      16,
      16,
      (canvas, size) => canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF9E9E9E), // pure grey
      ),
    );

    const fallback = Color(0xFF123456);
    final color = await dominantColorOfBytes(bytes, fallback: fallback);

    expect(color, fallback);
  });

  test('lifts a pale subject to a usable saturation', () async {
    final bytes = await _png(
      32,
      32,
      (canvas, size) => canvas.drawRect(
        Offset.zero & size,
        // Flamingo pink, but light: still has to read as pink on a light
        // background once it tints the ripple.
        Paint()..color = const Color(0xFFF2B8CB),
      ),
    );

    final color = await dominantColorOfBytes(bytes);
    final hsv = HSVColor.fromColor(color);

    expect(hsv.saturation, greaterThanOrEqualTo(0.55));
    expect(_hueDelta(color, const Color(0xFFF2B8CB)), lessThan(15));
  });
}
