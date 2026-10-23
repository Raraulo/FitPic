import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_info.dart';

class WeatherService {
  Future<WeatherInfo> getCurrentWeather({
    // Quito, Ecuador
    double latitude = -0.1807,
    double longitude = -78.4678,
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

    String cityName = 'Ubicación Desconocida';
    try {
      final geoUri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude',
      );
      final geoResponse = await http.get(
        geoUri,
        headers: {
          'User-Agent': 'FitPic/1.0 (raul@fitpic.app)',
        },
      ).timeout(const Duration(seconds: 4));

      if (geoResponse.statusCode >= 200 && geoResponse.statusCode < 300) {
        final geoData = jsonDecode(geoResponse.body) as Map<String, dynamic>;
        final address = geoData['address'] as Map<String, dynamic>?;
        if (address != null) {
          final possibleCity = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['suburb'] ??
              address['county'] ??
              address['state'];
          if (possibleCity != null) {
            cityName = possibleCity.toString();
          }
        } else if (geoData['display_name'] != null) {
          cityName = (geoData['display_name'] as String).split(',').first;
        }
      }
    } catch (_) {}

    if (cityName == 'Ubicación Desconocida') {
      if ((latitude - -0.1807).abs() < 0.01 && (longitude - -78.4678).abs() < 0.01) {
        cityName = 'Quito';
      }
    }

    return WeatherInfo.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      cityName: cityName,
    );
  }
}