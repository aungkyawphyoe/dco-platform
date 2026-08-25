import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/dco_theme.dart';
import 'features/auth/presentation/session_controller.dart';

bool _isOnline(List<ConnectivityResult>? results) {
  if (results == null || results.isEmpty) return true;
  return results.any((result) => result != ConnectivityResult.none);
}

class DcoApp extends ConsumerWidget {
  const DcoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    ref.listen(sessionControllerProvider, (previous, next) {
      final userId = next.valueOrNull?.user.id;
      final previousUserId = previous?.valueOrNull?.user.id;
      if (userId != null && userId != previousUserId) {
        ref.read(syncEngineProvider).syncNow();
        ref.read(profileRepositoryProvider).flushPendingActiveVehicle(userId);
      }
    });

    ref.listen(connectivityProvider, (previous, next) {
      final regained = !_isOnline(previous?.valueOrNull) && _isOnline(next.valueOrNull);
      if (regained) {
        ref.read(syncEngineProvider).requestSync();
      }
    });

    return MaterialApp.router(
      title: 'DCO',
      debugShowCheckedModeBanner: false,
      theme: buildDcoTheme(),
      routerConfig: router,
    );
  }
}
