import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/garment.dart';
import '../models/outfit.dart';
import '../theme/app_theme.dart';
import '../widgets/garment_rail.dart';
import 'outfit_detail_screen.dart';

enum _LayoutMode { two, three, four }

class SuggestScreen extends StatefulWidget {
  const SuggestScreen(
      {super.key, required this.services, required this.onChanged});

  final AppServices services;
  final VoidCallback onChanged;

  @override
  State<SuggestScreen> createState() => _SuggestScreenState();
}

class _SuggestScreenState extends State<SuggestScreen> {
  _LayoutMode _layout = _LayoutMode.three;
  final Map<String, String> _selectedGarmentIds = {};
  bool _loading = false;
  bool _showFavorites = false;
  bool _heartBurst = false;
  String? _error;

  List<_OutfitSlot> get _slots {
    if (_layout == _LayoutMode.two) {
      return const [
        _OutfitSlot(label: 'Mono / vestido', matcher: _matchesOnePiece),
        _OutfitSlot(label: 'Calzado', matcher: _matchesShoes),
        _OutfitSlot(label: 'Accesorio', matcher: _matchesAccessory),
      ];
    }
    if (_layout == _LayoutMode.three) {
      return const [
        _OutfitSlot(label: 'Arriba', matcher: _matchesTop),
        _OutfitSlot(label: 'Abajo', matcher: _matchesBottom),
        _OutfitSlot(label: 'Calzado', matcher: _matchesShoes),
        _OutfitSlot(label: 'Accesorio', matcher: _matchesAccessory),
      ];
    }
    return const [
      _OutfitSlot(label: 'Abrigo', matcher: _matchesOuterwear),
      _OutfitSlot(label: 'Arriba', matcher: _matchesTop),
      _OutfitSlot(label: 'Abajo', matcher: _matchesBottom),
      _OutfitSlot(label: 'Calzado', matcher: _matchesShoes),
      _OutfitSlot(label: 'Accesorio', matcher: _matchesAccessory),
    ];
  }

  List<Garment> _garmentsFor(_OutfitSlot slot) {
    return widget.services.storage.garments.where(slot.matcher).toList();
  }

  Garment? _selectedFor(_OutfitSlot slot) {
    final garments = _garmentsFor(slot);
    if (garments.isEmpty) return null;
    final selectedId = _selectedGarmentIds[slot.label];
    return garments.firstWhere((g) => g.id == selectedId,
        orElse: () => garments.first);
  }

