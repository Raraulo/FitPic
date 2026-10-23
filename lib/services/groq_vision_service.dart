import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/garment.dart';
import 'ai_support.dart';
import 'gemini_service.dart';
import 'image_service.dart';

class GroqVisionService {
  GroqVisionService(
      {GeminiService? gemini, ImageService? imageService, http.Client? client})
      : _gemini = gemini ?? GeminiService(),
        _imageService = imageService ?? ImageService(),
        _client = client;
  final GeminiService _gemini;
  final ImageService _imageService;
  final http.Client? _client;
  static const defaultModel = 'qwen/qwen3.8-27b';
  static String get _apiKey => dotenv.env['GROQ_API_KEY']?.trim() ?? '';
  bool get isConfigured => _apiKey.isNotEmpty || _gemini.isConfigured;

  Future<List<Garment>> analyzeWardrobe(String imagePath) =>
      analyzeGarmentInCategory(imagePath, '');

  Future<List<Garment>> analyzeGarmentInCategory(
      String imagePath, String categoryHint) async {
    final data = await _analyze(imagePath, garmentPrompt(categoryHint));
    final items = data['prendas'] is List ? data['prendas'] as List : [data];
    final valid = items.whereType<Map>().where((item) =>
        (item['nombre']?.toString().trim() ?? '').isNotEmpty &&
        (item['color']?.toString().trim() ?? '').isNotEmpty);
    if (valid.isEmpty)
      throw const AiException(
          'No se reconoció una prenda. Prueba una foto con una sola prenda o completa sus datos manualmente.');
    final item = Map<String, dynamic>.from(valid.first);
    final id = 'garment_${DateTime.now().microsecondsSinceEpoch}';
    final path = await _imageService.prepareGarmentImage(imagePath);
    return [
      Garment.fromJson({
        ...item,
        'id': id,
        if (categoryHint.isNotEmpty) 'categoria': categoryHint,
      }, imagePath: path)
    ];
  }

  Future<String> analyzeFace(String imagePath) async {
    final data = await _analyze(imagePath, facePrompt);
    if (data['error'] != null) throw AiException(data['error'].toString());
    if (data['colores_recomendados'] is! List ||
        (data['colores_recomendados'] as List).isEmpty) {
      throw const AiException(
          'No se pudo analizar el rostro. Usa una foto clara y bien iluminada.');
    }
    return jsonEncode(data);
  }

  Future<Map<String, dynamic>> _analyze(String imagePath, String prompt) async {
    final errors = <String>[];
    if (_apiKey.isNotEmpty) {
      try {
        return parseAiObject(await _groqImage(imagePath, prompt));
      } catch (error) {
        errors.add(error is AiException
            ? error.message
            : 'No se pudo conectar con Groq.');
      }
    }
    if (_gemini.isConfigured) {
      try {
        return parseAiObject(
            await _gemini.analyzeImage(imagePath: imagePath, prompt: prompt));
      } catch (error) {
        errors.add(error is AiException
            ? error.message
            : 'No se pudo conectar con Gemini.');
      }
    }
    throw AiException(errors.isEmpty
        ? 'Configura una API de visión para identificar las fotos. También puedes registrar prendas manualmente.'
        : errors.join(' '));
  }

  Future<String> _groqImage(String imagePath, String prompt) async {
    final bytes = await ImageService.visionBytes(imagePath);
    final configured = dotenv.env['GROQ_VISION_MODEL']?.trim();
    final models = {
      if (configured != null && configured.isNotEmpty) configured,
      defaultModel
    };
    final client = _client ?? http.Client();
    try {
      for (final model in models) {
        final response = await client
            .post(
              Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey'
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': prompt},
                      {
                        'type': 'image_url',
                        'image_url': {
                          'url':
                              'data:${_detectMimeType(imagePath, bytes)};base64,${base64Encode(bytes)}'
                        }
                      }
                    ]
                  }
                ],
                'temperature': 0.2,
                'max_completion_tokens': 2048,
                'response_format': {'type': 'json_object'},
              }),
            )
            .timeout(const Duration(seconds: 20));
        if ((response.statusCode == 404 ||
                response.body.contains('model_decommissioned')) &&
            model != models.last) continue;
        if (response.statusCode < 200 || response.statusCode >= 300)
          throw aiHttpError('Groq', response.statusCode);
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final choices = data['choices'] as List? ?? [];
        if (choices.isEmpty)
          throw const AiException('Groq devolvió una respuesta vacía.');
        return choices.first['message']?['content']?.toString() ?? '{}';
      }
      throw const AiException('No hay un modelo de visión disponible.');
    } on TimeoutException {
      throw const AiException('Groq tardó demasiado en analizar la foto.');
    } finally {
      if (_client == null) client.close();
    }
  }

  String _detectMimeType(String path, List<int> bytes) {
    final lower = path.toLowerCase();
    if (bytes.length > 12) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      if (String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        return 'image/webp';
      }
      final box = String.fromCharCodes(bytes.sublist(4, 12));
      if (box.contains('ftypheic') ||
          box.contains('ftypheix') ||
          box.contains('ftyphevc')) {
        return 'image/heic';
      }
      if (box.contains('ftypmif1') || box.contains('ftypmsf1')) {
        return 'image/heif';
      }
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }
}
