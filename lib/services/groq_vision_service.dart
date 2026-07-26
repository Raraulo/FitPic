import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/garment.dart';
import 'gemini_service.dart';
import 'image_service.dart';

class GroqVisionService {
  GroqVisionService({GeminiService? gemini, ImageService? imageService})
      : _gemini = gemini ?? GeminiService(),
        _imageService = imageService ?? ImageService();

  final GeminiService _gemini;
  final ImageService _imageService;

  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static String get _model => dotenv.env['GROQ_VISION_MODEL'] ?? 'qwen/qwen3.6-27b';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<Garment>> analyzeWardrobe(String imagePath) async {
    const prompt =
        'Eres un experto en moda. Mira esta imagen y dime QUÉ PRENDA DE ROPA ES.\n'
        'Solo identifica la prenda principal que aparece en la foto.\n'
        'Responde ÚNICAMENTE con un JSON con estos 3 campos:\n'
        '{\n'
        '  "nombre": "nombre exacto (ej: Saco de lana, Jean slim, Camisa de vestir, Camiseta básica, Zapatilla deportiva)",\n'
        '  "color": "color principal (ej: Negro, Blanco, Azul marino, Gris, Beige, Rojo)",\n'
        '  "categoria": "una de: Camiseta, Camisa, Pantalón, Jean, Abrigo, Saco, Calzado, Accesorio"\n'
        '}\n'
        'No agregues explicaciones ni texto fuera del JSON.';

    // ── 1. Groq primero (más rápido) ──────────────────────────────
    if (isConfigured) {
      try {
        final text = await _analyzeImage(imagePath: imagePath, prompt: prompt);
        final result = _parseGarment(text, imagePath);
        if (result != null) return [result];
      } catch (_) {}
    }

    // ── 2. Gemini como respaldo ────────────────────────────────────
    if (_gemini.isConfigured) {
      try {
        final list = await _gemini.analyzeWardrobe(imagePath);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    return [];
  }

  /// Parses a single-garment JSON response into a [Garment], or null if invalid.
  Garment? _parseGarment(String text, String imagePath) {
    final json = _extractJson(text, fallback: {});
    final Map<String, dynamic> item;
    if (json.containsKey('nombre')) {
      item = json;
    } else {
      final list = json['prendas'] as List?;
      if (list == null || list.isEmpty) return null;
      item = Map<String, dynamic>.from(list.first as Map);
    }
    if ((item['nombre'] as String? ?? '').trim().isEmpty) return null;
    final garmentId = 'garment_${DateTime.now().millisecondsSinceEpoch}_0';
    item['id'] = garmentId;
    return Garment.fromJson(item, imagePath: imagePath);
  }


  Future<String> analyzeFace(String imagePath) async {
    if (_gemini.isConfigured) {
      try {
        final analysis = await _gemini.analyzeFace(imagePath);
        if (analysis.isNotEmpty) return analysis;
      } catch (_) {
        // Fallback to Groq
      }
    }

    return _analyzeImage(
      imagePath: imagePath,
      prompt: 'Analiza la foto del rostro para recomendaciones de estilo personal y colorimetría. '
          'Responde estrictamente en formato JSON con la siguiente estructura en español:\n'
          '{\n'
          '  "genero_edad": "ej: Masculino, joven adulto",\n'
          '  "color_ojos": "ej: Ojos marrón oscuro",\n'
          '  "rasgos_principales": "ej: Forma de rostro ovalada, cejas definidas",\n'
          '  "colores_recomendados": [\n'
          '    {"nombre": "Azul marino", "hex": "#1a2a3a"},\n'
          '    {"nombre": "Gris antracita", "hex": "#2c3e50"}\n'
          '  ],\n'
          '  "colores_evitar": [\n'
          '    {"nombre": "Amarillo chillon", "hex": "#f1c40f"}\n'
          '  ],\n'
          '  "observaciones": "Consejos breves sobre cortes de cabello, barba o accesorios que favorecen a sus rasgos."\n'
          '}\n'
          'No identifiques a la persona ni infieras atributos sensibles. No devuelvas ningún texto antes o después del JSON.',
    );
  }

  Future<String> _analyzeImage({required String imagePath, required String prompt}) async {
    if (!isConfigured) {
      throw Exception('Falta GROQ_API_KEY. Pegala en el archivo .env');
    }

    final bytes = await File(imagePath).readAsBytes();
    final mimeType = _detectMimeType(imagePath, bytes);
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': dataUrl}
              }
            ],
          }
        ],
        'temperature': 0.2,
        'max_completion_tokens': 2048,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 429) {
        throw Exception('Limite temporal de Groq alcanzado. Espera 10 segundos y prueba otra vez con una foto mas simple o mas cercana.');
      }
      throw Exception('Groq Vision error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['choices']?[0]?['message']?['content']?.toString() ?? '{}';
  }

  Map<String, dynamic> _extractJson(String raw, {Map<String, dynamic>? fallback}) {
    final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'prendas': decoded};
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          return jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;
        } catch (_) {}
      }
      final arrStart = cleaned.indexOf('[');
      final arrEnd = cleaned.lastIndexOf(']');
      if (arrStart >= 0 && arrEnd > arrStart) {
        try {
          final list = jsonDecode(cleaned.substring(arrStart, arrEnd + 1)) as List;
          return {'prendas': list};
        } catch (_) {}
      }
    }
    if (fallback != null) return fallback;
    throw const FormatException('No se pudo extraer JSON de la respuesta de vision.');
  }

  Future<List<Garment>> _fallbackGarments(String imagePath) async {
    return [];
  }

  String _detectMimeType(String path, List<int> bytes) {
    final lower = path.toLowerCase();
    if (bytes.length > 12) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        return 'image/png';
      }
      if (String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        return 'image/webp';
      }
      final box = String.fromCharCodes(bytes.sublist(4, 12));
      if (box.contains('ftypheic') || box.contains('ftypheix') || box.contains('ftyphevc')) {
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
