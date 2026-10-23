import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models/weather_info.dart';
import '../services/news_service.dart';
import '../theme/app_theme.dart';
import '../widgets/square_action_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.services,
    required this.onSuggest,
    required this.onProfile,
  });

  final AppServices services;
  final VoidCallback onSuggest;
  final VoidCallback onProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<WeatherInfo> _weather;
  late Future<List<NewsItem>> _news;

  @override
  void initState() {
    super.initState();
    _weather = _loadWeather();
    _news = widget.services.news.fetchFashionNews();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _weather = _loadWeather();
      _news = widget.services.news.fetchFashionNews();
    });
    // Wait for both to settle (success or error)
    await Future.wait([
      _weather.then((_) {}).catchError((_) {}),
      _news.then((_) {}).catchError((_) {}),
    ]);
  }

  // Intenta usar la ubicación real del dispositivo; si el usuario no da
  // permiso o el GPS está apagado, cae de vuelta a los valores por
  // defecto del servicio (Quito).
  Future<WeatherInfo> _loadWeather() async {
    try {
      final position = await _determinePosition();
      return widget.services.weather.getCurrentWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return widget.services.weather.getCurrentWeather();
    }
  }

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Los servicios de ubicación están desactivados.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado permanentemente.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  }

  @override
  Widget build(BuildContext context) {
    final face = widget.services.storage.faceImagePath;
    final garments = widget.services.storage.garments;
    final saved = widget.services.storage.favoriteOutfits;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('FitPic')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppTheme.darkBrown,
          backgroundColor: AppTheme.canvas,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onProfile,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.line),
                      ),
                      child: face == null
                          ? const Icon(Icons.face_outlined)
                          : Image.file(File(face), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FutureBuilder<WeatherInfo>(
                      future: _weather,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hoy', style: TextStyle(fontSize: 11)),
                              Text('Cargando clima...',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500)),
                            ],
                          );
                        }

                        final info = snapshot.data!;
                        final currentText =
                            '${info.temperature.toStringAsFixed(0)}°C · ${info.description}';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hoy · ${info.cityName}',
                                style: const TextStyle(fontSize: 11)),
                            Text(currentText,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 240.ms).slideX(begin: -.03, end: 0),

              const SizedBox(height: 16),
              FutureBuilder<WeatherInfo>(
                future: _weather,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final info = snapshot.data!;
                  final recommendation = _getWeatherRecommendation(
                      info, widget.services.storage.faceAnalysis);

                  return Column(
                    children: [
                      WeatherLineChart(points: info.hourlyForecast),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.line.withValues(alpha: .3),
                          border: Border.all(color: AppTheme.line),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                size: 16, color: AppTheme.darkBrown),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                recommendation,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.3,
                                    color: AppTheme.darkBrown),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              SquareActionButton(
                  label: 'Crear outfit con IA',
                  icon: Icons.auto_awesome_outlined,
                  onPressed: widget.onSuggest),
              const SizedBox(height: 16),
              _Metric(label: 'Prendas', value: garments.length.toString()),
              const SizedBox(height: 8),
              _Metric(
                  label: 'Outfits guardados', value: saved.length.toString()),
              const SizedBox(height: 16),
              const Text('Últimas sugerencias',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final outfit in saved.take(4))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration:
                      BoxDecoration(border: Border.all(color: AppTheme.line)),
                  child: Text('${outfit.style} · ${outfit.name}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),

              // ── Fashion News ──────────────────────────────────
              const SizedBox(height: 24),
              const Text('Noticias Fashion',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              FutureBuilder<List<NewsItem>>(
                future: _news,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  if (!snap.hasData || snap.data!.isEmpty) {
                    return const Text(
                      'Sin noticias disponibles por ahora.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  }
                  return Column(
                    children: snap.data!
                        .map((item) => _NewsCard(item: item))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeatherRecommendation(WeatherInfo info, String faceAnalysis) {
    final tempNow = info.temperature;
    final profile = faceAnalysis.toLowerCase();
    final profileTail = profile.contains('color') ||
            profile.contains('tono') ||
            profile.contains('piel')
        ? ' Prioriza tonos recomendados en tu perfil y evita colores que apaguen tu rostro.'
        : ' Mantén una paleta limpia cerca del rostro para que el conjunto se vea más profesional.';

    bool isRainingSoon = info.hourlyForecast.any((p) {
      final desc = p.description.toLowerCase();
      return desc.contains('lluvia') ||
          desc.contains('tormenta') ||
          desc.contains('nieve');
    });

    double minTemp5h = info.hourlyForecast.isNotEmpty
        ? info.hourlyForecast
            .map((p) => p.temperature)
            .reduce((a, b) => a < b ? a : b)
        : tempNow;
    double maxTemp5h = info.hourlyForecast.isNotEmpty
        ? info.hourlyForecast
            .map((p) => p.temperature)
            .reduce((a, b) => a > b ? a : b)
        : tempNow;

    if (isRainingSoon) {
      return 'Se prevé lluvia en las próximas horas. Usa una capa impermeable, calzado cerrado y evita bajos muy largos.$profileTail';
    }
    if (minTemp5h < 12) {
      return 'Hará bastante frío hoy. Construye el look por capas: abrigo protagonista, textura gruesa y un accesorio funcional.$profileTail';
    }
    if (minTemp5h < 18) {
      return 'Clima fresco previsto. Una chaqueta ligera o saco fino te dará estructura sin verte recargado.$profileTail';
    }
    if (maxTemp5h > 26) {
      return 'Día cálido por delante. Elige telas ligeras, siluetas limpias y calzado respirable; el accesorio debe ser mínimo.$profileTail';
    }
    return 'Clima templado y agradable. Ideal para una camisa o camiseta bien ajustada, pantalón limpio y calzado que eleve el conjunto.$profileTail';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final NewsItem item;

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Silently handle
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkBrown.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _launchUrl(item.url),
            splashColor: AppTheme.line.withValues(alpha: 0.2),
            highlightColor: AppTheme.line.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.line.withValues(alpha: 0.5)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.newspaper_rounded,
                                size: 28, color: AppTheme.mediumBrown),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.line.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.line.withValues(alpha: 0.5)),
                      ),
                      child: const Center(
                        child: Icon(Icons.newspaper_rounded,
                            size: 28, color: AppTheme.mediumBrown),
                      ),
                    ),
                  Expanded(
                    child: SizedBox(
                      height: 90,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.mediumBrown.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NOTICIA DE MODA',
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.mediumBrown,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkBrown,
                                height: 1.3,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Leer artículo',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.mediumBrown
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 10,
                                color:
                                    AppTheme.mediumBrown.withValues(alpha: 0.9),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: .04, end: 0);
  }
}

class WeatherLineChart extends StatelessWidget {
  final List<HourlyForecastPoint> points;

  const WeatherLineChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 165,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkBrown.withValues(alpha: .06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 13, color: AppTheme.mediumBrown),
              SizedBox(width: 6),
              Text(
                'PRONÓSTICO PRÓXIMAS HORAS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.mediumBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _LineChartPainter(points: points),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: .05, end: 0);
  }
}

class _LineChartPainter extends CustomPainter {
  final List<HourlyForecastPoint> points;

  _LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final temps = points.map((p) => p.temperature).toList();
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final tempRange = (maxTemp - minTemp) > 1.0 ? (maxTemp - minTemp) : 1.0;

    const double topPadding = 22.0;
    const double bottomPadding = 24.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    const double horizontalPadding = 24.0;
    final chartWidth = size.width - 2 * horizontalPadding;

    final drawnPoints = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = horizontalPadding + (i * chartWidth / (points.length - 1));
      final y = topPadding +
          (chartHeight -
              ((points[i].temperature - minTemp) / tempRange * chartHeight));
      drawnPoints.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(drawnPoints[0].dx, drawnPoints[0].dy);
    for (int i = 0; i < drawnPoints.length - 1; i++) {
      final p0 = drawnPoints[i];
      final p1 = drawnPoints[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(drawnPoints.last.dx, size.height - bottomPadding);
    fillPath.lineTo(drawnPoints.first.dx, size.height - bottomPadding);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.mediumBrown.withValues(alpha: 0.15),
          AppTheme.mediumBrown.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = AppTheme.mediumBrown
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    for (int i = 0; i < points.length; i++) {
      final pt = drawnPoints[i];

      // Temp Label
      final tempPainter = TextPainter(
        text: TextSpan(
          text: '${points[i].temperature.toStringAsFixed(0)}°',
          style: const TextStyle(
            color: AppTheme.darkBrown,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tempPainter.layout();
      tempPainter.paint(
        canvas,
        Offset(pt.dx - tempPainter.width / 2, pt.dy - tempPainter.height - 6),
      );

      // Time Label
      final timePainter = TextPainter(
        text: TextSpan(
          text: points[i].timeLabel,
          style: TextStyle(
            color: AppTheme.mediumBrown.withValues(alpha: 0.7),
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      timePainter.layout();
      timePainter.paint(
        canvas,
        Offset(pt.dx - timePainter.width / 2, size.height - timePainter.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
