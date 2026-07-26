import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_info.dart';

class WeatherService {
  Future<WeatherInfo> getCurrentWeather({
    double latitude = -2.170998,
    double longitude = -79.922356,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current_weather': 'true',
      'hourly': 'temperature_2m,weathercode',
      'timezone': 'auto',
    });

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Open-Meteo error ${response.statusCode}');
    }

    return WeatherInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
