import 'entities/plan_item.dart';

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
