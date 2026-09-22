abstract final class AppRoutes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const dashboard = '/dashboard';
  static const garage = '/dashboard/garage';
  static const vehicleNew = '/dashboard/garage/new';
  static String vehicleEdit(String id) => '/dashboard/garage/$id/edit';
  static const notifications = '/dashboard/notifications';
  static const serviceHistory = '/dashboard/services';
  static const fuelLogs = '/dashboard/fuel';
  static const fuelLogNew = '/dashboard/fuel/new';
  static String fuelLogEdit(String id) => '/dashboard/fuel/$id/edit';
  static const fuelTypes = '/dashboard/fuel/types';
  static const fuelTypeNew = '/dashboard/fuel/types/new';
  static String fuelTypeEdit(String id) => '/dashboard/fuel/types/$id/edit';

  static const maintenance = '/maintenance';
  static const maintenanceRegister = '/maintenance/register';
  static String maintenanceRegisterItem(String planItemId) =>
      '/maintenance/register?item=$planItemId';
  static String serviceDetail(String id) => '/maintenance/history/$id';

  static const expenses = '/expenses';
  static const expenseNew = '/expenses/new';
  static String expenseEdit(String id) => '/expenses/$id/edit';

  static const settings = '/settings';
  static const settingsProfile = '/settings/profile';
  static const settingsLocalization = '/settings/localization';
  static const settingsUnits = '/settings/units';

  // Drawer routes (top-level, overlay shell)
  static const documents = '/documents';
  static const documentNew = '/documents/new';
  static String documentEdit(String id) => '/documents/$id/edit';
  static String documentView(String id) => '/documents/$id/view';

  static const parts = '/parts';
  static const partNew = '/parts/new';
  static String partEdit(String id) => '/parts/$id/edit';

  static const maintenancePlan = '/maintenance-plan';
  static const maintenancePlanNew = '/maintenance-plan/new';
  static const maintenanceSuggested = '/maintenance-plan/suggested';
  static String maintenancePlanEdit(String id) => '/maintenance-plan/$id/edit';

  static const insurance = '/insurance';

  static const refuelStats = '/refuel-stats';
  static const maintenanceStats = '/maintenance-stats';
  static const expenseStats = '/expense-stats';

  static const sync = '/sync';

  static const family = '/family';
  static const familyNew = '/family/new';
  static String familyJoin(String code) => '/family/join/$code';

  static const fleet = '/fleet';

  // Detail screens (top-level, accessible from any tab)
  static String vehicleDetail(String id) => '/vehicle/$id';
  static String userDetail(String id) => '/user/$id';

  static const authPaths = {welcome, login, signup, forgotPassword};
}
