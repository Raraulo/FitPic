import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    _weather = widget.services.weather.getCurrentWeather();
    _news = widget.services.news.fetchFashionNews();
  }

  @override
  Widget build(BuildContext context) {
    final face = widget.services.storage.faceImagePath;
    final garments = widget.services.storage.garments;
    final saved = widget.services.storage.favoriteOutfits;

    return Scaffold(
      appBar: AppBar(title: const Text('FitPic')),
      body: SafeArea(
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
                    decoration: BoxDecoration(border: Border.all(color: AppTheme.darkBrown)),
                    child: face == null ? const Icon(Icons.face_outlined) : Image.file(File(face), fit: BoxFit.cover),
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
                            Text('Cargando clima...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        );
                      }

                      final info = snapshot.data!;
                      final currentText = '${info.temperature.toStringAsFixed(0)}°C · ${info.description}';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hoy', style: TextStyle(fontSize: 11)),
                          Text(currentText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                final recommendation = _getWeatherRecommendation(info);

                return Column(
                  children: [
                    _buildWeatherBarChart(info.hourly5Hours),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.line.withValues(alpha: .3),
                        border: Border.all(color: AppTheme.line),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.darkBrown),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              recommendation,
                              style: const TextStyle(fontSize: 11.5, height: 1.3, color: AppTheme.darkBrown),
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
            SquareActionButton(label: 'Sugerir ropa', icon: Icons.auto_awesome_outlined, onPressed: widget.onSuggest),
            const SizedBox(height: 16),
            _Metric(label: 'Prendas', value: garments.length.toString()),
            const SizedBox(height: 8),
            _Metric(label: 'Outfits guardados', value: saved.length.toString()),
            const SizedBox(height: 16),
            const Text('Últimas sugerencias', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final outfit in saved.take(4))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: AppTheme.line)),
                child: Text('${outfit.style} · ${outfit.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),

            // ── Fashion News ──────────────────────────────────
            const SizedBox(height: 24),
            const Text('Noticias Fashion', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            FutureBuilder<List<NewsItem>>(
              future: _news,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
    );
  }

  Widget _buildWeatherBarChart(List<HourlyForecastPoint> points) {
    if (points.isEmpty) return const SizedBox.shrink();

    final temps = points.map((p) => p.temperature).toList();
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final tempRange = (maxTemp - minTemp) > 2 ? (maxTemp - minTemp) : 2.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRONÓSTICO PRÓXIMAS 5 HORAS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.mediumBrown),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((point) {
              final heightFactor = tempRange == 0 ? 0.6 : 0.2 + 0.8 * ((point.temperature - minTemp) / tempRange);
              final barHeight = 60.0 * heightFactor;

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${point.temperature.toStringAsFixed(0)}°C',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkBrown),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 20,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.darkBrown.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        topRight: Radius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    point.timeLabel,
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    point.description,
                    style: const TextStyle(fontSize: 7, color: AppTheme.mediumBrown),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getWeatherRecommendation(WeatherInfo info) {
    final tempNow = info.temperature;
    final condNow = info.description.toLowerCase();

    bool isRainingSoon = info.hourly5Hours.any((p) {
      final desc = p.description.toLowerCase();
      return desc.contains('lluvia') || desc.contains('tormenta') || desc.contains('nieve');
    });

    double minTemp5h = info.hourly5Hours.isNotEmpty
        ? info.hourly5Hours.map((p) => p.temperature).reduce((a, b) => a < b ? a : b)
        : tempNow;
    double maxTemp5h = info.hourly5Hours.isNotEmpty
        ? info.hourly5Hours.map((p) => p.temperature).reduce((a, b) => a > b ? a : b)
        : tempNow;

    if (isRainingSoon) {
      return 'Se prevé lluvia en las próximas horas. Te recomendamos llevar paraguas o impermeable y calzado impermeable.';
    }
    if (minTemp5h < 12) {
      return 'Hará bastante frío hoy. Se recomienda usar abrigo pesado, bufanda y prendas gruesas del armario.';
    }
    if (minTemp5h < 18) {
      return 'Clima fresco previsto. Una chaqueta ligera, saco o suéter te quedará perfecto.';
    }
    if (maxTemp5h > 26) {
      return 'Día caluroso o templado por delante. Opta por prendas frescas de manga corta y tejidos ligeros.';
    }
    return 'Clima templado y agradable. Ideal para cualquier combinación cómoda de camisa o camiseta y pantalón.';
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
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {}, // could open URL later
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
                child: Image.network(
                  item.imageUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 80, height: 80),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: .04, end: 0);
  }
}

