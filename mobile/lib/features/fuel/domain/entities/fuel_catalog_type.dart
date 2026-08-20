enum FuelCatalogKind {
  liquid,
  electric;

  String get storage => name;

  String get label => switch (this) {
    FuelCatalogKind.liquid => 'Liquid',
    FuelCatalogKind.electric => 'Electric',
  };

  String get defaultUnit => switch (this) {
    FuelCatalogKind.liquid => 'L',
    FuelCatalogKind.electric => 'kWh',
  };

  List<String> get units => switch (this) {
    FuelCatalogKind.liquid => const ['L', 'gal'],
    FuelCatalogKind.electric => const ['kWh'],
  };

  static FuelCatalogKind parse(String value) {
    return FuelCatalogKind.values.firstWhere(
      (kind) => kind.storage == value || kind.name == value,
      orElse: () => throw FormatException('Unknown fuel catalog kind: $value'),
    );
  }
}

class FuelCatalogType {
  const FuelCatalogType({
    required this.id,
    required this.userId,
    required this.name,
    required this.kind,
    required this.unit,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final FuelCatalogKind kind;
  final String unit;
  final DateTime updatedAt;
  final DateTime createdAt;

  String get detailLine => '${kind.label} · $unit';

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'name': name,
    'kind': kind.storage,
    'unit': unit,
  };
}

class FuelCatalogTypeDraft {
  const FuelCatalogTypeDraft({
    required this.name,
    required this.kind,
    required this.unit,
  });

  final String name;
  final FuelCatalogKind kind;
  final String unit;
}
