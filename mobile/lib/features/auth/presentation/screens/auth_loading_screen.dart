import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_logo.dart';

class AuthLoadingScreen extends ConsumerWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DcoLogo(size: 96),
            SizedBox(height: tokens.space.s5),
            CircularProgressIndicator(color: tokens.text.accent),
          ],
        ),
      ),
    );
  }
}
