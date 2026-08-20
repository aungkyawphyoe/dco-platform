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
  static const documents = '/expenses/documents';
  static const settings = '/settings';
  static const settingsLocalization = '/settings/localization';
  static const settingsUnits = '/settings/units';
  static const serviceHistory = '/dashboard/services';
  static const dashboardDocuments = '/dashboard/documents';
  static const insurance = '/dashboard/insurance';
  static const parts = '/dashboard/parts';
  static const partNew = '/dashboard/parts/new';
  static String partEdit(String id) => '/dashboard/parts/$id/edit';

  static const authPaths = {
    welcome,
    login,
    signup,
    forgotPassword,
  };
}
