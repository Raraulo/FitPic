import 'dart:io';

import 'package:flutter/material.dart';

import '../models/garment.dart';
import '../models/outfit.dart';
import '../theme/app_theme.dart';

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
    final assembledImages = _getAssembledImagePaths();
    final hasCoatInWardrobe = garments.any((g) =>
        g.category.toLowerCase().contains('abrigo') ||
        g.category.toLowerCase().contains('saco') ||
        g.category.toLowerCase().contains('chaqueta'));

    return Scaffold(
      appBar: AppBar(title: Text(outfit.style)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Outfit Header (No Pose)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkBrown,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.style.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    outfit.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Section Title
            const Text(
              'PRENDAS DEL OUTFIT',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),

            // Items List (Centered Image + How to wear for each garment)
            for (final item in outfit.items) _buildItemTile(context, item),

            // Recommendation for Coat/Jacket if not in wardrobe
            if (!hasCoatInWardrobe)
              const _InfoCard(
                icon: Icons.dry_cleaning_outlined,
                title: 'RECOMENDACIÓN DE ABRIGO / SACO / PARAGUAS',
                body: 'Según el clima y la hora, para complementar este outfit te sugerimos añadir una chaqueta de cuero, saco elegante, chompa o llevar paraguas.',
              ),

            const SizedBox(height: 10),

            // Accessories Section
            if (outfit.accessories.isNotEmpty)
              _InfoCard(
                icon: Icons.watch_outlined,
                title: 'ACCESORIOS RECOMENDADOS',
                body: outfit.accessories,
              ),

            // Why it works Section
            _InfoCard(
              icon: Icons.auto_awesome_outlined,
              title: 'POR QUÉ FUNCIONA',
              body: outfit.whyItWorks,
            ),

            // Tip Section
            _InfoCard(
              icon: Icons.lightbulb_outline,
              title: 'CONSEJO DEL ESTILISTA',
              body: outfit.tip,
            ),

            const SizedBox(height: 16),

            // Complete Vertical Unified Outfit Preview (Centered Contain Square Images)
            const Text(
              'VISTA PREVIA DEL OUTFIT ENSAMBLADO',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 4),
            const Text(
              'Combinación vertical centrada de arriba a abajo:',
              style: TextStyle(fontSize: 11, color: AppTheme.mediumBrown),
            ),
            const SizedBox(height: 8),

            _UnifiedOutfitPreview(imagePaths: assembledImages),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, OutfitItem item) {
    final garment = _findGarment(item);
    final imagePath = garment?.imagePath ?? '';
    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();

    String typeLabel = (item.type ?? garment?.category ?? 'PRENDA').toUpperCase();
    if (typeLabel.contains('ARRIBA') || typeLabel.contains('CAMISA')) typeLabel = 'PRENDA DE ARRIBA';
    if (typeLabel.contains('ABAJO') || typeLabel.contains('PANTAL')) typeLabel = 'PRENDA DE ABAJO';
    if (typeLabel.contains('CALZADO') || typeLabel.contains('TENIS') || typeLabel.contains('ZAPAT')) typeLabel = 'CALZADO';
    if (typeLabel.contains('ABRIGO') || typeLabel.contains('SACO') || typeLabel.contains('CHAQUETA')) typeLabel = 'ABRIGO / SACO';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garment Centered Contain Square Image
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(4),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.mediumBrown.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(3),
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
                  item.name.isNotEmpty ? item.name : garment?.name ?? 'Prenda del armario',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  item.howToWear.isNotEmpty ? item.howToWear : 'Úsala con estilo entallado y combinación armoniosa.',
                  style: const TextStyle(fontSize: 12, height: 1.25, color: Colors.black87),
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
    for (final g in garments) {
      if (g.name.toLowerCase().contains(item.name.toLowerCase()) ||
          item.name.toLowerCase().contains(g.name.toLowerCase())) {
        return g;
      }
    }
    return null;
  }

  List<String> _getAssembledImagePaths() {
    final paths = <String>[];
    for (final item in outfit.items) {
      final g = _findGarment(item);
      final p = g?.imagePath;
      if (p != null && p.isNotEmpty && File(p).existsSync() && !paths.contains(p)) {
        paths.add(p);
      }
    }
    return paths;
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
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.darkBrown),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.darkBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontSize: 13, height: 1.3, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _UnifiedOutfitPreview extends StatelessWidget {
  const _UnifiedOutfitPreview({required this.imagePaths});

  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: AppTheme.line)),
        child: const Center(
          child: Text(
            'Combina tus prendas guardadas para ver el ensamble visual.',
            style: TextStyle(fontSize: 12, color: AppTheme.mediumBrown),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.darkBrown, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          for (int i = 0; i < imagePaths.length; i++) ...[
            Container(
              height: 160,
              width: double.infinity,
              color: Colors.grey.shade50,
              alignment: Alignment.center,
              child: Image.file(
                File(imagePaths[i]),
                fit: BoxFit.contain,
              ),
            ),
            if (i < imagePaths.length - 1)
              Container(
                height: 2,
                color: AppTheme.darkBrown.withValues(alpha: .4),
              ),
          ],
        ],
      ),
    );
  }
}
