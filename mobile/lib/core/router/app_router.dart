import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/garage/presentation/screens/garage_home_screen.dart';
import '../../features/garage/presentation/screens/vehicle_form_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_plan_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_screen.dart';
import '../../features/maintenance/presentation/screens/plan_item_form_screen.dart';
import '../../features/maintenance/presentation/screens/register_service_screen.dart';
import '../../features/maintenance/presentation/screens/service_detail_screen.dart';
import '../../features/maintenance/presentation/screens/suggested_items_screen.dart';
import '../../features/notifications/presentation/screens/notification_feed_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;
      final onAuth = AppRoutes.authPaths.contains(location);
      final onSplash = location == AppRoutes.splash;

      if (session.isLoading) {
        return onSplash ? null : AppRoutes.splash;
      }

      final signedIn = session.valueOrNull != null;
      if (!signedIn) {
        if (onAuth) return null;
        return AppRoutes.welcome;
      }
      if (onAuth || onSplash) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const AuthLoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'garage',
                    builder: (context, state) => const GarageHomeScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const VehicleFormScreen(),
                      ),
                      GoRoute(
                        path: ':vehicleId/edit',
                        builder: (context, state) => VehicleFormScreen(
                          vehicleId: state.pathParameters['vehicleId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationFeedScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.maintenance,
                builder: (context, state) => const MaintenanceScreen(),
                routes: [
                  GoRoute(
                    path: 'plan',
                    builder: (context, state) => const MaintenancePlanScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const PlanItemFormScreen(),
                      ),
                      GoRoute(
                        path: 'suggested',
                        builder: (context, state) => const SuggestedItemsScreen(),
                      ),
                      GoRoute(
                        path: ':planItemId/edit',
                        builder: (context, state) => PlanItemFormScreen(
                          planItemId: state.pathParameters['planItemId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'register',
                    builder: (context, state) => RegisterServiceScreen(
                      preselectedPlanItemId: state.uri.queryParameters['item'],
                    ),
                  ),
                  GoRoute(
                    path: 'history/:serviceId',
                    builder: (context, state) => ServiceDetailScreen(
                      serviceId: state.pathParameters['serviceId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.expenses,
                builder: (context, state) => const ExpensesScreen(),
                routes: [
                  GoRoute(
                    path: 'documents',
                    builder: (context, state) => const DocumentsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
