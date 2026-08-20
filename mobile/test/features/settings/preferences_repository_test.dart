import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/settings/data/repositories/preferences_repository_impl.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleDraft _vehicleDraft() {
  return const VehicleDraft(
    name: 'Daily',
    make: 'Toyota',
    model: 'Camry',
    year: 2022,
    licensePlate: 'ABC123',
    fuelType: FuelType.petrol,
    mileage: 10000,
  );
}

void main() {
  late AppDatabase db;
  late VehicleRepositoryImpl vehicles;
  late PreferencesRepositoryImpl prefs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vehicles = VehicleRepositoryImpl(db: db, outbox: OutboxWriter(db));
    prefs = PreferencesRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('missing profile returns defaults', () async {
    final loaded = await prefs.get('user-1');
    expect(loaded.language, AppLanguage.english);
    expect(loaded.currency, AppCurrency.usd);
    expect(loaded.lengthUnit, MileageUnit.mi);
  });

  test('save persists language, currency, and length unit', () async {
    const userId = 'user-1';
    const next = UserPreferences(
      language: AppLanguage.myanmar,
      currency: AppCurrency.mmk,
      lengthUnit: MileageUnit.km,
    );

    await prefs.save(userId: userId, preferences: next);

    Future<void> expectSaved(UserPreferences loaded) async {
      expect(loaded.language, next.language);
      expect(loaded.currency, next.currency);
      expect(loaded.lengthUnit, next.lengthUnit);
    }

    await expectSaved(await prefs.get(userId));
    await expectSaved(await prefs.watch(userId).first);
  });

  test('save keeps the active vehicle', () async {
    const userId = 'user-1';
    final vehicle = await vehicles.add(userId: userId, draft: _vehicleDraft());

    await prefs.save(
      userId: userId,
      preferences: const UserPreferences(
        language: AppLanguage.myanmar,
        currency: AppCurrency.mmk,
        lengthUnit: MileageUnit.km,
      ),
    );

    final active = await vehicles.watchActive(userId).first;
    expect(active?.id, vehicle.id);
  });

  test('setActive does not reset saved preferences', () async {
    const userId = 'user-1';
    await vehicles.add(userId: userId, draft: _vehicleDraft());
    const saved = UserPreferences(
      language: AppLanguage.myanmar,
      currency: AppCurrency.mmk,
      lengthUnit: MileageUnit.km,
    );
    await prefs.save(userId: userId, preferences: saved);

    final second = await vehicles.add(
      userId: userId,
      draft: const VehicleDraft(
        name: 'Weekend',
        make: 'Honda',
        model: 'Civic',
        year: 2020,
        licensePlate: 'XYZ789',
        fuelType: FuelType.petrol,
        mileage: 2000,
      ),
    );
    await vehicles.setActive(userId: userId, vehicleId: second.id);

    final loaded = await prefs.get(userId);
    expect(loaded.language, saved.language);
    expect(loaded.currency, saved.currency);
    expect(loaded.lengthUnit, saved.lengthUnit);
  });
}
