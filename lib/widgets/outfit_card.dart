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
  });

  final Outfit outfit;
  final int index;
  final List<Garment> garments;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final imagePaths = _imagePathsForOutfit();

    return Hero(
      tag: 'outfit-${outfit.id}-$index',
      child: Material(
        color: AppTheme.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.darkBrown, width: 0.8),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        outfit.style.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.darkBrown),
                      ),
                    ),
                    InkWell(
                      onTap: onFavoriteToggle,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFavorite ? Colors.red : AppTheme.mediumBrown,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _OutfitImagePreview(imagePaths: imagePaths),
                ),
                const SizedBox(height: 4),
                Text(
                  outfit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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

  List<String> _imagePathsForOutfit() {
    final paths = <String>[];
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
      if (path != null && path.isNotEmpty && File(path).existsSync() && !paths.contains(path)) {
        paths.add(path);
      }
    }
    return paths;
  }
}

class _OutfitImagePreview extends StatelessWidget {
  const _OutfitImagePreview({required this.imagePaths});

  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return Container(
        color: AppTheme.line.withValues(alpha: .2),
        child: const Center(
          child: Icon(Icons.style_outlined, color: AppTheme.mediumBrown, size: 28),
        ),
      );
    }

    return Container(
      color: Colors.grey.shade50,
      alignment: Alignment.center,
      child: imagePaths.length == 1
          ? Image.file(File(imagePaths[0]), fit: BoxFit.contain)
          : GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: imagePaths.take(4).length,
              itemBuilder: (context, index) {
                return Container(
                  color: Colors.white,
                  child: Image.file(
                    File(imagePaths[index]),
                    fit: BoxFit.contain,
                    cacheWidth: 200,
                  ),
                );
              },
            ),
    );
  }
}
