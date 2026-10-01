import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/documents/presentation/screens/document_form_screen.dart';
import '../../features/documents/presentation/screens/document_viewer_screen.dart';
import '../../features/expenses/presentation/screens/expense_form_screen.dart';
import '../../features/fleet/presentation/screens/driver_fuel_log_screen.dart';
import '../../features/fleet/presentation/screens/driver_inspection_screen.dart';
import '../../features/fleet/presentation/screens/driver_report_issue_screen.dart';
import '../../features/fleet/presentation/screens/driver_shift_screen.dart';
import '../../features/fleet/presentation/screens/fleet_assignments_screen.dart';
import '../../features/fleet/presentation/screens/fleet_screen.dart';
import '../../features/fleet/presentation/screens/fleet_vehicle_detail_screen.dart';
import '../../features/fleet/presentation/screens/fleet_vehicle_form_screen.dart';
import '../../features/fleet/presentation/screens/fleet_vehicle_transfer_screen.dart';
import '../../features/fleet/presentation/screens/fleet_warranty_form_screen.dart';
import '../../features/fleet/presentation/screens/fleet_warranty_templates_screen.dart';
import '../../features/fleet/presentation/screens/fleet_work_order_detail_screen.dart';
import '../../features/fleet/presentation/screens/org_management_screen.dart';
import '../../features/fuel/domain/entities/fuel_catalog_type.dart';
import '../../features/fuel/presentation/screens/fuel_log_form_screen.dart';
import '../../features/fuel/presentation/screens/fuel_logs_screen.dart';
import '../../features/fuel/presentation/screens/fuel_type_form_screen.dart';
import '../../features/fuel/presentation/screens/fuel_types_screen.dart';
import '../../features/garage/presentation/screens/garage_home_screen.dart';
import '../../features/garage/presentation/screens/vehicle_form_screen.dart';
import '../../features/insurance/presentation/screens/insurance_screen.dart';
import '../../features/maintenance/domain/entities/service_record.dart';
import '../../features/maintenance/presentation/screens/maintenance_plan_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_success_screen.dart';
import '../../features/maintenance/presentation/screens/plan_item_form_screen.dart';
import '../../features/maintenance/presentation/screens/register_service_screen.dart';
import '../../features/maintenance/presentation/screens/service_detail_screen.dart';
import '../../features/maintenance/presentation/screens/service_history_screen.dart';
import '../../features/maintenance/presentation/screens/suggested_items_screen.dart';
import '../../features/notifications/presentation/screens/notification_feed_screen.dart';
import '../../features/notes/presentation/screens/note_form_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/parts/presentation/screens/part_form_screen.dart';
import '../../features/parts/presentation/screens/parts_screen.dart';
import '../../features/settings/presentation/screens/appearance_screen.dart';
import '../../features/settings/presentation/screens/localization_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/reminders_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/units_formats_screen.dart';
import '../../features/stats/presentation/screens/expense_stats_screen.dart';
import '../../features/stats/presentation/screens/fuel_stats_screen.dart';
import '../../features/stats/presentation/screens/maintenance_stats_screen.dart';
import '../../features/family/presentation/screens/family_setup_screen.dart';
import '../../features/family/presentation/screens/family_management_screen.dart';
import '../../features/family/presentation/screens/car_detail_screen.dart';
import '../../features/family/presentation/screens/user_detail_screen.dart';
import '../../features/sync/presentation/screens/sync_status_screen.dart';
import 'app_shell.dart';
import 'routes.dart';
import 'tab_switchers.dart';

