import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/error_strip.dart';
import '../widgets/linear_loader.dart';
import '../widgets/square_action_button.dart';
import 'app_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _loading = false;
  String? _error;
  String? _wardrobePath;
  String? _facePath;

  @override
  void initState() {
    super.initState();
    _facePath = widget.services.storage.faceImagePath;
    _wardrobePath = widget.services.storage.wardrobeImagePath;
  }

  Future<void> _saveWardrobe(String? path) async {
    if (path == null) return;
    setState(() => _wardrobePath = path);
    await widget.services.storage.saveWardrobeImage(path);
    final garments = await widget.services.vision.analyzeWardrobe(path);
    await widget.services.storage.addGarments(garments);
  }

  Future<void> _saveFace(String? path) async {
    if (path == null) return;
    setState(() => _facePath = path);
    await widget.services.storage.saveFace(path, '');
    final analysis = await widget.services.vision.analyzeFace(path);
    await widget.services.storage.saveFace(path, analysis);
  }

  Future<void> _takeWardrobe() async {
    await _guard(() async {
      final path = await widget.services.image.takePhoto('armario');
      await _saveWardrobe(path);
    });
  }

  Future<void> _pickWardrobe() async {
    await _guard(() async {
      final path = await widget.services.image.pickPhoto('armario');
      await _saveWardrobe(path);
    });
  }

  Future<void> _takeFace() async {
    await _guard(() async {
      final path = await widget.services.image.takePhoto('rostro');
      await _saveFace(path);
    });
  }

  Future<void> _pickFace() async {
    await _guard(() async {
      final path = await widget.services.image.pickPhoto('rostro');
      await _saveFace(path);
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('json_validate_failed') ||
        text.contains('Failed to validate JSON')) {
      return 'La foto quedo guardada, pero la IA no pudo analizarla en JSON. Puedes entrar o intentar otra foto.';
    }
    if (text.contains('Vision error') ||
        text.contains('error') ||
        text.contains('Exception')) {
      return 'La foto quedo guardada, pero el analisis de la IA fallo. Puedes entrar o intentar otra foto.';
    }
    return text;
  }

  void _continue() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AppShell(services: widget.services)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.services.storage.hasOnboarding;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearLoader(visible: false),
              Text('FitPic', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              const Text('Estilista personal local con IA',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 18),
              LinearLoader(visible: _loading, label: 'Preparando tu armario…'),
              if (_error != null) ...[
                const SizedBox(height: 10),
                ErrorStrip(message: _error!),
              ],
              const Spacer(),
              _StepTile(
                title: 'Armario',
                subtitle:
                    _wardrobePath == null ? 'Pendiente' : 'Guardado localmente',
                number: '01',
                imagePath: _wardrobePath,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SquareActionButton(
                      label: 'Camara',
                      icon: Icons.photo_camera_outlined,
                      onPressed: _loading ? null : _takeWardrobe,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SquareActionButton(
                      label: 'Galeria',
                      icon: Icons.photo_library_outlined,
                      primary: false,
                      onPressed: _loading ? null : _pickWardrobe,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StepTile(
                title: 'Rostro',
                subtitle:
                    _facePath == null ? 'Pendiente' : 'Guardado localmente',
                number: '02',
                imagePath: _facePath,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SquareActionButton(
                      label: 'Camara',
                      icon: Icons.face_outlined,
                      onPressed: _loading ? null : _takeFace,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SquareActionButton(
                      label: 'Galeria',
                      icon: Icons.photo_library_outlined,
                      primary: false,
                      onPressed: _loading ? null : _pickFace,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SquareActionButton(
                label: 'Entrar',
                icon: Icons.arrow_forward,
                onPressed: ready && !_loading ? _continue : null,
              ),
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: .04, end: 0),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.title,
    required this.subtitle,
    required this.number,
    this.imagePath,
  });

  final String title;
  final String subtitle;
  final String number;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line)),
      child: Row(
        children: [
          _PhotoPreview(imagePath: imagePath, fallbackText: number),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                Text(subtitle, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.imagePath, required this.fallbackText});

  final String? imagePath;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final imageExists = path != null && File(path).existsSync();

    return SizedBox(
      width: 54,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.line.withValues(alpha: .35),
          border: Border.all(color: AppTheme.line),
        ),
        child: imageExists
            ? ClipRect(
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 180,
                ),
              )
            : Center(
                child: Text(
                  fallbackText,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.mediumBrown),
                ),
              ),
      ),
    );
  }
}