  Future<void> _generateWithAi() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _showFavorites = false;
    });
    try {
      final weather = await widget.services.weather.getCurrentWeather();
      final outfits = await widget.services.groq.generateOutfits(
        faceAnalysis: widget.services.storage.faceAnalysis,
        weather: weather,
        garments: widget.services.storage.garments,
        favoriteOutfits: widget.services.storage.favoriteOutfits,
      );
      if (outfits.isNotEmpty) {
        if (mounted) _applyOutfit(outfits.first);
      } else {
        if (mounted) _applyLocalFallbackOutfit();
      }
    } catch (e) {
      if (mounted)
        AppTheme.notify(
            context, 'Usamos una combinación local para que puedas continuar.',
            isError: true);
      if (mounted) {
        _applyLocalFallbackOutfit();
        setState(() => _error =
            'La IA no está disponible. Se eligió una combinación local; puedes ajustarla manualmente.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyLocalFallbackOutfit() {
    final next = <String, String>{};
    final usedIds = <String>{};
    final random = Random();

    for (final slot in _slots) {
      final options =
          _garmentsFor(slot).where((g) => !usedIds.contains(g.id)).toList();
      if (options.isEmpty) continue;
      options.shuffle(random);
      final chosen = options.first;
      next[slot.label] = chosen.id;
      usedIds.add(chosen.id);
    }

    if (next.isEmpty) {
      setState(
          () => _error = 'No hay prendas suficientes para armar un outfit.');
      return;
    }

    setState(() {
      _selectedGarmentIds
        ..clear()
        ..addAll(next);
    });
  }

  void _applyOutfit(Outfit outfit) {
    final garments = widget.services.storage.garments;
    final selectedIds = outfit.items.map((item) => item.id).toSet();
    final chosen = garments.where((g) => selectedIds.contains(g.id));
    _layout = chosen.any(_matchesOnePiece)
        ? _LayoutMode.two
        : chosen.any(_matchesOuterwear)
            ? _LayoutMode.four
            : _LayoutMode.three;
    final next = <String, String>{};
    for (final slot in _slots) {
      final options = _garmentsFor(slot);
      for (final item in outfit.items) {
        Garment? found;
        for (final garment in garments) {
          if (garment.id == item.id) {
            found = garment;
            break;
          }
        }
        final foundId = found?.id;
        if (foundId != null && options.any((g) => g.id == foundId)) {
          next[slot.label] = foundId;
          break;
        }
      }
    }
    setState(() => _selectedGarmentIds
      ..clear()
      ..addAll(next));
  }

  Future<void> _saveCurrentOutfit() async {
    final requiredSlots =
        _slots.where((slot) => slot.label != 'Accesorio').toList();
    final selected = _slots.map(_selectedFor).whereType<Garment>().toList();
    final selectedRequired =
        requiredSlots.map(_selectedFor).whereType<Garment>().toList();
    if (selectedRequired.length != requiredSlots.length) return;
    final id = 'manual_${selected.map((g) => g.id).join('_')}';
    if (widget.services.storage.isFavorite(id)) {
      setState(() => _showFavorites = true);
      return;
    }
    final name = await _askOutfitName();
    if (name == null) return;

    final outfit = Outfit(
      id: id,
      style: 'Manual',
      name: name,
      pose: '',
      items: selected
          .map((g) => OutfitItem(
              id: g.id, name: g.name, howToWear: '', type: _typeFor(g)))
          .toList(),
      accessories: '',
      visualDescription: selected.map((g) => g.name).join(', '),
      whyItWorks: _buildWhyItWorks(selected),
      tip: _buildStylistTip(selected),
    );
    if (!widget.services.storage.isFavorite(outfit.id)) {
      await widget.services.storage.toggleFavorite(outfit);
    }
    widget.onChanged();
    if (mounted) {
      setState(() => _heartBurst = true);
      await Future.delayed(const Duration(milliseconds: 420));
      if (mounted) {
        setState(() {
          _heartBurst = false;
          _showFavorites = true;
        });
        AppTheme.notify(context, 'Outfit guardado en tus favoritos');
      }
    }
  }

  String _buildWhyItWorks(List<Garment> garments) {
    final colors = garments
        .map((g) => g.color.trim())
        .where((c) => c.isNotEmpty && c.toLowerCase() != 'sin color')
        .toSet()
        .take(3)
        .join(', ');
    if (colors.isEmpty) {
      return 'Funciona porque mantiene una silueta clara con prendas de tu armario: base, calzado y detalle final.';
    }
    return 'Funciona porque combina $colors con una estructura equilibrada y coherente con tu perfil de estilo.';
  }

  String _buildStylistTip(List<Garment> garments) {
    if (garments.any(_matchesOuterwear)) {
      return 'Lleva el abrigo como capa principal y deja visible la prenda de arriba para que el conjunto se vea intencional.';
    }
    if (garments.any(_matchesAccessory)) {
      return 'Usa el accesorio como acento visual, idealmente conectado con el color del calzado o la prenda superior.';
    }
    return 'Cuida el ajuste: la prenda de arriba debe verse limpia y el pantalon debe caer bien sobre el calzado.';
  }

  Future<String?> _askOutfitName() {
    final controller = TextEditingController(text: 'Mi outfit');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Nombre del outfit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej: Cena elegante'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkBrown,
              foregroundColor: Colors.white,
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(context, text.isEmpty ? 'Mi outfit' : text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _openFavorite(Outfit outfit, int index) {
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

  @override
  Widget build(BuildContext context) {
    final garments = widget.services.storage.garments;
    final slots = _slots;
    final selected = slots.map(_selectedFor).whereType<Garment>().toList();
    final requiredSlots =
        slots.where((slot) => slot.label != 'Accesorio').toList();
    final canSave =
        requiredSlots.map(_selectedFor).whereType<Garment>().length ==
            requiredSlots.length;
    final currentId = 'manual_${selected.map((g) => g.id).join('_')}';
    final isFavorite = canSave && widget.services.storage.isFavorite(currentId);
    final favorites = widget.services.storage.favoriteOutfits;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.canvas,
        elevation: 0,
        title: Text(_showFavorites ? 'Favoritos' : 'Outfits'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_showFavorites)
              favorites.isEmpty
                  ? const Center(child: Text('No tienes outfits guardados'))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 86),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: .9,
                      ),
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final outfit = favorites[index];
                        return _FavoriteOutfitTile(
                          outfit: outfit,
                          garments: garments,
                          onTap: () => _openFavorite(outfit, index),
                          onDelete: () async {
                            await widget.services.storage
                                .toggleFavorite(outfit);
                            widget.onChanged();
                            if (mounted) setState(() {});
                          },
                        );
                      },
                    )
            else if (garments.isEmpty)
              const Center(
                  child: Text(
                      'Agrega prendas en el armario para combinarlas aqui'))
            else
              Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Text(
                        _error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 88),
                      itemCount: slots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final slot = slots[index];
                        return GarmentRail(
                          key: ValueKey(slot.label),
                          title: slot.label,
                          garments: _garmentsFor(slot),
                          selectedId: _selectedGarmentIds[slot.label],
                          compact: slot.label == 'Accesorio' ||
                              slot.label == 'Calzado',
                          onSelected: (garment) {
                            setState(() =>
                                _selectedGarmentIds[slot.label] = garment.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            if (!_showFavorites && canSave)
              Positioned(
                right: 18,
                bottom: 76,
                child: AnimatedScale(
                  scale: _heartBurst ? 1.28 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Material(
                    color:
                        isFavorite ? Colors.red.shade400 : AppTheme.darkBrown,
                    shape: const CircleBorder(),
                    elevation: 8,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _saveCurrentOutfit,
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.favorite, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 42,
              right: 42,
              bottom: 12,
              child: _BottomControls(
                layout: _layout,
                loading: _loading,
                showingFavorites: _showFavorites,
                onLayoutChanged: (layout) => setState(() {
                  _layout = layout;
                  _showFavorites = false;
                }),
                onAi: garments.isEmpty || _loading ? null : _generateWithAi,
                onFavorites: () =>
                    setState(() => _showFavorites = !_showFavorites),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.layout,
    required this.loading,
    required this.showingFavorites,
    required this.onLayoutChanged,
    required this.onAi,
    required this.onFavorites,
  });

  final _LayoutMode layout;
  final bool loading;
  final bool showingFavorites;
  final ValueChanged<_LayoutMode> onLayoutChanged;
  final VoidCallback? onAi;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppTheme.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlTextButton(
              label: '2',
              selected: layout == _LayoutMode.two,
              onTap: () => onLayoutChanged(_LayoutMode.two)),
          _ControlTextButton(
              label: '3',
              selected: layout == _LayoutMode.three,
              onTap: () => onLayoutChanged(_LayoutMode.three)),
          _ControlTextButton(
              label: '4',
              selected: layout == _LayoutMode.four,
              onTap: () => onLayoutChanged(_LayoutMode.four)),
          IconButton(
            tooltip: 'Recomendar con IA',
            onPressed: onAi,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.darkBrown),
                  )
                : const Icon(Icons.casino_outlined, color: AppTheme.darkBrown),
          ),
          IconButton(
            tooltip: 'Favoritos',
            onPressed: onFavorites,
            icon: Icon(
              showingFavorites ? Icons.favorite : Icons.favorite_border,
              color: AppTheme.darkBrown,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlTextButton extends StatelessWidget {
  const _ControlTextButton(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.darkBrown : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : AppTheme.darkBrown,
          ),
        ),
      ),
    );
  }
}

class _FavoriteOutfitTile extends StatelessWidget {
  const _FavoriteOutfitTile({
    required this.outfit,
    required this.garments,
    required this.onTap,
    required this.onDelete,
  });

  final Outfit outfit;
  final List<Garment> garments;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final outfitGarments = _resolveGarments();
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppTheme.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      outfit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.darkBrown,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(Icons.favorite,
                        color: Colors.redAccent, size: 20),
                  ),
                ],
              ),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount:
                      outfitGarments.length > 4 ? 4 : outfitGarments.length,
                  itemBuilder: (context, index) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F7),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: _GarmentImage(
                            garment: outfitGarments[index], cacheWidth: 220),
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

  List<Garment> _resolveGarments() {
    final result = <Garment>[];
    for (final item in outfit.items) {
      for (final garment in garments) {
        if (garment.id == item.id && !result.any((g) => g.id == garment.id)) {
          result.add(garment);
          break;
        }
      }
    }
    return result;
  }
}

