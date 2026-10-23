import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OutfitBoardItem {
  const OutfitBoardItem(
      {required this.id,
      required this.name,
      required this.imagePath,
      required this.role});

  final String id;
  final String name;
  final String imagePath;
  final String role;
  bool get isSmall => role == 'calzado' || role == 'accesorio';
}

/// A single outfit composition; source photos are always shown uncropped.
class OutfitBoard extends StatelessWidget {
  const OutfitBoard({super.key, required this.name, required this.items});

  final String name;
  final List<OutfitBoardItem> items;

  @override
  Widget build(BuildContext context) {
    final main =
        items.where((item) => !item.isSmall && item.role != 'abrigo').toList();
    final layers = items.where((item) => item.role == 'abrigo').toList();
    final details = items.where((item) => item.isSmall).toList();
    final left = main.isNotEmpty ? main : layers;
    final right = main.isNotEmpty ? layers : <OutfitBoardItem>[];

    return Container(
      key: const ValueKey('outfit-board'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E3DF)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.darkBrown.withValues(alpha: .035),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            const Expanded(
                child: Text('EL LOOK',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mediumBrown))),
            Text('${items.length} prendas',
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.mediumBrown)),
          ]),
        ),
        if (items.isEmpty)
          const Padding(
              padding: EdgeInsets.all(28),
              child:
                  Text('Las prendas de este outfit ya no están en el armario.'))
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: LayoutBuilder(builder: (context, constraints) {
              final side = (constraints.maxWidth - 16) / 2;
              final hasRight = right.isNotEmpty || details.isNotEmpty;
              if (!hasRight) {
                return Center(
                    child: Column(children: [
                  for (final item in left) _piece(context, item, side),
                ]));
              }
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                        child: Column(children: [
                      for (final item in left) _piece(context, item, side),
                    ])),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(children: [
                      for (final item in right) _piece(context, item, side),
                      for (final item in details)
                        _piece(context, item, side * .66),
                    ])),
                  ]);
            }),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0ECE9)))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.4,
                    color: AppTheme.darkBrown)),
            const SizedBox(height: 5),
            const Text('Tu armario, en una sola mirada.',
                style: TextStyle(fontSize: 12, color: AppTheme.mediumBrown)),
          ]),
        ),
      ]),
    );
  }

  Widget _piece(BuildContext context, OutfitBoardItem item, double side) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: 'Ver foto de ${item.name}',
        child: InkWell(
          onTap: () => _openPhoto(context, item),
          borderRadius: BorderRadius.circular(8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              key: ValueKey('board-photo-${item.id}'),
              width: side,
              height: side,
              child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _photo(item, cacheWidth: 640)),
            ),
            const SizedBox(height: 5),
            Text(item.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, height: 1.3, color: AppTheme.mediumBrown)),
          ]),
        ),
      ),
    );
  }

  Widget _photo(OutfitBoardItem item, {int? cacheWidth}) {
    if (item.imagePath.isEmpty)
      return const Icon(Icons.checkroom_outlined, color: AppTheme.mediumBrown);
    return Image.file(File(item.imagePath),
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined,
            color: AppTheme.mediumBrown));
  }

  void _openPhoto(BuildContext context, OutfitBoardItem item) {
    showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
              backgroundColor: Colors.white,
              child: SafeArea(
                  child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                    child: Row(children: [
                      Expanded(
                          child: Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ])),
                Expanded(
                    child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Center(child: _photo(item, cacheWidth: 1600)))),
              ])),
            ));
  }
}
