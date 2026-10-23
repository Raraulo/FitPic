import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/garment.dart';
import 'ai_support.dart';
import 'image_service.dart';

class GeminiService {
  GeminiService({http.Client? client}) : _client = client;
  final http.Client? _client;
  static const defaultModel = 'gemini-3.5-flash-lite';
  static String get _apiKey => dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<Garment>> analyzeWardrobe(String imagePath) async {
    final data = parseAiObject(
        await analyzeImage(imagePath: imagePath, prompt: garmentPrompt('')));
    final items = data['prendas'] is List ? data['prendas'] as List : [data];
    return items
        .whereType<Map>()
        .where((item) => (item['nombre']?.toString().trim() ?? '').isNotEmpty)
        .map((item) => Garment.fromJson({
              ...Map<String, dynamic>.from(item),
              'id': 'garment_${DateTime.now().microsecondsSinceEpoch}'
            }, imagePath: imagePath))
        .toList();
  }

  Future<String> analyzeFace(String imagePath) =>
      analyzeImage(imagePath: imagePath, prompt: facePrompt);

  Future<String> analyzeImage(
      {required String imagePath, required String prompt}) async {
    if (!isConfigured) throw const AiException('Gemini no está configurado.');
    final bytes = await ImageService.visionBytes(imagePath);
    final configured = dotenv.env['GEMINI_MODEL']?.trim();
    final models = {
      if (configured != null && configured.isNotEmpty) configured,
      defaultModel
    };
    final client = _client ?? http.Client();
    try {
      for (final model in models) {
        final response = await client
            .post(
              Uri.parse(
                  'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _apiKey
              },
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                      {
                        'inline_data': {
                          'mime_type': _detectMimeType(imagePath, bytes),
                          'data': base64Encode(bytes)
                        }
                      }
                    ]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'responseMimeType': 'application/json'
                },
              }),
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 404 && model != models.last) continue;
        if (response.statusCode < 200 || response.statusCode >= 300)
          throw aiHttpError('Gemini', response.statusCode);
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final candidates = data['candidates'] as List? ?? [];
        if (candidates.isEmpty)
          throw const AiException(
              'Gemini no pudo analizar esta foto. Prueba con una imagen más clara.');
        final parts = candidates.first['content']?['parts'] as List? ?? [];
        final text = parts
            .whereType<Map>()
            .where((p) => p['thought'] != true)
            .map((p) => p['text'] ?? '')
            .join();
        if (text.trim().isEmpty)
          throw const AiException('Gemini devolvió una respuesta vacía.');
        return text;
      }
      throw const AiException('No hay un modelo de Gemini disponible.');
    } on TimeoutException {
      throw const AiException(
          'Gemini tardó demasiado. Puedes reintentar o identificar la prenda manualmente.');
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
