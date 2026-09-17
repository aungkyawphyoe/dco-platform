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
  static const maintenance = '/maintenance';
  static const maintenancePlan = '/maintenance/plan';
  static const maintenancePlanNew = '/maintenance/plan/new';
  static const maintenanceSuggested = '/maintenance/plan/suggested';
  static String maintenancePlanEdit(String id) => '/maintenance/plan/$id/edit';
  static const maintenanceRegister = '/maintenance/register';
  static String maintenanceRegisterItem(String planItemId) =>
      '/maintenance/register?item=$planItemId';
  static String serviceDetail(String id) => '/maintenance/history/$id';
  static const expenses = '/expenses';
  static const expenseNew = '/expenses/new';
  static String expenseEdit(String id) => '/expenses/$id/edit';
  static const documents = '/expenses/documents';
  static const documentNew = '/expenses/documents/new';
  static String documentEdit(String id) => '/expenses/documents/$id/edit';
  static String documentView(String id) => '/expenses/documents/$id/view';
  static const settings = '/settings';
  static const settingsLocalization = '/settings/localization';
  static const settingsUnits = '/settings/units';
  static const serviceHistory = '/dashboard/services';
  static const dashboardDocuments = '/dashboard/documents';
  static const insurance = '/dashboard/insurance';
  static const parts = '/dashboard/parts';
  static const partNew = '/dashboard/parts/new';
  static String partEdit(String id) => '/dashboard/parts/$id/edit';
  static const fuelLogs = '/dashboard/fuel';
  static const fuelLogNew = '/dashboard/fuel/new';
  static String fuelLogEdit(String id) => '/dashboard/fuel/$id/edit';
  static const fuelTypes = '/dashboard/fuel/types';
  static const fuelTypeNew = '/dashboard/fuel/types/new';
  static String fuelTypeEdit(String id) => '/dashboard/fuel/types/$id/edit';

  // Family
  static const familyCreate = '/settings/family/new';
  static const familyManage = '/settings/family';
  static String familyJoin(String code) => '/settings/family/join/$code';

  // Detail screens (top-level, accessible from any tab)
  static String vehicleDetail(String id) => '/vehicle/$id';
  static String userDetail(String id) => '/user/$id';

  static const authPaths = {welcome, login, signup, forgotPassword};
}
