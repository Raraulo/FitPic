class HourlyForecastPoint {
  const HourlyForecastPoint({
    required this.timeLabel,
    required this.temperature,
    required this.code,
    required this.description,
  });

  final String timeLabel;
  final double temperature;
  final int code;
  final String description;
}

class WeatherInfo {
  const WeatherInfo({
    required this.temperature,
    required this.windSpeed,
    required this.code,
    required this.description,
    required this.tempIn3Hours,
    required this.descIn3Hours,
    required this.hourly5Hours,
  });

  final double temperature;
  final double windSpeed;
  final int code;
  final String description;
  final double tempIn3Hours;
  final String descIn3Hours;
  final List<HourlyForecastPoint> hourly5Hours;

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    final current = Map<String, dynamic>.from(json['current_weather'] as Map);
    final code = (current['weathercode'] as num?)?.toInt() ?? 0;

    double temp3h = (current['temperature'] as num?)?.toDouble() ?? 0;
    String desc3h = _describe(code);
    final hourlyPoints = <HourlyForecastPoint>[];

    try {
      final hourly = json['hourly'] as Map?;
      if (hourly != null) {
        final times = hourly['time'] as List?;
        final temps = hourly['temperature_2m'] as List?;
        final codes = hourly['weathercode'] as List?;

        if (times != null && temps != null && codes != null) {
          final targetTime = DateTime.now().add(const Duration(hours: 3));
          int bestIndex = -1;
          int minDiffSeconds = 99999999;

          for (int i = 0; i < times.length; i++) {
            final tStr = times[i] as String;
            final dt = DateTime.tryParse(tStr);
            if (dt != null) {
              final diff = (dt.difference(targetTime).inSeconds).abs();
              if (diff < minDiffSeconds) {
                minDiffSeconds = diff;
                bestIndex = i;
              }
            }
          }

          if (bestIndex != -1) {
            temp3h = (temps[bestIndex] as num).toDouble();
            final code3h = (codes[bestIndex] as num).toInt();
            desc3h = _describe(code3h);
          }

          // Parse next 5 hours from current time
          final now = DateTime.now();
          int startIndex = -1;
          int minDiffNow = 99999999;
          for (int i = 0; i < times.length; i++) {
            final tStr = times[i] as String;
            final dt = DateTime.tryParse(tStr);
            if (dt != null) {
              final diff = (dt.difference(now).inSeconds).abs();
              if (diff < minDiffNow) {
                minDiffNow = diff;
                startIndex = i;
              }
            }
          }

          if (startIndex != -1) {
            for (int k = 0; k < 5; k++) {
              final idx = startIndex + k;
              if (idx < times.length) {
                final tStr = times[idx] as String;
                final dt = DateTime.tryParse(tStr) ?? now;
                final hourStr = '${dt.hour.toString().padLeft(2, '0')}:00';
                final temp = (temps[idx] as num).toDouble();
                final codeVal = (codes[idx] as num).toInt();
                hourlyPoints.add(HourlyForecastPoint(
                  timeLabel: hourStr,
                  temperature: temp,
                  code: codeVal,
                  description: _describe(codeVal),
                ));
              }
            }
          }
        }
      }
    } catch (_) {}

    return WeatherInfo(
      temperature: (current['temperature'] as num?)?.toDouble() ?? 0,
      windSpeed: (current['windspeed'] as num?)?.toDouble() ?? 0,
      code: code,
      description: _describe(code),
      tempIn3Hours: temp3h,
      descIn3Hours: desc3h,
      hourly5Hours: hourlyPoints,
    );
  }

  static String _describe(int code) {
    if (code == 0) return 'Despejado';
    if ([1, 2, 3].contains(code)) return 'Nublado';
    if ([45, 48].contains(code)) return 'Niebla';
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code)) return 'Lluvia';
    if ([71, 73, 75, 77, 85, 86].contains(code)) return 'Nieve';
    if ([95, 96, 99].contains(code)) return 'Tormenta';
    return 'Variable';
  }
}
