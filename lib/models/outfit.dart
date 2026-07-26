class Outfit {
  const Outfit({
    required this.id,
    required this.style,
    required this.name,
    required this.pose,
    required this.items,
    required this.accessories,
    required this.visualDescription,
    required this.whyItWorks,
    required this.tip,
  });

  final String id;
  final String style;
  final String name;
  final String pose;
  final List<OutfitItem> items;
  final String accessories;
  final String visualDescription;
  final String whyItWorks;
  final String tip;

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id']?.toString() ?? '',
      style: json['estilo']?.toString() ?? '',
      name: json['nombre']?.toString() ?? '',
      pose: json['pose']?.toString() ?? '',
      items: (json['prendas'] as List? ?? [])
          .whereType<Map>()
          .map((item) => OutfitItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      accessories: json['accesorios']?.toString() ?? json['consejo_accesorios']?.toString() ?? '',
      visualDescription: json['descripcion_visual']?.toString() ?? '',
      whyItWorks: json['por_que_funciona']?.toString() ?? '',
      tip: json['consejo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'estilo': style,
        'nombre': name,
        'pose': pose,
        'prendas': items.map((item) => item.toJson()).toList(),
        'accesorios': accessories,
        'descripcion_visual': visualDescription,
        'por_que_funciona': whyItWorks,
        'consejo': tip,
      };
}

class OutfitItem {
  const OutfitItem({
    required this.id,
    required this.name,
    required this.howToWear,
    this.type,
  });

  final String id;
  final String name;
  final String howToWear;
  final String? type;

  factory OutfitItem.fromJson(Map<String, dynamic> json) {
    return OutfitItem(
      id: json['id']?.toString() ?? '',
      name: json['nombre']?.toString() ?? '',
      howToWear: json['como_usarla']?.toString() ?? '',
      type: json['tipo']?.toString() ?? json['categoria']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': name,
        'como_usarla': howToWear,
        'tipo': type,
      };
}
