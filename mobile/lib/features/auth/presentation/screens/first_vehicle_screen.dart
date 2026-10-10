import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/entry_preferences.dart';
import '../../../../generated/app_localizations.dart';
import '../widgets/auth_illustration.dart';

class FirstVehicleScreen extends ConsumerWidget {
  const FirstVehicleScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    void finish(String route) {
      ref.read(newOwnerSetupProvider.notifier).state = false;
      ref.read(postAuthRouteProvider.notifier).state = null;
      context.go(route);
    }

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const AuthIllustration(asset: 'assets/onboarding/01-car-home.svg'),
            const SizedBox(height: 24),
            Text(
              s.authFirstVehicle,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(s.authFirstVehicleBody),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => finish(AppRoutes.vehicleNew),
              child: Text(s.authAddVehicle),
            ),
            TextButton(
              onPressed: () => finish(AppRoutes.dashboard),
              child: Text(s.authLater),
            ),
          ],
        ),
      ),
    );
  }
}
