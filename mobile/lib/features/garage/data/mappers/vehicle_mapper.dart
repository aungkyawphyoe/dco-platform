import '../../../../core/database/app_database.dart';
import '../../domain/entities/vehicle.dart';

Vehicle vehicleFromDrift(VehicleRecord row) {
  return Vehicle(
    id: row.id,
    userId: row.userId,
    name: row.name,
    nickname: row.nickname,
    make: row.make,
    model: row.model,
    year: row.year,
    licensePlate: row.licensePlate,
    vin: row.vin,
    color: row.color,
    fuelType: FuelType.parse(row.fuelType),
    mileage: row.mileage,
    mileageUnit: MileageUnit.parse(row.mileageUnit),
    purchaseDate: row.purchaseDate,
    purchasePrice: row.purchasePrice,
    photoLocalPath: row.photoLocalPath,
    photoMediaId: row.photoMediaId,
    archived: row.archived,
    archivedAt: row.archivedAt,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}
