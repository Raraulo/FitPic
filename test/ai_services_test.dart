import 'dart:convert';
import 'dart:io';

import 'package:fitpic/services/ai_support.dart';
import 'package:fitpic/services/gemini_service.dart';
import 'package:fitpic/services/groq_vision_service.dart';
import 'package:fitpic/services/image_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class PassthroughImages extends ImageService {
  @override
  Future<String> prepareGarmentImage(String sourcePath) async => sourcePath;
}

http.Response groqReply(Map<String, dynamic> content) => http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {'content': jsonEncode(content)}
        }
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() => dotenv.testLoad(
      fileInput:
          'GROQ_API_KEY=test\nGROQ_VISION_MODEL=old-model\nGEMINI_API_KEY='));

  test(
      'retired vision model retries current model and preserves selected category',
      () async {
    final models = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body);
      models.add(body['model'] as String);
      if (models.length == 1)
        return http.Response('{"error":{"code":"model_not_found"}}', 404);
      return groqReply(
          {'nombre': 'Polo negro', 'color': 'Negro', 'categoria': 'Camiseta'});
    });
    final result = await GroqVisionService(
            client: client, imageService: PassthroughImages())
        .analyzeGarmentInCategory('assets/ropa/camisa.png', 'Camisa');
    expect(models, ['old-model', GroqVisionService.defaultModel]);
    expect(result.single.name, 'Polo negro');
    expect(result.single.category, 'Camisa');
    expect(result.single.imagePath, 'assets/ropa/camisa.png');
  });

  test('Gemini takes over when Groq has no quota', () async {
    dotenv.testLoad(fileInput: 'GROQ_API_KEY=test\nGEMINI_API_KEY=test');
    final gemini = GeminiService(client: MockClient((request) async {
      expect(request.headers['x-goog-api-key'], 'test');
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'nombre': 'Zapatos beige',
                        'color': 'Beige',
                        'categoria': 'Calzado'
                      })
                    }
                  ]
                }
              }
            ]
          }),
          200);
    }));
    final result = await GroqVisionService(
            gemini: gemini,
            imageService: PassthroughImages(),
            client: MockClient((_) async => http.Response('{}', 429)))
        .analyzeGarmentInCategory('assets/ropa/zapatos.png', 'Calzado');
    expect(result.single.name, 'Zapatos beige');
  });

  test('unrecognizable photos never become invented garments', () async {
    final service = GroqVisionService(
        imageService: PassthroughImages(),
        client: MockClient((_) async => groqReply({'prendas': []})));
    await expectLater(service.analyzeWardrobe('assets/ropa/camisa.png'),
        throwsA(isA<AiException>()));
  });

  test('provider errors are actionable and do not leak raw responses',
      () async {
    final service = GroqVisionService(
        client: MockClient(
            (_) async => http.Response('private server details', 401)));
    await expectLater(
        service.analyzeFace('assets/ropa/camisa.png'),
        throwsA(isA<AiException>().having((e) => e.message, 'message',
            allOf(contains('clave'), isNot(contains('private'))))));
  });

  test('profile analysis uses the same working vision route', () async {
    final service = GroqVisionService(
        client: MockClient((_) async => groqReply({
              'rasgos_principales': 'Rostro ovalado',
              'colores_recomendados': [
                {'nombre': 'Azul', 'hex': '#0011FF'}
              ],
            })));
    expect(
        jsonDecode(await service.analyzeFace('assets/ropa/camisa.png'))[
            'colores_recomendados'],
        isNotEmpty);
  });

  test('live providers recognize project sample garments', () async {
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());
    final vision = GroqVisionService(imageService: PassthroughImages());
    final shirt = await vision.analyzeGarmentInCategory(
        'assets/ropa/camisa.png', 'Camisa');
    expect(shirt.single.name.toLowerCase(),
        anyOf(contains('polo'), contains('camis')));
    final shoes =
        await GeminiService().analyzeWardrobe('assets/ropa/zapatos.png');
    expect(shoes.single.name.toLowerCase(),
        anyOf(contains('zapat'), contains('calzado'), contains('tenis')));
  },
      skip: Platform.environment['FITPIC_LIVE_AI'] != '1',
      timeout: const Timeout(Duration(seconds: 90)));
}
