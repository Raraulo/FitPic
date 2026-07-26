import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/garment.dart';
import 'image_service.dart';

class GeminiService {
  GeminiService({ImageService? imageService})
      : _imageService = imageService ?? ImageService();

  final ImageService _imageService;

  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get _model => dotenv.env['GEMINI_MODEL'] ?? 'gemini-1.5-flash';
  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<Garment>> analyzeWardrobe(String imagePath) async {
    final text = await _analyzeImage(
      imagePath: imagePath,
      prompt:
          'Eres un experto en moda. Mira esta imagen y dime QUÉ PRENDA DE ROPA ES.\n'
          'Solo identifica la prenda principal que aparece en la foto.\n'
          'Responde ÚNICAMENTE con un JSON con estos 3 campos:\n'
          '{\n'
          '  "nombre": "nombre exacto de la prenda (ej: Saco de lana, Jean slim, Camisa de vestir, Camiseta básica, Zapatilla deportiva)",\n'
          '  "color": "color principal (ej: Negro, Blanco, Azul marino, Gris, Beige, Rojo)",\n'
          '  "categoria": "una de estas categorías exactas: Camiseta, Camisa, Pantalón, Jean, Abrigo, Saco, Calzado, Accesorio"\n'
          '}\n'
          'No agregues explicaciones ni texto fuera del JSON.',
      forceJson: true,
    );

    final json = _extractJsonSafe(text);

    // Accept both a single object or a list wrapped in "prendas"
    final Map<String, dynamic> item;
    if (json.containsKey('nombre')) {
      item = json;
    } else {
      final list = json['prendas'] as List?;
      if (list == null || list.isEmpty) return [];
      item = Map<String, dynamic>.from(list.first as Map);
    }

    final garmentId = 'garment_${DateTime.now().millisecondsSinceEpoch}_0';
    item['id'] = garmentId;
    // Keep the full original photo — no cropping
    return [Garment.fromJson(item, imagePath: imagePath)];
  }

  Future<String> analyzeFace(String imagePath) async {
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
      forceJson: true,
    );
  }

  Future<String> _analyzeImage({required String imagePath, required String prompt, bool forceJson = false}) async {
    if (!isConfigured) {
      throw Exception('Falta GEMINI_API_KEY. Pegala en el archivo .env');
    }

    final bytes = await File(imagePath).readAsBytes();
    final mimeType = _detectMimeType(imagePath, bytes);
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
    );

    final genConfig = <String, dynamic>{
      'temperature': 0.1,
    };
    if (forceJson) {
      genConfig['responseMimeType'] = 'application/json';
    }

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Encode(bytes),
                }
              }
            ]
          }
        ],
        'generationConfig': genConfig,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString() ?? '{}';
  }

  Map<String, dynamic> _extractJsonSafe(String raw) {
    final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'prendas': decoded};
    } catch (_) {}

    // Try to find JSON object
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(cleaned.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // Try to find JSON array
    final arrStart = cleaned.indexOf('[');
    final arrEnd = cleaned.lastIndexOf(']');
    if (arrStart >= 0 && arrEnd > arrStart) {
      try {
        final list = jsonDecode(cleaned.substring(arrStart, arrEnd + 1)) as List;
        return {'prendas': list};
      } catch (_) {}
    }

    return {'prendas': []};
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
