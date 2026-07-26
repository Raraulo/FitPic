import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/error_strip.dart';
import '../widgets/linear_loader.dart';
import '../widgets/square_action_button.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.services, required this.onChanged});

  final AppServices services;
  final VoidCallback onChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _changeFace({required bool fromGallery}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = fromGallery
          ? await widget.services.image.pickPhoto('rostro')
          : await widget.services.image.takePhoto('rostro');
      if (path != null) {
        final analysis = await widget.services.vision.analyzeFace(path);
        await widget.services.storage.saveFace(path, analysis);
        widget.onChanged();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clear() async {
    await widget.services.storage.clearAll();
    widget.onChanged();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OnboardingScreen(services: widget.services)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final face = widget.services.storage.faceImagePath;
    final faceAnalysisStr = widget.services.storage.faceAnalysis;

    Map<String, dynamic>? analysis;
    if (faceAnalysisStr.isNotEmpty) {
      try {
        analysis = jsonDecode(faceAnalysisStr) as Map<String, dynamic>;
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            LinearLoader(visible: _loading),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorStrip(message: _error!),
            ],
            const SizedBox(height: 10),
            Container(
              height: 300,
              decoration: BoxDecoration(border: Border.all(color: AppTheme.darkBrown)),
              child: face == null ? const Icon(Icons.face_outlined, size: 42) : Image.file(File(face), fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SquareActionButton(
                    label: 'Camara',
                    icon: Icons.photo_camera_outlined,
                    onPressed: _loading ? null : () => _changeFace(fromGallery: false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SquareActionButton(
                    label: 'Galeria',
                    icon: Icons.photo_library_outlined,
                    primary: false,
                    onPressed: _loading ? null : () => _changeFace(fromGallery: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SquareActionButton(label: 'Limpiar datos', icon: Icons.delete_outline, primary: false, onPressed: _loading ? null : _clear),
            const SizedBox(height: 14),

            if (analysis != null) ...[
              const Text(
                'ANÁLISIS DE ROSTRO Y ESTILO',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: AppTheme.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (analysis['genero_edad'] != null)
                      _buildDetailRow('Género y edad', analysis['genero_edad'].toString()),
                    if (analysis['color_ojos'] != null)
                      _buildDetailRow('Color de ojos', analysis['color_ojos'].toString()),
                    if (analysis['rasgos_principales'] != null)
                      _buildDetailRow('Rasgos principales', analysis['rasgos_principales'].toString()),
                    if (analysis['observaciones'] != null)
                      _buildDetailRow('Recomendación de estilo', analysis['observaciones'].toString()),
                  ],
                ),
              ),

              // Colors Recommended
              if (analysis['colores_recomendados'] is List) ...[
                const SizedBox(height: 16),
                const Text(
                  'TE QUEDARÍA BIEN ESTOS COLORES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.9),
                ),
                const SizedBox(height: 8),
                _buildColorList(analysis['colores_recomendados'] as List),
              ],

              // Colors to Avoid
              if (analysis['colores_evitar'] is List) ...[
                const SizedBox(height: 16),
                const Text(
                  'EVITAR USAR ESTOS COLORES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.9),
                ),
                const SizedBox(height: 8),
                _buildColorList(analysis['colores_evitar'] as List),
              ],
              const SizedBox(height: 14),
            ] else if (faceAnalysisStr.isNotEmpty) ...[
              const Text(
                'ANÁLISIS DE ROSTRO',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: AppTheme.line)),
                child: Text(faceAnalysisStr, style: const TextStyle(fontSize: 13, height: 1.35)),
              ),
              const SizedBox(height: 14),
            ],

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: AppTheme.line)),
              child: const Text(
                'Los datos se guardan solo en este dispositivo con Hive. Las fotos se copian al directorio local de la app.',
                style: TextStyle(fontSize: 12, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: AppTheme.darkBrown, height: 1.3),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildColorList(List colorsList) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colorsList.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final name = map['nombre']?.toString() ?? 'Color';
        final hexStr = map['hex']?.toString() ?? '#808080';
        Color color = Colors.grey;
        try {
          final cleanHex = hexStr.replaceAll('#', '').trim();
          color = Color(int.parse('FF$cleanHex', radix: 16));
        } catch (_) {}

        return SizedBox(
          width: 70,
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.line, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, height: 1.1, color: AppTheme.darkBrown),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
