import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/garment.dart';
import '../models/outfit.dart';
import '../models/weather_info.dart';

class GroqService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const _model = 'llama-3.3-70b-versatile';

  static const outfitPrompt = '''
Eres un estilista personal de élite. Crea exactamente 4 outfits completos usando TODAS las prendas disponibles del armario.

REGLAS OBLIGATORIAS:
1. Puedes y DEBES mezclar libremente cualquier prenda del armario con cualquier otra, sin importar el orden en que fueron añadidas.
2. Cada outfit DEBE incluir obligatoriamente prendas para:
   - "arriba": Camisa, camiseta o polo
   - "abajo": Pantalón, vaquero, falda o short
   - "calzado": Zapatillas, zapatos o botas
   - Si hace frío (< 20°C) o es de noche/madrugada, INCLUYE obligatoriamente una cuarta prenda de "abrigo" (saco, chaqueta, blazer, abrigo).
3. Varía las combinaciones entre los 4 outfits para maximizar las posibilidades de todo el armario.
4. Incluye accesorios recomendados para elevar el look (reloj, gafas de sol, anillos, cinturón, corbata, pulsera).
5. Adapta las combinaciones de colores según los tonos de piel/rostro analizados.
6. Usa los IDs EXACTOS de las prendas tal como aparecen en la lista de prendas disponibles.

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
        {"id": "...", "nombre": "...", "como_usarla": "...", "tipo": "abajo"},
        {"id": "...", "nombre": "...", "como_usarla": "...", "tipo": "calzado"},
        {"id": "...", "nombre": "...", "como_usarla": "...", "tipo": "abrigo"}
      ],
      "accesorios": "Reloj con correa de cuero, gafas de sol de marco negro, cinturón a juego",
      "descripcion_visual": "Un look pulcro y estilizado ideal para el clima y la hora...",
      "por_que_funciona": "Combina perfectamente los contrastes fríos/cálidos y resalta tu complexión...",
      "consejo": "Asegúrate de que la camisa quede bien entallada en los hombros."
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
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ($timeOfDay)';

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

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': 'Responde solo JSON valido, sin markdown.'},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.75,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Groq error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content']?.toString() ?? '{}';
    final json = jsonDecode(content) as Map<String, dynamic>;
    return (json['outfits'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Outfit.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _getTimeOfDay(int hour) {
    if (hour >= 6 && hour < 12) return 'Mañana';
    if (hour >= 12 && hour < 19) return 'Tarde';
    if (hour >= 19 && hour < 24) return 'Noche';
    return 'Madrugada';
  }
}
