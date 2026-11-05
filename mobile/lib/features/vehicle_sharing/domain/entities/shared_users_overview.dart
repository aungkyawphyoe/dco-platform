import 'vehicle_share.dart';

class SharedUserVehicle {
  const SharedUserVehicle(this.vehicle, this.share);
  final VehicleSharesDetail vehicle;
  final VehicleShare share;
}

class SharedUsersOverview {
  const SharedUsersOverview({
    required this.vehicles,
    required this.used,
    required this.limit,
    required this.updatedAt,
  });
  final List<VehicleSharesDetail> vehicles;
  final int used;
  final int? limit;
  final DateTime updatedAt;

  int? get remaining => limit == null ? null : (limit! - used).clamp(0, limit!);

  Map<String, List<SharedUserVehicle>> get people {
    final grouped = <String, List<SharedUserVehicle>>{};
    for (final vehicle in vehicles) {
      for (final share in vehicle.activeShares) {
        (grouped[share.userId] ??= []).add(SharedUserVehicle(vehicle, share));
      }
    }
    final entries = grouped.entries.toList()
      ..sort(
        (a, b) => a.value.first.share.label.toLowerCase().compareTo(
          b.value.first.share.label.toLowerCase(),
        ),
      );
    return Map.fromEntries(entries);
  }

  factory SharedUsersOverview.fromJson(Map<String, dynamic> json) {
    final sharing = json['sharing'] as Map<String, dynamic>;
    final limits = sharing['limits'] as Map<String, dynamic>;
    if (!limits.containsKey('total') || sharing['active_shares'] is! int) {
      throw const FormatException('Missing sharing quota');
    }
    return SharedUsersOverview(
      vehicles: (json['vehicles'] as List)
          .map((v) => VehicleSharesDetail.fromJson(v as Map<String, dynamic>))
          .toList(),
      used: sharing['active_shares'] as int,
      limit: limits['total'] as int?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
