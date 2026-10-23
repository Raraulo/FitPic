import 'dart:io';

import 'package:flutter/material.dart';

import '../models/garment.dart';
import '../models/outfit.dart';
import '../theme/app_theme.dart';
import '../widgets/outfit_board.dart';

class OutfitDetailScreen extends StatelessWidget {
  const OutfitDetailScreen({
    super.key,
    required this.outfit,
    required this.garments,
    required this.heroTag,
  });

  final Outfit outfit;
  final List<Garment> garments;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final sortedItems = _getSortedItems();
    final whyItWorks = outfit.whyItWorks.trim().isEmpty
        ? _fallbackWhyItWorks()
        : outfit.whyItWorks;
    final tip = outfit.tip.trim().isEmpty ? _fallbackTip() : outfit.tip;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
          title: const Text('Tu outfit'),
          backgroundColor: const Color(0xFFF7F5F2)),
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          OutfitBoard(name: outfit.name, items: _buildBoardItems()),
          const SizedBox(height: 20),
          _InfoCard(
              icon: Icons.auto_awesome_outlined,
              title: 'LA COMBINACION',
              body: whyItWorks),
          _InfoCard(
              icon: Icons.lightbulb_outline,
              title: 'EL TOQUE FINAL',
              body: tip),
          if (outfit.accessories.isNotEmpty)
            _InfoCard(
                icon: Icons.watch_outlined,
                title: 'COMPLEMENTOS',
                body: outfit.accessories),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Prendas y detalles',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: Text('${sortedItems.length} piezas de tu armario'),
              children: [
                for (final item in sortedItems) _buildItemTile(context, item)
              ],
            ),
          ),
        ],
      )),
    );
  }

  int _getItemPriority(OutfitItem item) {
    final garment = _findGarment(item);
    final cat = _normalizedText(
        '${item.type ?? ''} ${garment?.category ?? ''} ${item.name}');
    if (cat.contains('arriba') || cat.contains('camisa') || cat.contains('top'))
      return 1;
    if (cat.contains('abrigo') ||
        cat.contains('saco') ||
        cat.contains('chaqueta') ||
        cat.contains('chompa')) return 2;
    if (cat.contains('abajo') || cat.contains('pant') || cat.contains('jean'))
      return 3;
    if (cat.contains('accesorio') ||
        cat.contains('gorra') ||
        cat.contains('reloj')) return 4;
    if (cat.contains('calzado') ||
        cat.contains('zapato') ||
        cat.contains('bot')) return 5;
    return 6;
  }

  List<OutfitItem> _getSortedItems() {
    final list = List<OutfitItem>.from(outfit.items);
    list.sort((a, b) => _getItemPriority(a).compareTo(_getItemPriority(b)));
    return list;
  }

  Widget _buildItemTile(BuildContext context, OutfitItem item) {
    final garment = _findGarment(item);
    final imagePath = garment?.imagePath ?? '';
    final hasImage = imagePath.isNotEmpty;

    String typeLabel =
        (item.type ?? garment?.category ?? 'PRENDA').toUpperCase();
    if (typeLabel.contains('ARRIBA') || typeLabel.contains('CAMISA'))
      typeLabel = 'PRENDA DE ARRIBA';
    if (typeLabel.contains('ABAJO') || typeLabel.contains('PANTAL'))
      typeLabel = 'PRENDA DE ABAJO';
    if (typeLabel.contains('CALZADO') ||
        typeLabel.contains('TENIS') ||
        typeLabel.contains('ZAPAT')) typeLabel = 'CALZADO';
    if (typeLabel.contains('ABRIGO') ||
        typeLabel.contains('SACO') ||
        typeLabel.contains('CHAQUETA')) typeLabel = 'ABRIGO / SACO';
    if (typeLabel.contains('ACCESORIO') || typeLabel.contains('GORRA'))
      typeLabel = 'ACCESORIO';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garment Centered Contain Square Image
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.zero,
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                      cacheWidth: 240,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  )
                : const Center(child: Icon(Icons.checkroom_outlined, size: 32)),
          ),
          const SizedBox(width: 12),

          // Garment Info & How to Wear
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0ECE9),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    typeLabel,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkBrown,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.name.isNotEmpty
                      ? item.name
                      : garment?.name ?? 'Prenda del armario',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  item.howToWear.isNotEmpty
                      ? item.howToWear
                      : 'Úsala con estilo entallado y combinación armoniosa.',
                  style: const TextStyle(
                      fontSize: 12, height: 1.25, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Garment? _findGarment(OutfitItem item) {
    for (final g in garments) {
      if (g.id == item.id) return g;
    }
    if (item.name.trim().isEmpty) return null;
    for (final g in garments) {
      if (g.name.toLowerCase().contains(item.name.toLowerCase()) ||
          item.name.toLowerCase().contains(g.name.toLowerCase())) {
        return g;
      }
    }
    return null;
  }

  List<OutfitBoardItem> _buildBoardItems() {
    final usedIds = <String>{};
    final result = <OutfitBoardItem>[];
    for (final item in _getSortedItems()) {
      final garment = _findGarment(item);
      if (garment == null || !usedIds.add(garment.id)) continue;
      result.add(OutfitBoardItem(
          id: garment.id,
          name: garment.name,
          imagePath: garment.imagePath,
          role: _slotFor(item, garment) ?? 'arriba'));
    }
    return result;
  }

  String? _slotFor(OutfitItem item, Garment garment) {
    final cat = _normalizedText(
        '${item.type ?? ''} ${garment.category} ${item.name} ${garment.name}');
    if (cat.contains('mono') ||
        cat.contains('vestido') ||
        cat.contains('enterizo')) return 'mono';
    if (_isOuterwear(cat)) return 'abrigo';
    if (_isAccessory(cat)) return 'accesorio';
    if (_isShoes(cat)) return 'calzado';
    if (_isBottom(cat)) return 'abajo';
    if (_isTop(cat)) return 'arriba';
    return null;
  }

  bool _isTop(String text) {
    return text.contains('arriba') ||
        text.contains('camisa') ||
        text.contains('camiseta') ||
        text.contains('top') ||
        text.contains('blusa') ||
        text.contains('polo');
  }

  bool _isOuterwear(String text) {
    return text.contains('abrigo') ||
        text.contains('saco') ||
        text.contains('chaqueta') ||
        text.contains('chompa') ||
        text.contains('sueter') ||
        text.contains('sweater') ||
        text.contains('chamarra') ||
        text.contains('casaca');
  }

  bool _isBottom(String text) {
    if (_isOuterwear(text) || _isShoes(text)) return false;
    return text.contains('abajo') ||
        text.contains('pantalon') ||
        text.contains('jean') ||
        text.contains('vaquero') ||
        text.contains('falda') ||
        text.contains('short');
  }

  bool _isShoes(String text) {
    return text.contains('calzado') ||
        text.contains('zapato') ||
        text.contains('zapatilla') ||
        text.contains('bota') ||
        text.contains('tenis');
  }

  bool _isAccessory(String text) {
    return text.contains('accesorio') ||
        text.contains('gorra') ||
        text.contains('reloj') ||
        text.contains('cintur') ||
        text.contains('lente') ||
        text.contains('gafa');
  }

  String _normalizedText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  String _fallbackWhyItWorks() {
    final names = outfit.items
        .map((item) => item.name)
        .where((name) => name.trim().isNotEmpty)
        .take(4)
        .join(', ');
    if (names.isEmpty) {
      return 'Funciona porque mantiene una estructura equilibrada entre parte superior, base, calzado y accesorios.';
    }
    return 'Funciona porque combina $names con una lectura visual ordenada: una pieza principal, una base clara y calzado que cierra el conjunto.';
  }

  String _fallbackTip() {
    final hasCoat = outfit.items.any((item) {
      final text = '${item.type ?? ''} ${item.name}'.toLowerCase();
      return text.contains('abrigo') ||
          text.contains('saco') ||
          text.contains('chaqueta');
    });
    if (hasCoat) {
      return 'Usa el abrigo como capa exterior y procura que la prenda de arriba quede visible para dar profundidad al look.';
    }
    return 'Ajusta proporciones: si la parte superior es amplia, usa una base mas limpia; si es entallada, puedes permitir mas volumen abajo.';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.darkBrown),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.darkBrown,
                ),
              )),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
                fontSize: 13, height: 1.3, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
