import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/garment.dart';
import '../theme/app_theme.dart';
import '../widgets/error_strip.dart';
import '../widgets/linear_loader.dart';
import 'garment_viewer_screen.dart';

class GarmentListScreen extends StatefulWidget {
  const GarmentListScreen({
    super.key,
    required this.categoryName,
    required this.categoryHint,
    required this.services,
    required this.onChanged,
  });

  final String categoryName;
  final String
      categoryHint; // e.g. 'Camisa', 'Saco', 'Pantalón', 'Accesorio', 'Calzado'
  final AppServices services;
  final VoidCallback onChanged;

  @override
  State<GarmentListScreen> createState() => _GarmentListScreenState();
}

class _GarmentListScreenState extends State<GarmentListScreen> {
  bool _loading = false;
  String? _error;

  List<Garment> _getCategoryGarments() {
    final all = widget.services.storage.garments;
    final hintLower = widget.categoryHint.toLowerCase();

    return all.where((g) {
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
    }).toList();
  }

  Future<void> _addGarment(
      {required bool fromGallery, bool useAi = true}) async {
    if (_loading) return;
    String? savedPath;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = fromGallery
          ? await widget.services.image.pickPhoto('armario')
          : await widget.services.image.takePhoto('armario');
      if (path != null) {
        final cleanPath = path;
        savedPath = cleanPath;
        await widget.services.storage.saveWardrobeImage(cleanPath);

        if (!useAi) {
          final normalized =
              await widget.services.image.prepareGarmentImage(path);
          final garment = _blankGarment(normalized);
          await widget.services.storage.addGarments([garment]);
          widget.onChanged();
          if (mounted) {
            setState(() => _loading = false);
            await _showEditDialog(garment, autoOpened: true);
          }
          return;
        }

        // Analyze with category hint
        var garments = await widget.services.vision.analyzeGarmentInCategory(
          cleanPath,
          widget.categoryHint,
        );

        if (garments.isEmpty) {
          final placeholder = _blankGarment(cleanPath);
          await widget.services.storage.addGarments([placeholder]);
          widget.onChanged();
          if (mounted) {
            setState(() => _loading = false);
            await _showEditDialog(placeholder, autoOpened: true);
          }
          return;
        }

        await widget.services.storage.addGarments(garments);
        widget.onChanged();
        if (mounted) AppTheme.notify(context, 'Prenda añadida a tu armario');
      }
    } catch (e) {
      final path = savedPath;
      if (path != null) {
        final normalized =
            await widget.services.image.prepareGarmentImage(path);
        final placeholder = _blankGarment(normalized);
        await widget.services.storage.addGarments([placeholder]);
        widget.onChanged();
        if (mounted) {
          setState(() {
            _loading = false;
            _error = e.toString();
          });
          await _showEditDialog(placeholder, autoOpened: true);
        }
        return;
      }
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Garment _blankGarment(String path) {
    return Garment(
      id: 'armario_${DateTime.now().millisecondsSinceEpoch}',
      name: '${widget.categoryHint} nueva',
      category: widget.categoryHint,
      color: '',
      material: '',
      season: 'Todo clima',
      imagePath: path,
    );
  }

  Future<void> _identifyAgain(Garment garment) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.services.vision
          .analyzeGarmentInCategory(garment.imagePath, garment.category);
      if (results.isEmpty) return;
      final result = results.first;
      await widget.services.storage.addGarments([
        Garment(
          id: garment.id,
          name: result.name,
          category: result.category,
          color: result.color,
          material: result.material,
          season: result.season,
          imagePath: result.imagePath,
        )
      ]);
      widget.onChanged();
      if (mounted)
        AppTheme.notify(context, 'Prenda identificada correctamente');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddPhotoSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Agregar ${widget.categoryName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkBrown,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined,
                      color: AppTheme.darkBrown),
                  title: const Text('Tomar foto con Cámara',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'La IA detectará automáticamente el color y estilo'),
                  onTap: () {
                    Navigator.pop(context);
                    _addGarment(fromGallery: false);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: AppTheme.darkBrown),
                  title: const Text('Seleccionar de Galería',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle:
                      const Text('Elige una foto existente de tu dispositivo'),
                  onTap: () {
                    Navigator.pop(context);
                    _addGarment(fromGallery: true);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Agregar manualmente'),
                  subtitle: const Text(
                      'Elige una foto y escribe sus datos, sin esperar a la IA'),
                  onTap: () {
                    Navigator.pop(context);
                    _addGarment(fromGallery: true, useAi: false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Garment garment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('¿Eliminar prenda?'),
        content: Text(
            '¿Estás seguro de que deseas eliminar "${garment.name}" de tu armario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.services.storage.deleteGarment(garment.id);
      widget.onChanged();
      if (mounted) {
        setState(() {});
        AppTheme.notify(context, 'Prenda eliminada');
      }
    }
  }

  Future<void> _showEditDialog(Garment garment,
      {bool autoOpened = false}) async {
    final nameCtrl = TextEditingController(text: garment.name);
    final colorCtrl = TextEditingController(text: garment.color);
    var selectedCategory = garment.category;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !autoOpened,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    autoOpened
                        ? 'Completar prenda manualmente'
                        : 'Editar detalles',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  const Text('Nombre',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ej: Camisa oxford blanca',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Color',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: colorCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ej: Negro, Azul, Blanco',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (!autoOpened)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _identifyAgain(garment);
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Volver a identificar con IA'),
                    ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: [
                      'Camisa',
                      'Saco',
                      'Pantalón',
                      'Mono',
                      'Accesorio',
                      'Calzado'
                    ].contains(selectedCategory)
                        ? selectedCategory
                        : null,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: const [
                      'Camisa',
                      'Saco',
                      'Pantalón',
                      'Mono',
                      'Accesorio',
                      'Calzado'
                    ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        setModalState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (!autoOpened)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                        ),
                      if (!autoOpened) const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.darkBrown,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final updated = Garment(
                              id: garment.id,
                              name: nameCtrl.text.trim().isEmpty
                                  ? garment.name
                                  : nameCtrl.text.trim(),
                              category: selectedCategory,
                              color: colorCtrl.text.trim().isEmpty
                                  ? 'Sin color'
                                  : colorCtrl.text.trim(),
                              material: garment.material,
                              season: garment.season,
                              imagePath: garment.imagePath,
                            );
                            await widget.services.storage
                                .addGarments([updated]);
                            widget.onChanged();
                            if (context.mounted) {
                              setState(() {});
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final garments = _getCategoryGarments();
    final compact =
        widget.categoryHint == 'Accesorio' || widget.categoryHint == 'Calzado';
    final columns = compact ? 3 : 2;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.darkBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.categoryName),
        actions: [
          // Rectangular "Agregar +" button on top left/right as requested
          Padding(
            padding:
                const EdgeInsets.only(right: 12.0, top: 10.0, bottom: 10.0),
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _showAddPhotoSourceOptions,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkBrown,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearLoader(visible: _loading, label: 'Identificando tu prenda…'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: ErrorStrip(message: _error!),
              ),
            Expanded(
              child: garments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.checkroom_outlined,
                              size: 64,
                              color:
                                  AppTheme.mediumBrown.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'No tienes ${widget.categoryName.toLowerCase()} guardadas',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkBrown,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Presiona "Agregar +" para subir tu primera prenda',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(14),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: (MediaQuery.sizeOf(context).width -
                                    28 -
                                    (columns - 1) * 12) /
                                columns +
                            56,
                      ),
                      itemCount: garments.length,
                      itemBuilder: (context, index) {
                        final garment = garments[index];
                        final hasFile = garment.imagePath.isNotEmpty;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GarmentViewerScreen(
                                  garments: garments,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          onLongPress: () => _showEditDialog(garment),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.zero,
                              border: Border.all(color: AppTheme.darkBrown),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.zero,
                                          child: !hasFile
                                              ? const Center(
                                                  child: Icon(
                                                      Icons.checkroom_outlined))
                                              : Image.file(
                                                  File(garment.imagePath),
                                                  cacheWidth: 480,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Center(
                                                          child: Icon(Icons
                                                              .checkroom_outlined)),
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.contain,
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 6,
                                        left: 6,
                                        child: IconButton.filledTonal(
                                          tooltip:
                                              'Editar o identificar prenda',
                                          onPressed: _loading
                                              ? null
                                              : () => _showEditDialog(garment),
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18),
                                        ),
                                      ),
                                      // Delete button with confirmation (square)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Material(
                                          color: Colors.black
                                              .withValues(alpha: 0.7),
                                          shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.zero),
                                          child: InkWell(
                                            onTap: () =>
                                                _confirmDelete(garment),
                                            child: const Padding(
                                              padding: EdgeInsets.all(6),
                                              child: Icon(
                                                Icons.delete_outline,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        garment.name,
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
                                        garment.color.isNotEmpty
                                            ? garment.color
                                            : 'Sin color',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.mediumBrown,
                                        ),
                                      ),
                                    ],
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
    );
  }
}
