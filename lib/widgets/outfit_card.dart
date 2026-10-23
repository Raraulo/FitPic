import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/garment.dart';
import '../models/outfit.dart';
import '../theme/app_theme.dart';

class OutfitCard extends StatelessWidget {
  const OutfitCard({
    super.key,
    required this.outfit,
    required this.index,
    required this.garments,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.compact = false,
  });

  final Outfit outfit;
  final int index;
  final List<Garment> garments;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final categorizedPaths = _getCategorizedPaths();
    final double pad = compact ? 5 : 8;

    return Hero(
      tag: 'outfit-${outfit.id}-$index',
      child: Material(
        color: AppTheme.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.darkBrown, width: 1.0),
              borderRadius: BorderRadius.zero,
            ),
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!compact)
                      Expanded(
                        child: Text(
                          outfit.style.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkBrown),
                        ),
                      )
                    else
                      const Spacer(),
                    InkWell(
                      onTap: onFavoriteToggle,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: compact ? 14 : 18,
                          color: isFavorite ? Colors.red : AppTheme.mediumBrown,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _OutfitImagePreview(paths: categorizedPaths),
                ),
                const SizedBox(height: 4),
                Text(
                  outfit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: compact ? 9.5 : 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: (80 * index).ms)
        .fadeIn(duration: 260.ms)
        .slideY(begin: .08, end: 0, curve: Curves.easeOutCubic);
  }

  _CategorizedPaths _getCategorizedPaths() {
    String? arriba;
    String? abrigo;
    String? abajo;
    String? accesorio;
    String? calzado;
    final fallbackList = <String>[];

    for (final item in outfit.items) {
      Garment? match;
      for (final garment in garments) {
        if (garment.id == item.id ||
            garment.name.toLowerCase().contains(item.name.toLowerCase()) ||
            item.name.toLowerCase().contains(garment.name.toLowerCase())) {
          match = garment;
          break;
        }
      }
      final path = match?.imagePath;
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        final cat = _normalizedText('${item.type ?? ''} ${match?.category ?? ''} ${item.name}');
        if (_isTop(cat)) {
          arriba ??= path;
        } else if (_isOuterwear(cat)) {
          abrigo ??= path;
        } else if (_isBottom(cat)) {
          abajo ??= path;
        } else if (_isAccessory(cat)) {
          accesorio ??= path;
        } else if (_isShoes(cat)) {
          calzado ??= path;
        } else {
          if (!fallbackList.contains(path)) fallbackList.add(path);
        }
      }
    }

    return _CategorizedPaths(
      arriba: arriba,
      abrigo: abrigo,
      abajo: abajo,
      accesorio: accesorio,
      calzado: calzado,
      fallback: fallbackList,
    );
  }
}

class _CategorizedPaths {
  const _CategorizedPaths({
    this.arriba,
    this.abrigo,
    this.abajo,
    this.accesorio,
    this.calzado,
    required this.fallback,
  });

  final String? arriba;
  final String? abrigo;
  final String? abajo;
  final String? accesorio;
  final String? calzado;
  final List<String> fallback;

  bool get isEmpty =>
      arriba == null &&
      abrigo == null &&
      abajo == null &&
      accesorio == null &&
      calzado == null &&
      fallback.isEmpty;
}

class _OutfitImagePreview extends StatelessWidget {
  const _OutfitImagePreview({required this.paths});

  final _CategorizedPaths paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return Container(
        color: AppTheme.line.withValues(alpha: .2),
        child: const Center(
          child: Icon(Icons.style_outlined, color: AppTheme.mediumBrown, size: 28),
        ),
      );
    }

    final String? topPath = paths.arriba;
    final String? bottomPath = paths.abajo;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        children: [
          Expanded(
            child: _buildTile(topPath),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _buildTile(bottomPath),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(String? path) {
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      return const SizedBox.shrink();
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(2),
      child: Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          cacheWidth: 300,
        ),
      ),
    );
  }
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
