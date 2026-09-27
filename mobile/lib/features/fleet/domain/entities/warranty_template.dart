class WarrantyTemplate {
  const WarrantyTemplate({
    required this.id,
    required this.orgId,
    required this.name,
    required this.durationYears,
    required this.mileageLimitKm,
    required this.coverageCategories,
    required this.exclusions,
    required this.approvedWorkshopIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WarrantyTemplate.fromJson(Map<String, dynamic> json) {
    return WarrantyTemplate(
      id: json['id'] as String,
      orgId: json['org_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      durationYears: (json['duration_years'] as num?)?.toInt() ?? 1,
      mileageLimitKm: (json['mileage_limit_km'] as num?)?.toInt() ?? 0,
      coverageCategories: ((json['coverage_categories'] as List?) ?? const [])
          .cast<String>(),
      exclusions: json['exclusions'] as String?,
      approvedWorkshopIds: ((json['approved_workshop_ids'] as List?) ?? const [])
          .cast<String>(),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final String id;
  final String orgId;
  final String name;
  final int durationYears;
  final int mileageLimitKm;
  final List<String> coverageCategories;
  final String? exclusions;
  final List<String> approvedWorkshopIds;
  final String? createdAt;
  final String? updatedAt;
}
