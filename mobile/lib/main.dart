import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await bootstrap();
  runApp(
    ProviderScope(
      overrides: overrides,
      child: const DcoApp(),
    ),
  );
}
