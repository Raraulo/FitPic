import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitpic/widgets/outfit_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const pieces = [
  OutfitBoardItem(id: 'top', name: 'Polo negro', imagePath: '', role: 'arriba'),
  OutfitBoardItem(id: 'bottom', name: 'Pantalón', imagePath: '', role: 'abajo'),
  OutfitBoardItem(id: 'coat', name: 'Saco', imagePath: '', role: 'abrigo'),
  OutfitBoardItem(
      id: 'shoes', name: 'Zapatillas', imagePath: '', role: 'calzado'),
  OutfitBoardItem(
      id: 'accessory', name: 'Accesorio', imagePath: '', role: 'accesorio'),
];

void main() {
  testWidgets(
      'main pieces have equal size and accessories stay smaller on narrow screens',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: Padding(
          padding: EdgeInsets.all(16),
          child: OutfitBoard(name: 'Mi look', items: pieces)),
    ))));
    Size size(String id) =>
        tester.getSize(find.byKey(ValueKey('board-photo-$id')));
    expect(size('top'), size('bottom'));
    expect(size('top'), size('coat'));
    expect(size('shoes').width, lessThan(size('top').width * .7));
    expect(size('shoes'), size('accessory'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('board-photo-top')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets(
      'a one-piece outfit and missing garments have no empty image slots',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: OutfitBoard(name: 'Vestido', items: [
      OutfitBoardItem(
          id: 'dress', name: 'Vestido', imagePath: '', role: 'mono'),
    ]))));
    expect(find.byKey(const ValueKey('board-photo-dress')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: OutfitBoard(name: 'Mi look', items: []))));
    expect(find.textContaining('ya no están'), findsOneWidget);
  });

  testWidgets('render sample outfit board', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final assets = [
      'camisa.png',
      'pantalon.png',
      'saco.png',
      'zapatos.png',
      'accesorio.png'
    ];
    final demo = List.generate(
        pieces.length,
        (i) => OutfitBoardItem(
              id: pieces[i].id,
              name: pieces[i].name,
              role: pieces[i].role,
              imagePath: 'assets/ropa/${assets[i]}',
            ));
    await tester.runAsync(() async {
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        final loader = FontLoader('PreviewSans')
          ..addFont(
              font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
        await loader.load();
      }
    });
    final boundary = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'PreviewSans'),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F5F2),
            appBar: AppBar(
                title: const Text('Tu outfit'),
                backgroundColor: const Color(0xFFF7F5F2)),
            body: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutfitBoard(
                        name: 'Esenciales de ciudad', items: demo))),
          ),
        )));
    final pending = demo.map((item) => precacheImage(
      ResizeImage(FileImage(File(item.imagePath)), width: 640), boundary.currentContext!,
    )).toList();
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      if (PaintingBinding.instance.imageCache.pendingImageCount == 0) break;
    }
    await tester.runAsync(() => Future.wait(pending).timeout(const Duration(seconds: 3)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/verification')
        ..createSync(recursive: true);
      await File('${directory.path}/outfit-board.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }, skip: Platform.environment['FITPIC_RENDER_PREVIEW'] != '1');
}
