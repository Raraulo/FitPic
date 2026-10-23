import 'package:fitpic/models/garment.dart';
import 'package:fitpic/widgets/garment_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Garment> clothes(int count) => List.generate(
    count,
    (i) => Garment(
          id: '$i',
          name: 'Prenda $i',
          category: 'Camisa',
          color: 'Negro',
          material: '',
          season: '',
          imagePath: '',
        ));

void main() {
  testWidgets(
      'every item remains reachable after parent rebuilds while scrolling',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 400,
      child: StatefulBuilder(
          builder: (context, setState) => GarmentRail(
                title: 'Arriba',
                garments: clothes(3),
                selectedId: selected,
                compact: false,
                onSelected: (g) => setState(() => selected = g.id),
              )),
    ))));
    final rail = find.byType(PageView);
    expect(tester.widget<PageView>(rail).controller!.page, 0);
    await tester.drag(rail, const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(selected, '1');
    await tester.drag(rail, const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(selected, '2');
    await tester.drag(rail, const Offset(640, 0));
    await tester.pumpAndSettle();
    expect(selected, '0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('external AI selection moves to the right garment',
      (tester) async {
    Future<void> show(String id) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SizedBox(
          width: 400,
          child: GarmentRail(
              title: 'Arriba',
              garments: clothes(5),
              selectedId: id,
              compact: false,
              onSelected: (_) {}),
        ))));
    await show('0');
    await show('3');
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 3);
  });

  testWidgets(
      'shoes and accessories use smaller squares and vertical scrolling works over a rail',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 400,
      child: ListView(children: [
        GarmentRail(
            title: 'Arriba',
            garments: clothes(3),
            selectedId: null,
            compact: false,
            onSelected: (_) {}),
        GarmentRail(
            title: 'Calzado',
            garments: clothes(3),
            selectedId: null,
            compact: true,
            onSelected: (_) {}),
        const SizedBox(height: 600),
        const Text('Fin'),
      ]),
    ))));
    final large =
        tester.getSize(find.byKey(const ValueKey('rail-Arriba'))).height;
    final small =
        tester.getSize(find.byKey(const ValueKey('rail-Calzado'))).height;
    expect(small, lessThan(large * .7));
    await tester.drag(
        find.byKey(const ValueKey('rail-Arriba')), const Offset(0, -300));
    await tester.pumpAndSettle();
    final vertical =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(vertical.pixels, greaterThan(100));
    expect(tester.takeException(), isNull);
  });
}
