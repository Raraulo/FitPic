import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/garment.dart';
import '../theme/app_theme.dart';
import '../widgets/error_strip.dart';
import '../widgets/linear_loader.dart';
import '../widgets/square_action_button.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key, required this.services, required this.onChanged});

  final AppServices services;
  final VoidCallback onChanged;

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _addWardrobePhoto({required bool fromGallery}) async {
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
        // Retocar fondo a blanco antes de analizar y mostrar
        final cleanPath = await widget.services.image.removeBackground(path);
        savedPath = cleanPath;
        await widget.services.storage.saveWardrobeImage(cleanPath);
        var garments = await widget.services.vision.analyzeWardrobe(cleanPath);
        if (garments.isEmpty) {
          // IA no pudo detectar → guardar con datos vacíos y abrir editor
          final placeholder = _blankGarment(path);
          await widget.services.storage.addGarments([placeholder]);
          widget.onChanged();
          if (mounted) {
            setState(() => _loading = false);
            // Small delay so the grid updates before the dialog appears
            await Future.delayed(const Duration(milliseconds: 200));
            await _showEditDialog(placeholder, autoOpened: true);
          }
          return;
        }
        await widget.services.storage.addGarments(garments);
        widget.onChanged();
      }
    } catch (e) {
      final path = savedPath;
      if (path != null) {
        final placeholder = _blankGarment(path);
        await widget.services.storage.addGarments([placeholder]);
        widget.onChanged();
        if (mounted) {
          setState(() => _loading = false);
          await Future.delayed(const Duration(milliseconds: 200));
          await _showEditDialog(placeholder, autoOpened: true);
        }
        return;
      }
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Garment con la foto pero sin datos — el usuario los completará manualmente.
  Garment _blankGarment(String path) {
    return Garment(
      id: 'armario_${DateTime.now().millisecondsSinceEpoch}',
      name: '',
      category: '',
      color: '',
      material: '',
      season: 'Todo clima',
      imagePath: path,
    );
  }


  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('FormatException') || text.contains('Unexpected character')) {
      return 'La foto se guardo, pero Groq devolvio un formato invalido. Intenta otra foto o usa Sugerir con las prendas actuales.';
    }
    if (text.contains('Groq Vision error')) {
      return 'La foto se guardo, pero el analisis de Groq fallo. Intenta otra foto.';
    }
    return text;
  }
  Future<void> _deleteGarment(String id) async {
    await widget.services.storage.deleteGarment(id);
    widget.onChanged();
    if (mounted) {
      setState(() {});
    }
  }
  Future<void> _showEditDialog(Garment garment, {bool autoOpened = false}) async {
    final nameCtrl = TextEditingController(text: garment.name);
    final colorCtrl = TextEditingController(text: garment.color);
    String selectedCategory = garment.category;

    const categories = ['Camiseta', 'Camisa', 'Pantalón', 'Jean', 'Abrigo', 'Saco', 'Calzado', 'Accesorio'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !autoOpened,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(
              20, 16, 20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header row with photo
                  Row(
                    children: [
                      if (garment.imagePath.isNotEmpty && File(garment.imagePath).existsSync())
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(garment.imagePath),
                            width: 56, height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                      if (garment.imagePath.isNotEmpty && File(garment.imagePath).existsSync())
                        const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              autoOpened ? 'Identificar prenda' : 'Editar prenda',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            if (autoOpened)
                              const Text(
                                'La IA no pudo identificarla automáticamente.',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Nombre
                  const Text('Nombre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ej: Camisa oxford blanca',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Color
                  const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: colorCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ej: Negro, Blanco, Azul marino',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Categoría chips
                  const Text('Categoría', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categories.map((cat) {
                      final selected = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? Colors.black87 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              color: selected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      if (!autoOpened) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            final updated = Garment(
                              id: garment.id,
                              name: nameCtrl.text.trim().isEmpty ? 'Sin nombre' : nameCtrl.text.trim(),
                              category: selectedCategory.isEmpty ? 'Sin categoría' : selectedCategory,
                              color: colorCtrl.text.trim().isEmpty ? 'Sin color' : colorCtrl.text.trim(),
                              material: garment.material,
                              season: garment.season,
                              imagePath: garment.imagePath,
                            );
                            await widget.services.storage.addGarments([updated]);
                            widget.onChanged();
                            if (mounted) setState(() {});
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
    final garments = widget.services.storage.garments;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Armario'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${garments.length} prendas',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearLoader(visible: _loading),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (_error != null) ...[
                    ErrorStrip(message: _error!),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: SquareActionButton(
                          label: 'Cámara',
                          icon: Icons.add_a_photo_outlined,
                          onPressed: _loading ? null : () => _addWardrobePhoto(fromGallery: false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SquareActionButton(
                          label: 'Galería',
                          icon: Icons.photo_library_outlined,
                          primary: false,
                          onPressed: _loading ? null : () => _addWardrobePhoto(fromGallery: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: garments.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay prendas registradas.\nToma o sube una foto de tu armario o ropa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.mediumBrown),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: .82,
                      ),
                      itemCount: garments.length,
                      itemBuilder: (context, index) {
                        final garment = garments[index];
                        final hasFile = garment.imagePath.isNotEmpty && File(garment.imagePath).existsSync();
                        return GestureDetector(
                          onTap: () => _showEditDialog(garment),
                          child: Container(
                            decoration: BoxDecoration(border: Border.all(color: AppTheme.darkBrown, width: .7)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: !hasFile
                                            ? const Center(child: Icon(Icons.checkroom_outlined))
                                            : Container(
                                                color: Colors.grey.shade50,
                                                alignment: Alignment.center,
                                                child: Image.file(
                                                  File(garment.imagePath),
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          color: Colors.black54,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _deleteGarment(garment.id),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        garment.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                      ),
                                      Text(
                                        '${garment.color} · ${garment.category}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.mediumBrown),
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
