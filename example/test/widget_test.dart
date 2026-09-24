import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobius_carousel_example/bird_palette.dart';
import 'package:mobius_carousel_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cards show bird photos', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName)
        .toSet();

    expect(images, contains('assets/birds/red_and_green_macaw.jpg'));
    expect(
      images.every((name) => name.startsWith('assets/birds/')),
      isTrue,
      reason: 'every card image should be a bird photo',
    );
  });

  testWidgets('offer details stay in the tree but are hidden', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    // Built, so flipping one flag brings them back...
    final code = find.text('MACAW20');
    expect(code, findsOneWidget);

    // ...but not painted, and not shrinking the layout while hidden.
    final visibility = tester.widget<Visibility>(
      find.ancestor(of: code, matching: find.byType(Visibility)).first,
    );
    expect(visibility.visible, isFalse);
    expect(visibility.maintainSize, isTrue);
    expect(visibility.maintainState, isTrue);

    expect(tester.getSize(code).isEmpty, isFalse);
  });

  group('accent colour comes from the photo itself', () {
    // Ranges, not exact values: the extractor samples a downscaled decode,
    // so a pixel or two either way must not break the build. What matters
    // is that each bird lands in its own colour family and that no two
    // cards end up tinting the ripple the same way.
    const expected = <String, (double, double)>{
      'red_and_green_macaw': (345, 370), // scarlet (wraps past 360)
      'chilean_flamingo': (5, 30), // coral pink
      'sun_conure': (20, 42), // orange
      'yellow_warbler': (40, 62), // yellow
      'yellow_collared_lovebird': (80, 140), // green
      'indian_peacock': (200, 250), // blue
    };

    // A plain `test`, not `testWidgets`: image decoding is real async work
    // and never completes inside the faked clock of a widget test.
    test('each photo yields its own hue family', () async {
      final hues = <String, double>{};

      for (final entry in expected.entries) {
        final color =
            await dominantColorOfAsset('assets/birds/${entry.key}.jpg');
        var hue = HSVColor.fromColor(color).hue;
        if (entry.value.$1 > 180 && hue < 90) hue += 360; // wrap for red
        hues[entry.key] = hue;

        expect(
          hue,
          inInclusiveRange(entry.value.$1, entry.value.$2),
          reason: '${entry.key} extracted hue $hue',
        );
        expect(
          HSVColor.fromColor(color).saturation,
          greaterThanOrEqualTo(0.55),
          reason: '${entry.key} must tint the ripple visibly',
        );
      }

      // No two birds may collapse onto the same accent.
      final sorted = hues.values.toList()..sort();
      for (var i = 1; i < sorted.length; i++) {
        expect(
          sorted[i] - sorted[i - 1],
          greaterThan(8),
          reason: 'accents too close: $hues',
        );
      }
    });
  });
}
