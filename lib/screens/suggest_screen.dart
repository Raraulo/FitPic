import 'dart:convert';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/outfit.dart';
import '../theme/app_theme.dart';
import '../widgets/error_strip.dart';
import '../widgets/linear_loader.dart';
import '../widgets/outfit_card.dart';
import '../widgets/square_action_button.dart';
import 'outfit_detail_screen.dart';

class SuggestScreen extends StatefulWidget {
  const SuggestScreen({super.key, required this.services, required this.onChanged});

  final AppServices services;
  final VoidCallback onChanged;

  @override
  State<SuggestScreen> createState() => _SuggestScreenState();
}

enum _ViewFilter { historial, favoritos }

class _SuggestScreenState extends State<SuggestScreen> {
  bool _loading = false;
  String? _error;
  _ViewFilter _filter = _ViewFilter.historial;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _generate({Outfit? base}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final weather = await widget.services.weather.getCurrentWeather();
      final favorites = widget.services.storage.favoriteOutfits;

      var outfits = await widget.services.groq.generateOutfits(
        faceAnalysis: widget.services.storage.faceAnalysis,
        weather: weather,
        garments: widget.services.storage.garments,
        favoriteOutfits: favorites,
        selectedOutfitJson: base == null ? null : jsonEncode(base.toJson()),
      );

      // Hard-deduplicate: remove any generated outfit whose garment-ID set
      // exactly matches a favorite (so the AI can't silently repeat them).
     if (favorites.isNotEmpty) {
  final favSets = favorites
      .map((f) => f.items.map((i) => i.id).toSet())
      .toList();
  outfits = outfits.where((o) {
    final ids = o.items.map((i) => i.id).toSet();
    return !favSets.any((fav) => fav.length == ids.length && fav.containsAll(ids));
  }).toList();
}

      await widget.services.storage.saveHistoryOutfits(outfits);
      setState(() => _filter = _ViewFilter.historial);
      widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(Outfit outfit) async {
    await widget.services.storage.toggleFavorite(outfit);
    widget.onChanged();
    if (mounted) setState(() {});
  }

  void _open(Outfit outfit, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OutfitDetailScreen(
          outfit: outfit,
          garments: widget.services.storage.garments,
          heroTag: 'outfit-${outfit.id}-$index',
        ),
      ),
    );
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text('¿Estás seguro de que quieres borrar todo tu historial de sugerencias?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.services.storage.clearHistory();
      widget.onChanged();
    }
  }

  List<Outfit> _getDisplayedOutfits() {
    switch (_filter) {
      case _ViewFilter.historial:
        return widget.services.storage.historyOutfits;
      case _ViewFilter.favoritos:
        return widget.services.storage.favoriteOutfits;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedOutfits = _getDisplayedOutfits();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugerir Estilos'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearLoader(visible: _loading),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null) ...[
                    ErrorStrip(message: _error!),
                    const SizedBox(height: 10),
                  ],

                  // Main Suggest Button
                  SquareActionButton(
                    label: 'Sugerir ropa',
                    icon: Icons.auto_awesome_outlined,
                    onPressed: _loading ? null : () => _generate(),
                  ),
                  const SizedBox(height: 10),

                  // Filter Buttons: Historial | Favoritos
                  Row(
                    children: [
                      Expanded(
                        child: SquareActionButton(
                          label: 'Historial',
                          icon: Icons.history,
                          primary: _filter == _ViewFilter.historial,
                          onPressed: () => setState(() => _filter = _ViewFilter.historial),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SquareActionButton(
                          label: 'Favoritos',
                          icon: Icons.favorite,
                          primary: _filter == _ViewFilter.favoritos,
                          onPressed: () => setState(() => _filter = _ViewFilter.favoritos),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section Title and Clear History button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _filter == _ViewFilter.historial
                            ? 'HISTORIAL DE SUGERENCIAS (${displayedOutfits.length})'
                            : 'MIS FAVORITOS ❤️ (${displayedOutfits.length})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.9),
                      ),
                      if (_filter == _ViewFilter.historial && displayedOutfits.isNotEmpty)
                        TextButton.icon(
                          onPressed: _loading ? null : _clearHistory,
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          label: const Text('Borrar', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (displayedOutfits.isEmpty && !_loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Text(
                        _filter == _ViewFilter.favoritos
                            ? 'Aún no tienes outfits en favoritos.\nToca el ícono del corazón (❤️) en cualquier outfit para guardarlo aquí.'
                            : 'Presiona "Sugerir ropa" para generar 4 propuestas basadas en tu armario, clima y hora.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppTheme.mediumBrown, height: 1.3),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: .88,
                      ),
                      itemCount: displayedOutfits.length,
                      itemBuilder: (context, index) {
                        final outfit = displayedOutfits[index];
                        final isFav = widget.services.storage.isFavorite(outfit.id);

                        return OutfitCard(
                          outfit: outfit,
                          index: index,
                          garments: widget.services.storage.garments,
                          isFavorite: isFav,
                          onFavoriteToggle: () => _toggleFavorite(outfit),
                          onTap: () => _open(outfit, index),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
