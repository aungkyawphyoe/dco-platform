import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/entry_preferences.dart';
import '../../../../core/theme/dco_tokens.dart';

class LanguageAction extends ConsumerWidget {
  const LanguageAction({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: 'မြန်မာ / English',
    icon: Icon(Icons.language, color: context.tokens.icon.inactive),
    onSelected: (value) =>
        ref.read(entryPreferencesProvider.notifier).language(value),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'my', child: Text('မြန်မာ')),
      PopupMenuItem(value: 'en', child: Text('English')),
    ],
  );
}
