abstract final class AppRoutes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const dashboard = '/dashboard';
  static const garage = '/dashboard/garage';
  static const notifications = '/dashboard/notifications';
  static const maintenance = '/maintenance';
  static const expenses = '/expenses';
  static const documents = '/expenses/documents';
  static const settings = '/settings';

  static const authPaths = {
    welcome,
    login,
    signup,
    forgotPassword,
  };
}