class _GarmentImage extends StatelessWidget {
  const _GarmentImage({required this.garment, required this.cacheWidth});

  final Garment garment;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final hasFile = garment.imagePath.isNotEmpty;
    if (!hasFile) {
      return Icon(
        Icons.checkroom_outlined,
        color: AppTheme.mediumBrown.withValues(alpha: .45),
        size: 42,
      );
    }
    return Image.file(
      File(garment.imagePath),
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
    );
  }
}

class _OutfitSlot {
  const _OutfitSlot({required this.label, required this.matcher});

  final String label;
  final bool Function(Garment garment) matcher;
}

bool _matchesTop(Garment garment) {
  final text = _searchText(garment);
  return text.contains('camisa') ||
      text.contains('camiseta') ||
      text.contains('top') ||
      text.contains('blusa') ||
      text.contains('polo');
}

bool _matchesOuterwear(Garment garment) {
  final text = _searchText(garment);
  return text.contains('saco') ||
      text.contains('abrigo') ||
      text.contains('chaqueta') ||
      text.contains('chompa') ||
      text.contains('sueter') ||
      text.contains('sweater');
}

bool _matchesBottom(Garment garment) {
  final text = _searchText(garment);
  if (_matchesOuterwear(garment) ||
      _matchesTop(garment) ||
      _matchesShoes(garment)) {
    return false;
  }
  return text.contains('pantalon') ||
      text.contains('pantalón') ||
      text.contains('jean') ||
      text.contains('falda') ||
      text.contains('short');
}

bool _matchesShoes(Garment garment) {
  final text = _searchText(garment);
  return text.contains('calzado') ||
      text.contains('zapato') ||
      text.contains('zapatilla') ||
      text.contains('bota') ||
      text.contains('tenis');
}

bool _matchesOnePiece(Garment garment) {
  final text = _searchText(garment);
  return text.contains('mono') ||
      text.contains('vestido') ||
      text.contains('enterizo') ||
      text.contains('jumpsuit');
}

bool _matchesAccessory(Garment garment) {
  final text = _searchText(garment);
  return text.contains('accesorio') ||
      text.contains('gorra') ||
      text.contains('reloj') ||
      text.contains('cintur') ||
      text.contains('lente') ||
      text.contains('gafa');
}

String _typeFor(Garment garment) {
  if (_matchesOuterwear(garment)) return 'abrigo';
  if (_matchesTop(garment)) return 'arriba';
  if (_matchesBottom(garment)) return 'abajo';
  if (_matchesShoes(garment)) return 'calzado';
  if (_matchesAccessory(garment)) return 'accesorio';
  if (_matchesOnePiece(garment)) return 'mono';
  return garment.category;
}

String _searchText(Garment garment) {
  return '${garment.category} ${garment.name}'.toLowerCase();
}
