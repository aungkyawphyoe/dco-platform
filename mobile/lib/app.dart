import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/dco_theme.dart';

class DcoApp extends ConsumerWidget {
  const DcoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'DCO',
      debugShowCheckedModeBanner: false,
      theme: buildDcoTheme(),
      routerConfig: router,
    );
  }
}
