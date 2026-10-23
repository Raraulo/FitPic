import 'dart:io';
import 'package:flutter/material.dart';
import '../models/garment.dart';
import '../theme/app_theme.dart';

class GarmentViewerScreen extends StatefulWidget {
  const GarmentViewerScreen({
    super.key,
    required this.garments,
    required this.initialIndex,
  });

  final List<Garment> garments;
  final int initialIndex;

  @override
  State<GarmentViewerScreen> createState() => _GarmentViewerScreenState();
}

class _GarmentViewerScreenState extends State<GarmentViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // PageView for swiping garments
            PageView.builder(
              controller: _pageController,
              itemCount: widget.garments.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final garment = widget.garments[index];
                final hasFile = garment.imagePath.isNotEmpty;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 24.0),
                        child: Center(
                          child: hasFile
                              ? ClipRRect(
                                  borderRadius: BorderRadius.zero,
                                  child: Image.file(
                                    File(garment.imagePath),
                                    cacheWidth: 1080,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white54),
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              : const Icon(
                                  Icons.checkroom_outlined,
                                  size: 100,
                                  color: Colors.white54,
                                ),
                        ),
                      ),
                    ),
                    // Garment metadata overlay at bottom
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      color: Colors.black54,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.mediumBrown.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Text(
                              garment.category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            garment.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Color: ${garment.color}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_currentIndex + 1} de ${widget.garments.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            // Top Bar with Close button
            Positioned(
              top: 10,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
