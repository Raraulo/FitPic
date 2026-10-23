import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import 'garment_list_screen.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({
    super.key,
    required this.services,
    required this.onChanged,
  });

  final AppServices services;
  final VoidCallback onChanged;

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  // Category Definitions mapped to assets/ropa/
  final List<_CategoryItem> _categories = const [
    _CategoryItem(
      title: 'Camisas & Camisetas',
      hint: 'Camisa',
      assetPath: 'assets/ropa/camisa.png',
    ),
    _CategoryItem(
      title: 'Sacos & Abrigos',
      hint: 'Saco',
      assetPath: 'assets/ropa/saco.png',
    ),
    _CategoryItem(
      title: 'Pantalones & Jeans',
      hint: 'Pantalón',
      assetPath: 'assets/ropa/pantalon.png',
    ),
    _CategoryItem(
      title: 'Monos & Vestidos',
      hint: 'Mono',
      assetPath: 'assets/ropa/mono.jpg',
    ),
    _CategoryItem(
      title: 'Accesorios & Gorras',
      hint: 'Accesorio',
      assetPath: 'assets/ropa/accesorio.png',
    ),
    _CategoryItem(
      title: 'Zapatos & Calzado',
      hint: 'Calzado',
      assetPath: 'assets/ropa/zapatos.png',
    ),
  ];

  int _countForCategory(String hint) {
    final garments = widget.services.storage.garments;
    final hintLower = hint.toLowerCase();

    return garments.where((g) {
      final catLower = g.category.toLowerCase();
      if (hintLower == 'camisa') {
        return catLower.contains('camisa') ||
            catLower.contains('camiseta') ||
            catLower.contains('top');
      } else if (hintLower == 'saco') {
        return catLower.contains('saco') ||
            catLower.contains('abrigo') ||
            catLower.contains('chompa') ||
            catLower.contains('chaqueta') ||
            catLower.contains('suéter');
      } else if (hintLower == 'pantalón' || hintLower == 'pantalon') {
        return catLower.contains('pantalón') ||
            catLower.contains('pantalon') ||
            catLower.contains('jean');
      } else if (hintLower == 'mono' || hintLower == 'vestido') {
        return catLower.contains('mono') ||
            catLower.contains('vestido') ||
            catLower.contains('enterizo');
      } else if (hintLower == 'accesorio') {
        return catLower.contains('accesorio') ||
            catLower.contains('gorra') ||
            catLower.contains('cintur') ||
            catLower.contains('reloj');
      } else if (hintLower == 'calzado' || hintLower == 'zapatos') {
        return catLower.contains('calzado') ||
            catLower.contains('zapato') ||
            catLower.contains('zapatilla');
      }
      return catLower.contains(hintLower);
    }).length;
  }

  void _openCategory(_CategoryItem cat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentListScreen(
          categoryName: cat.title,
          categoryHint: cat.hint,
          services: widget.services,
          onChanged: () {
            setState(() {});
            widget.onChanged();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalGarments = widget.services.storage.garments.length;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.canvas,
        elevation: 0,
        title: const Text('Armario'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0ECE9),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(
                  '$totalGarments prendas',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkBrown,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona una categoría para explorar o agregar ropa:',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.mediumBrown,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final count = _countForCategory(cat.hint);

                    return GestureDetector(
                      onTap: () => _openCategory(cat),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppTheme.line),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.cocoa.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Content Column
                            Column(
                              children: [
                                const SizedBox(height: 12),
                                // Image representation from assets/ropa/
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 8.0),
                                    child: Image.asset(
                                      cat.assetPath,
                                      cacheWidth: 480,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.checkroom_rounded,
                                        size: 48,
                                        color: AppTheme.mediumBrown,
                                      ),
                                    ),
                                  ),
                                ),
                                // Bottom Label and Count
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(22)),
                                    border: Border(
                                      top: BorderSide(
                                        color: AppTheme.line,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        cat.title,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.darkBrown,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$count ${count == 1 ? 'prenda' : 'prendas'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.mediumBrown
                                              .withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Square '+' button overlay
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: AppTheme.darkBrown,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: InkWell(
                                  onTap: () => _openCategory(cat),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.title,
    required this.hint,
    required this.assetPath,
  });

  final String title;
  final String hint;
  final String assetPath;
}
