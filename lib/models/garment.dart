class Garment {
  const Garment({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.material,
    required this.season,
    required this.imagePath,
  });

  final String id;
  final String name;
  final String category;
  final String color;
  final String material;
  final String season;
  final String imagePath;

  bool get isValid {
    return !_looksLikePlaceholder(name) &&
        !_looksLikePlaceholder(category) &&
        !_looksLikePlaceholder(color);
  }

  factory Garment.fromJson(Map<String, dynamic> json, {String? imagePath}) {
    return Garment(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['nombre']?.toString() ?? json['name']?.toString() ?? 'Prenda',
      category: json['categoria']?.toString() ?? json['category']?.toString() ?? 'Sin categoria',
      color: json['color']?.toString() ?? 'Neutro',
      material: json['material']?.toString() ?? 'No especificado',
      season: json['temporada']?.toString() ?? json['season']?.toString() ?? 'Todo clima',
      imagePath: imagePath ?? json['imagePath']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': name,
        'categoria': category,
        'color': color,
        'material': material,
        'temporada': season,
        'imagePath': imagePath,
      };

  static bool _looksLikePlaceholder(String value) {
    final cleaned = value.trim().toLowerCase();
    if (cleaned.isEmpty) return true;
    if (cleaned == '...' || cleaned == '…') return true;
    if (cleaned.replaceAll('.', '').trim().isEmpty) return true;
    return false;
  }
}
