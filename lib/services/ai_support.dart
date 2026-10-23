import 'dart:convert';

class AiException implements Exception {
  const AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

AiException aiHttpError(String provider, int status) {
  if (status == 401 || status == 403) {
    return AiException(
        '$provider no tiene acceso. Revisa la clave y los permisos de la API.');
  }
  if (status == 404) {
    return AiException(
        'El modelo de $provider no está disponible. Revisa la configuración.');
  }
  if (status == 429) {
    return AiException(
        '$provider alcanzó su cuota. Puedes completar la prenda manualmente y reintentar después.');
  }
  return AiException(
      '$provider no pudo responder (código $status). Inténtalo de nuevo.');
}

Map<String, dynamic> parseAiObject(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'```(?:json)?'), '').trim();
  try {
    final decoded = jsonDecode(cleaned);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'prendas': decoded};
  } on FormatException {
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
    }
  }
  throw const AiException(
      'La IA devolvió una respuesta incompleta. Inténtalo de nuevo o identifica la prenda manualmente.');
}

String garmentPrompt(String category) => '''
Identifica solamente la prenda principal visible, con nombre y color concretos en español.
La categoría elegida por el usuario es "$category"; úsala como orientación, no inventes ropa.
Si no hay una prenda reconocible, devuelve {"prendas":[]}.
Devuelve solo JSON: {"nombre":"Polo negro", "color":"Negro", "categoria":"Camisa"}.
Categorías: Camisa, Saco, Pantalón, Mono, Accesorio, Calzado.
''';

const facePrompt = '''
Describe solo rasgos visibles útiles para estilo y colorimetría. No identifiques a la persona ni infieras atributos sensibles.
Devuelve solo JSON con: color_ojos, rasgos_principales, colores_recomendados (lista de {nombre,hex}), colores_evitar (lista de {nombre,hex}), observaciones.
Si no hay un rostro visible, devuelve {"error":"No se distingue un rostro. Usa una foto clara y bien iluminada."}.
''';
