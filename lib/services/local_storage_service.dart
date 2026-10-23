import 'package:hive_flutter/hive_flutter.dart';

import '../models/garment.dart';
import '../models/outfit.dart';

class LocalStorageService {
  List<Garment>? _garmentsCache;

  static const _appBoxName = 'fitpic_app';
  static const _garmentsBoxName = 'fitpic_garments';
  static const _historyBoxName = 'fitpic_history';
  static const _favoritesBoxName = 'fitpic_favorites';

  Box get _appBox => Hive.box(_appBoxName);
  Box get _garmentsBox => Hive.box(_garmentsBoxName);
  Box get _historyBox => Hive.box(_historyBoxName);
  Box get _favoritesBox => Hive.box(_favoritesBoxName);

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_appBoxName);
    await Hive.openBox(_garmentsBoxName);
    await Hive.openBox(_historyBoxName);
    await Hive.openBox(_favoritesBoxName);
  }

  bool get hasOnboarding => faceImagePath != null && wardrobeImagePath != null;

  String? get faceImagePath => _appBox.get('faceImagePath') as String?;
  String? get wardrobeImagePath => _appBox.get('wardrobeImagePath') as String?;
  String get faceAnalysis => (_appBox.get('faceAnalysis') as String?) ?? '';

  List<Garment> get garments =>
      _garmentsCache ??= List.unmodifiable(_garmentsBox.values
          .whereType<Map>()
          .map((item) => Garment.fromJson(Map<String, dynamic>.from(item)))
          .toList());

  List<Outfit> get historyOutfits => _historyBox.values
      .whereType<Map>()
      .map((item) => Outfit.fromJson(Map<String, dynamic>.from(item)))
      .toList()
      .reversed
      .toList();

  List<Outfit> get favoriteOutfits => _favoritesBox.values
      .whereType<Map>()
      .map((item) => Outfit.fromJson(Map<String, dynamic>.from(item)))
      .toList()
      .reversed
      .toList();

  bool isFavorite(String outfitId) => _favoritesBox.containsKey(outfitId);

  Future<void> saveFavorite(Outfit outfit) =>
      _favoritesBox.put(outfit.id, outfit.toJson());

  Future<void> toggleFavorite(Outfit outfit) async {
    if (isFavorite(outfit.id)) {
      await _favoritesBox.delete(outfit.id);
    } else {
      await _favoritesBox.put(outfit.id, outfit.toJson());
    }
  }

  Future<void> saveHistoryOutfits(List<Outfit> outfits) async {
    for (final outfit in outfits) {
      await _historyBox.put(outfit.id, outfit.toJson());
    }
  }

  Future<void> saveFace(String path, String analysis) async {
    await _appBox.put('faceImagePath', path);
    await _appBox.put('faceAnalysis', analysis);
  }

  Future<void> saveWardrobeImage(String path) =>
      _appBox.put('wardrobeImagePath', path);

  Future<void> addGarments(List<Garment> garments) async {
    try {
      await _garmentsBox.putAll({
        for (final garment in garments) garment.id: garment.toJson(),
      });
    } finally {
      _garmentsCache = null;
    }
  }

  Future<void> deleteGarment(String id) async {
    try {
      await _garmentsBox.delete(id);
    } finally {
      _garmentsCache = null;
    }
  }

  Future<void> clearHistory() => _historyBox.clear();

  Future<void> clearAll() async {
    await _appBox.clear();
    await _garmentsBox.clear();
    _garmentsCache = null;
    await _historyBox.clear();
    await _favoritesBox.clear();
  }
}