/// Root navigator. Nested screens set [GoRoute.parentNavigatorKey] to this
/// so they cover the tab shell instead of sitting above the bottom bar.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
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
                builder: (context, state) => const GarageTabScreen(),
                routes: [
                  GoRoute(
                    path: 'garage',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const GarageHomeScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => const VehicleFormScreen(),
                      ),
                      GoRoute(
                        path: ':vehicleId/edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => VehicleFormScreen(
                          vehicleId: state.pathParameters['vehicleId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const NotificationFeedScreen(),
                  ),
                  GoRoute(
                    path: 'services',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ServiceHistoryScreen(),
                  ),
                  GoRoute(
                    path: 'fuel',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const FuelLogsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => const FuelLogEntryScreen(),
                      ),
                      GoRoute(
                        path: 'types',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => const FuelTypesScreen(),
                        routes: [
                          GoRoute(
                            path: 'new',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) => FuelTypeFormScreen(
                              initialKind: state.extra is FuelCatalogKind
                                  ? state.extra as FuelCatalogKind
                                  : null,
                            ),
                          ),
                          GoRoute(
                            path: ':fuelTypeId/edit',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) => FuelTypeFormScreen(
                              fuelTypeId: state.pathParameters['fuelTypeId'],
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: ':logId/edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => FuelLogEntryScreen(
                          logId: state.pathParameters['logId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.maintenance,
                builder: (context, state) => const MaintenanceTabScreen(),
                routes: [
                  GoRoute(
                    path: 'register',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => RegisterServiceScreen(
                      preselectedPlanItemId: state.uri.queryParameters['item'],
                    ),
                  ),
                  GoRoute(
                    path: 'success',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => MaintenanceSuccessScreen(
                      record: state.extra! as ServiceRecord,
                    ),
                  ),
                  GoRoute(
                    path: 'history/:serviceId',
                    parentNavigatorKey: rootNavigatorKey,
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
                builder: (context, state) => const ExpensesTabScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ExpenseFormScreen(),
                  ),
                  GoRoute(
                    path: ':expenseId/edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ExpenseFormScreen(
                      expenseId: state.pathParameters['expenseId'],
                    ),
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
                routes: [
                  GoRoute(
                    path: 'profile',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'localization',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const LocalizationScreen(),
                  ),
                  GoRoute(
                    path: 'units',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const UnitsFormatsScreen(),
                  ),
                  GoRoute(
                    path: 'reminders',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const RemindersScreen(),
                  ),
                  GoRoute(
                    path: 'appearance',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AppearanceScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Drawer routes (top-level, overlay shell) ──

      // Documents
      GoRoute(
        path: AppRoutes.documents,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DocumentsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const DocumentFormScreen(),
          ),
          GoRoute(
            path: ':documentId/edit',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => DocumentFormScreen(
              documentId: state.pathParameters['documentId'],
            ),
          ),
          GoRoute(
            path: ':documentId/view',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => DocumentViewerScreen(
              documentId: state.pathParameters['documentId']!,
            ),
          ),
        ],
      ),

      // Parts
      GoRoute(
        path: AppRoutes.parts,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PartsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const PartFormScreen(),
          ),
          GoRoute(
            path: ':partId/edit',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                PartFormScreen(partId: state.pathParameters['partId']),
          ),
        ],
      ),

      // Notes (local-only notebook)
      GoRoute(
        path: AppRoutes.notes,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const NoteFormScreen(),
          ),
          GoRoute(
            path: ':noteId',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                NoteFormScreen(noteId: state.pathParameters['noteId']),
          ),
        ],
      ),

      // Maintenance Plan
      GoRoute(
        path: AppRoutes.maintenancePlan,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => MaintenancePlanScreen(
          showDone: state.uri.queryParameters['registered'] == '1',
        ),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const PlanItemFormScreen(),
          ),
          GoRoute(
            path: 'suggested',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const SuggestedItemsScreen(),
          ),
          GoRoute(
            path: ':planItemId/edit',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => PlanItemFormScreen(
              planItemId: state.pathParameters['planItemId'],
            ),
          ),
        ],
      ),

      // Insurance
      GoRoute(
        path: AppRoutes.insurance,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InsuranceScreen(),
      ),

      // Stats
      GoRoute(
        path: AppRoutes.refuelStats,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FuelStatsScreen(),
      ),
      GoRoute(
        path: AppRoutes.maintenanceStats,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MaintenanceStatsScreen(),
      ),
      GoRoute(
        path: AppRoutes.expenseStats,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ExpenseStatsScreen(),
      ),

      // Sync
      GoRoute(
        path: AppRoutes.sync,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SyncStatusScreen(),
      ),

      // Family
      GoRoute(
        path: AppRoutes.family,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FamilyManagementScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const FamilySetupScreen(),
          ),
          GoRoute(
            path: 'join/:code',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                FamilySetupScreen(joinCode: state.pathParameters['code']!),
          ),
          GoRoute(
            path: 'vehicle/:id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                CarDetailScreen(vehicleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'user/:id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                UserDetailScreen(userId: state.pathParameters['id']!),
          ),
        ],
      ),

      // Fleet
      GoRoute(
        path: AppRoutes.fleet,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FleetScreen(),
        routes: [
          GoRoute(
            path: 'org',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const OrgManagementScreen(),
          ),
          GoRoute(
            path: 'vehicles/new',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const FleetVehicleFormScreen(),
          ),
          GoRoute(
            path: 'vehicles/:vehicleId',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => FleetVehicleDetailScreen(
              vehicleId: state.pathParameters['vehicleId']!,
            ),
            routes: [
              GoRoute(
                path: 'transfer',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => FleetTransferScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'work-orders/:workOrderId',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => FleetWorkOrderDetailScreen(
              workOrderId: state.pathParameters['workOrderId']!,
            ),
          ),
          GoRoute(
            path: 'assignments',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const FleetAssignmentsScreen(),
          ),
          GoRoute(
            path: 'warranty-templates',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const FleetWarrantyTemplatesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const FleetWarrantyFormScreen(),
              ),
            ],
          ),
        ],
      ),

      // Driver flows
      GoRoute(
        path: AppRoutes.driverShift,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DriverShiftScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverReportIssue,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DriverReportIssueScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverFuelLog,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DriverFuelLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverInspectionNew,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DriverInspectionScreen(),
      ),

      // Detail screens
      GoRoute(
        path: AppRoutes.vehicleDetail(':id'),
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            CarDetailScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.userDetail(':id'),
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            UserDetailScreen(userId: state.pathParameters['id']!),
      ),
    ],
  );
});
