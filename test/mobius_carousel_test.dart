import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobius_carousel/mobius_carousel.dart';

void main() {
  testWidgets('renders the provider and bill amount of the centered item',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: MobiusCarousel(
          initialIndex: 0,
          autoPlayInterval: null,
          items: [
            MobiusItem(
              code: 'X',
              provider: 'Acme',
              billAmount: r'$1',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text(r'$1'), findsOneWidget);
  });

  testWidgets('renders an empty list without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MobiusCarousel(items: [], autoPlayInterval: null),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not duplicate the only card when items.length == 1',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: MobiusCarousel(
          initialIndex: 0,
          autoPlayInterval: null,
          items: [
            MobiusItem(provider: 'Solo', billAmount: r'$1'),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Solo'), findsOneWidget);
  });
}
