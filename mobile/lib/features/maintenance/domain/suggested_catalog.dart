import '../../garage/domain/entities/vehicle.dart';
import 'entities/plan_item.dart';
import 'entities/suggested_plan_item.dart';

/// Default items created when the owner first builds a maintenance plan.
abstract final class DefaultPlanItems {
  static const mileageUpdate = 'mileage_update';
  static const routine = 'routine';

  static const mileageUpdateName = 'Mileage Update';
  static const routineName = 'Routine';

  static PlanItemDraft mileageUpdateDraft() {
    return const PlanItemDraft(
      name: mileageUpdateName,
      recurring: true,
      intervalDays: 30,
      catalogKey: mileageUpdate,
    );
  }

  static PlanItemDraft routineDraft() {
    return const PlanItemDraft(
      name: routineName,
      recurring: true,
      intervalDays: 365,
      intervalDistance: 10000,
      catalogKey: routine,
    );
  }
}

/// Predefined templates. Engine items are hidden for electric vehicles.
abstract final class SuggestedCatalog {
  static const _allFuels = {
    FuelType.petrol,
    FuelType.electric,
    FuelType.hybridPlugin,
  };
  static const _engine = {FuelType.petrol, FuelType.hybridPlugin};

  static const items = <SuggestedPlanItem>[
    SuggestedPlanItem(
      catalogKey: 'oil_change',
      name: 'Oil Change',
      intervalDays: 365,
      intervalDistance: 15000,
      fuelTypes: _engine,
    ),
    SuggestedPlanItem(
      catalogKey: 'air_filter_cabin',
      name: 'Air Filter (Cabin)',
      intervalDays: 365,
      intervalDistance: 15000,
      fuelTypes: _allFuels,
    ),
    SuggestedPlanItem(
      catalogKey: 'new_tires',
      name: 'New Tires',
      intervalDays: 365 * 5,
      intervalDistance: 50000,
      fuelTypes: _allFuels,
    ),
    SuggestedPlanItem(
      catalogKey: 'brake_change',
      name: 'Brake Change',
      intervalDistance: 30000,
      fuelTypes: _allFuels,
    ),
    SuggestedPlanItem(
      catalogKey: 'brake_fluid',
      name: 'Brake Fluid',
      intervalDays: 365 * 3,
      intervalDistance: 30000,
      fuelTypes: _allFuels,
    ),
    SuggestedPlanItem(
      catalogKey: 'belts',
      name: 'Belts',
      intervalDays: 365 * 5,
      intervalDistance: 80000,
      fuelTypes: _engine,
    ),
    SuggestedPlanItem(
      catalogKey: 'fuel_filter',
      name: 'Fuel Filter',
      intervalDistance: 30000,
      fuelTypes: _engine,
    ),
    SuggestedPlanItem(
      catalogKey: 'wash',
      name: 'Wash',
      intervalDays: 14,
      fuelTypes: _allFuels,
    ),
    SuggestedPlanItem(
      catalogKey: 'battery',
      name: 'Battery',
      intervalDays: 365 * 3,
      intervalDistance: 36000,
      fuelTypes: _allFuels,
    ),
    SuggestedPlanItem(
      catalogKey: 'air_conditioning',
      name: 'Air Conditioning',
      intervalDays: 365,
      fuelTypes: _allFuels,
    ),
    SuggestedPlanItem(
      catalogKey: 'rotate_tires',
      name: 'Rotate Tires',
      intervalDays: 365,
      intervalDistance: 6000,
      fuelTypes: _allFuels,
    ),
  ];

  static List<SuggestedPlanItem> forFuelType(FuelType fuelType) {
    return items.where((item) => item.matches(fuelType)).toList();
  }
}
