import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Extracts the dominant, *vivid* colour of an image asset.
///
/// The carousel tints its ripple with the focused card's colour, so the
/// colour taken from a bird photo has to be the bird — not the sky behind
/// it and not the shadow under it. A plain "most frequent pixel" average
/// returns mud for exactly that reason: backgrounds usually win on count.
///
/// The algorithm therefore:
/// 1. decodes the image at a small size (sampling, not fidelity, is the
///    goal — a 64px-wide decode is ~40x less work than the full frame);
/// 2. discards pixels that are transparent, nearly black, nearly white or
///    washed out, since those carry no usable hue;
/// 3. buckets what survives by hue, weighting each pixel by how saturated
///    and how bright it is, so a small patch of vivid plumage outweighs a
///    large wash of pale sky;
/// 4. averages the winning bucket and lifts the result to a usable
///    saturation so the ripple reads clearly against a light background.
///
/// Returns [fallback] when the image has no colourful pixels at all (a
/// greyscale photo, for instance).
Future<Color> dominantColorOfAsset(
  String assetKey, {
  Color fallback = const Color(0xFFE91E63),
  AssetBundle? bundle,
}) async {
  final data = await (bundle ?? rootBundle).load(assetKey);
  return dominantColorOfBytes(data.buffer.asUint8List(), fallback: fallback);
}

/// Same as [dominantColorOfAsset] but for already-loaded encoded image
/// [bytes] (PNG, JPEG, …). Exposed separately so it can be tested without
/// an asset bundle.
Future<Color> dominantColorOfBytes(
  Uint8List bytes, {
  Color fallback = const Color(0xFFE91E63),
}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) return fallback;
    return _dominantColorOfRgba(rgba.buffer.asUint8List(), fallback: fallback);
  } finally {
    image.dispose();
    codec.dispose();
  }
}

/// Number of hue buckets. 30 gives 12° per bucket: wide enough that one
/// bird's plumage lands in a single bucket, narrow enough to keep red and
/// orange apart.
const int _hueBuckets = 30;

Color _dominantColorOfRgba(Uint8List pixels, {required Color fallback}) {
  final weights = List<double>.filled(_hueBuckets, 0);
  final sumR = List<double>.filled(_hueBuckets, 0);
  final sumG = List<double>.filled(_hueBuckets, 0);
  final sumB = List<double>.filled(_hueBuckets, 0);

  for (var i = 0; i + 3 < pixels.length; i += 4) {
    final a = pixels[i + 3];
    if (a < 128) continue; // transparent

    final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
    final hsv = HSVColor.fromColor(Color.fromARGB(255, r, g, b));

    // Skip pixels that cannot describe a hue: near-black, near-white and
    // washed-out greys (sky haze, paper backgrounds, shadow).
    if (hsv.value < 0.18 || hsv.value > 0.97) continue;
    if (hsv.saturation < 0.28) continue;

    // Vivid pixels count for more than pale ones.
    final weight = hsv.saturation * hsv.saturation * hsv.value;
    final bucket = ((hsv.hue / 360.0) * _hueBuckets).floor() % _hueBuckets;

    weights[bucket] += weight;
    sumR[bucket] += r * weight;
    sumG[bucket] += g * weight;
    sumB[bucket] += b * weight;
  }

  var best = -1;
  var bestWeight = 0.0;
  for (var i = 0; i < _hueBuckets; i++) {
    // Fold in the neighbouring buckets so a hue sitting exactly on a
    // boundary is not split in half and beaten by a lesser colour.
    final left = weights[(i - 1 + _hueBuckets) % _hueBuckets];
    final right = weights[(i + 1) % _hueBuckets];
    final score = weights[i] + (left + right) * 0.5;
    if (weights[i] > 0 && score > bestWeight) {
      bestWeight = score;
      best = i;
    }
  }
  if (best < 0) return fallback;

  final w = weights[best];
  final average = Color.fromARGB(
    255,
    (sumR[best] / w).round().clamp(0, 255),
    (sumG[best] / w).round().clamp(0, 255),
    (sumB[best] / w).round().clamp(0, 255),
  );

  // Lift pale results so the ripple stays visible on a light background,
  // without touching colours that are already vivid.
  final hsv = HSVColor.fromColor(average);
  return hsv
      .withSaturation(hsv.saturation.clamp(0.55, 1.0))
      .withValue(hsv.value.clamp(0.45, 0.92))
      .toColor();
}
