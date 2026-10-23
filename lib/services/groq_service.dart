import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'ai_support.dart';
import '../models/garment.dart';
import '../models/outfit.dart';
import '../models/weather_info.dart';

class GroqService {
  GroqService({http.Client? client}) : _client = client;
  final http.Client? _client;

  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static String get _model => dotenv.env['GROQ_MODEL'] ?? 'openai/gpt-oss-20b';

  static const outfitPrompt = '''
Eres un estilista personal de élite. Crea exactamente 4 outfits completos basándote rigurosamente en el ANÁLISIS DE ROSTRO (colorimetría y perfil) y en el CLIMA ACTUAL.

REGLAS OBLIGATORIAS DE SELECCIÓN POR CATEGORÍA DEL ARMARIO:
1. "arriba": Selecciona EXACTAMENTE 1 prenda de la categoría Camisas/Camisetas (Camisa, Camiseta, Polo).
2. "abrigo": Selecciona 1 prenda de la categoría Sacos/Abrigos ÚNICAMENTE SI EL CLIMA O LA TEMPERATURA LO AMERITAN (temperatura < 20°C, clima frío, viento, lluvia o noche). Si el clima es cálido o agradable, NO INCLUYAS NINGÚN ABRIGO O SACO.
3. "abajo": Selecciona EXACTAMENTE 1 prenda de la categoría Pantalones/Jeans (Pantalón, Jean, Vaquero).
4. "accesorio": Si existen prendas de la categoría Accesorios/Gorras en el armario, incluye 1 accesorio.
5. "calzado": Selecciona EXACTAMENTE 1 par de la categoría Zapatos/Calzado (Zapatos, Zapatillas, Calzado).

ORDEN ESTRICTO DE LAS PRENDAS EN LA LISTA:
Las prendas en el arreglo "prendas" DEBEN estar ordenadas exactamente en el orden vertical del Armario:
1. "arriba" (Camisa/Camiseta)
2. "abrigo" (Saco/Chaqueta, solo si el clima lo amerita)
3. "abajo" (Pantalón/Jean)
4. "accesorio" (si aplica)
5. "calzado" (Zapatos/Calzado)

Si hay un Mono o Vestido, puedes elegirlo en lugar de arriba y abajo (tipo "mono"). Nunca inventes prendas de categorias ausentes.

Usa los IDs EXACTOS de las prendas tal como aparecen en la lista de prendas disponibles.

Responde ÚNICAMENTE con JSON válido en este formato exacto:
{
  "outfits": [
    {
      "id": "o1",
      "estilo": "Minimalista",
      "nombre": "Urbano Elegante",
      "pose": "De pie erguido con las manos en los bolsillos",
      "prendas": [
        {"id": "...", "nombre": "...", "como_usarla": "...", "tipo": "arriba"},
        {"id": "...", "nombre": "...", "como_usarla": "...", "tipo": "abrigo"},
        {"id": "...", "nombre": "...", "como_usarla": "...", "tipo": "abajo"},
        {"id": "...", "nombre": "...", "como_usarla": "...", "tipo": "accesorio"},
        {"id": "...", "nombre": "...", "como_usarla": "...", "tipo": "calzado"}
      ],
      "accesorios": "Reloj con correa de cuero, gafas de sol de marco negro",
      "descripcion_visual": "Un look pulcro y estilizado ideal para el clima...",
      "por_que_funciona": "Combina perfectamente con tu perfil y tono de piel...",
      "consejo": "Asegúrate de que la camisa quede bien entallada."
    }
  ]
}
''';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<Outfit>> generateOutfits({
    required String faceAnalysis,
    required WeatherInfo weather,
    required List<Garment> garments,
    List<Outfit>? favoriteOutfits,
    String? selectedOutfitJson,
    DateTime? time,
  }) async {
    if (!isConfigured) {
      throw Exception('Falta GROQ_API_KEY. Pegala en el archivo .env');
    }

    final now = time ?? DateTime.now();
    final timeOfDay = _getTimeOfDay(now.hour);
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ($timeOfDay)';

    // Build a short summary of already-favorited outfit combinations so the AI avoids repeating them
    String favoritesBlock = '';
    if (favoriteOutfits != null && favoriteOutfits.isNotEmpty) {
      final favSummary = favoriteOutfits.map((o) {
        final ids = o.items.map((i) => i.id).join(', ');
        return '- ${o.name} (prendas: $ids)';
      }).join('\n');
      favoritesBlock = '''

COMBINACIONES YA GUARDADAS EN FAVORITOS (NO REPETIR estas combinaciones exactas ni similares, genera outfits con diferentes mezclas):
$favSummary
''';
    }

    final userPrompt = '''
$outfitPrompt

Analisis del rostro:
$faceAnalysis

Momento del día / Hora:
$formattedTime

Clima actual:
Temperatura: ${weather.temperature} C
Viento: ${weather.windSpeed} km/h
Condicion: ${weather.description}

Prendas disponibles:
${jsonEncode(garments.map((garment) => garment.toJson()).toList())}
$favoritesBlock
${selectedOutfitJson == null ? '' : 'Genera 4 variaciones nuevas inspiradas en este outfit elegido, sin repetir la misma combinacion exacta: $selectedOutfitJson'}
''';

    final client = _client ?? http.Client();
    late http.Response response;
    try {
      response = await client
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content': 'Responde solo JSON valido, sin markdown.'
                },
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': 0.75,
              'max_completion_tokens': 4096,
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const AiException(
          'La IA tardo demasiado. Puedes seguir combinando tus prendas manualmente.');
    } finally {
      if (_client == null) client.close();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw aiHttpError('Groq', response.statusCode);
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content =
        data['choices']?[0]?['message']?['content']?.toString() ?? '{}';
    final json = parseAiObject(content);
    return (json['outfits'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Outfit.fromJson(Map<String, dynamic>.from(item)))
        .where((outfit) =>
            outfit.items.isNotEmpty &&
            outfit.items.every((item) => garments.any((g) => g.id == item.id)))
        .toList();
  }

  String _getTimeOfDay(int hour) {
    if (hour >= 6 && hour < 12) return 'Mañana';
    if (hour >= 12 && hour < 19) return 'Tarde';
    if (hour >= 19 && hour < 24) return 'Noche';
    return 'Madrugada';
  }
}
