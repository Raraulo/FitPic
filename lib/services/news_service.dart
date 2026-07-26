import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Model representing a news article.
class NewsItem {
  final String title;
  final String description;
  final String url;
  final String? imageUrl;

  NewsItem({
    required this.title,
    required this.description,
    required this.url,
    this.imageUrl,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      url: (json['link'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// Service responsible for fetching fashion-related news from newsdata.io.
class NewsService {
  static const _baseUrl = 'https://newsdata.io/api/1/news';

  final String _apiKey;

  NewsService() : _apiKey = dotenv.env['NEWS_API_KEY'] ?? '';

  /// Returns up to [count] fashion news articles.
  /// Returns an empty list on any error so the UI never crashes.
  Future<List<NewsItem>> fetchFashionNews({int count = 3}) async {
    if (_apiKey.isEmpty) return [];

    // Strict fashion-only query in Spanish
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'apikey': _apiKey,
      'q': '"moda" OR "fashion" OR "tendencia" OR "ropa" OR "outfit" OR "estilo" OR "pasarela" OR "coleccion"',
      'language': 'es',
      'category': 'entertainment',
      'size': '10',
    });

    // Keywords that confirm the article is truly about fashion/style
    const fashionKeywords = [
      'moda', 'fashion', 'tendencia', 'ropa', 'outfit', 'estilo',
      'pasarela', 'coleccion', 'diseñador', 'prenda', 'temporada',
      'look', 'vestimenta', 'indumentaria', 'tela', 'accesorio',
    ];

    bool isFashion(NewsItem item) {
      final text = '${item.title} ${item.description}'.toLowerCase();
      return fashionKeywords.any((kw) => text.contains(kw));
    }

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> results =
          (data['results'] as List<dynamic>?) ?? [];

      return results
          .whereType<Map<String, dynamic>>()
          .map(NewsItem.fromJson)
          .where((item) => item.title.isNotEmpty && isFashion(item))
          .take(count)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
