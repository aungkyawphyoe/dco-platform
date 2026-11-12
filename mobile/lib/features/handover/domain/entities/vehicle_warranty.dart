/// Warranty issued with a showroom-to-personal handover.
///
/// `terms` is the frozen snapshot captured when the handover was completed.
/// It is display-only: the buyer never edits warranty terms on the device.
class VehicleWarranty {
  const VehicleWarranty({
    required this.id,
    required this.vehicleId,
    required this.status,
    required this.terms,
    required this.updatedAt,
    required this.createdAt,
    this.saleDate,
    this.saleMileageKm,
  });

  final String id;
  final String vehicleId;
  final DateTime? saleDate;
  final double? saleMileageKm;
  final String status;
  final Map<String, dynamic> terms;
  final DateTime updatedAt;
  final DateTime createdAt;

  String? get templateId => _string(terms['template_id']);

  String? get name => _string(terms['name']);

  int? get durationYears => _integer(terms['duration_years']);

  double? get mileageLimitKm => _number(terms['mileage_limit_km']);

  String? get exclusions => _string(terms['exclusions']);

  List<String> get coverageCategories =>
      _stringList(terms['coverage_categories']);

  List<WarrantyWorkshop> get approvedWorkshops =>
      terms['approved_workshops'] is List
      ? (terms['approved_workshops'] as List)
            .whereType<Map>()
            .map(
              (row) => WarrantyWorkshop(
                id: _string(row['id']),
                name: _string(row['name']) ?? '',
              ),
            )
            .toList()
      : const [];
}

class WarrantyWorkshop {
  const WarrantyWorkshop({required this.id, required this.name});

  final String? id;
  final String name;
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int? _integer(Object? value) =>
    value is int ? value : (value is num ? value.round() : null);

double? _number(Object? value) => value is num ? value.toDouble() : null;

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().where((item) => item.isNotEmpty).toList()
    : const [];
