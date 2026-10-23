import 'dart:convert';
import 'dart:io';

import 'package:fitpic/models/garment.dart';
import 'package:fitpic/models/weather_info.dart';
import 'package:fitpic/services/groq_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const weather = WeatherInfo(temperature: 24, windSpeed: 5, code: 0,
  description: 'Despejado', tempIn3Hours: 24, descIn3Hours: 'Despejado', hourlyForecast: [], cityName: 'Quito');
final garments = [
  for (final entry in {'shirt': 'Camisa', 'pants': 'Pantalón', 'shoes': 'Calzado'}.entries)
    Garment(id: entry.key, name: entry.value, category: entry.value, color: 'Negro',
      material: 'Algodón', season: 'Todo clima', imagePath: ''),
];

void main() {
  test('outfits with invented garment IDs are rejected', () async {
    dotenv.testLoad(fileInput: 'GROQ_API_KEY=test');
    final service = GroqService(client: MockClient((request) async {
      expect(jsonDecode(request.body)['model'], 'openai/gpt-oss-20b');
      return http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode({
        'outfits': [
          {'id': 'valid', 'prendas': [{'id': 'shirt'}]},
          {'id': 'invented', 'prendas': [{'id': 'missing'}]},
        ],
      })}}]}), 200);
    }));
    final outfits = await service.generateOutfits(faceAnalysis: '', weather: weather, garments: garments);
    expect(outfits.map((o) => o.id), ['valid']);
  });

  test('live outfit generation uses only saved garment IDs', () async {
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());
    final outfits = await GroqService().generateOutfits(faceAnalysis: '', weather: weather, garments: garments);
    expect(outfits, isNotEmpty);
    for (final outfit in outfits) {
      expect(outfit.items.map((item) => item.id).toSet(), {'shirt', 'pants', 'shoes'});
    }
  }, skip: Platform.environment['FITPIC_LIVE_AI'] != '1', timeout: const Timeout(Duration(seconds: 45)));
}
