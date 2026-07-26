import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/app_shell.dart';
import 'services/groq_service.dart';
import 'services/groq_vision_service.dart';
import 'services/image_service.dart';
import 'services/weather_service.dart';
import 'services/local_storage_service.dart';
import 'services/news_service.dart';
import 'services/gemini_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final storage = LocalStorageService();
  await storage.init();

  runApp(FitPicApp(storage: storage));
}

class FitPicApp extends StatelessWidget {
  const FitPicApp({super.key, required this.storage});

  final LocalStorageService storage;

  @override
  Widget build(BuildContext context) {
    final services = AppServices(
      storage: storage,
      image: ImageService(),
      vision: GroqVisionService(),
      groq: GroqService(),
      weather: WeatherService(),
      gemini: GeminiService(),
      news: NewsService(),
    );

    return MaterialApp(
      title: 'FitPic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AppShell(services: services),
    );
  }
}

class AppServices {
  const AppServices({
    required this.storage,
    required this.image,
    required this.vision,
    required this.groq,
    required this.weather,
    required this.gemini,
    required this.news,
  });

  final LocalStorageService storage;
  final ImageService image;
  final GroqVisionService vision;
  final GroqService groq;
  final WeatherService weather;
  final GeminiService gemini;
  final NewsService news;
}
