import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_card.dart';
import '../../../../generated/app_localizations.dart';

final appPackageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Keep the screen usable when there is no browser or a platform failure.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.aboutLinkError)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final info = ref.watch(appPackageInfoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.aboutTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.all(tokens.space.s5),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Image.asset(
                      'assets/branding/autox-logo.png',
                      width: 96,
                      height: 96,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AutoX',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    info.when(
                      data: (value) => Text(
                        s.aboutVersion(value.version, value.buildNumber),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => TextButton(
                        onPressed: () => ref.invalidate(appPackageInfoProvider),
                        child: Text(s.retry),
                      ),
                    ),
                    const SizedBox(height: 32),
                    DcoCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(s.termsOfService),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () =>
                                _open(context, 'https://www.autoxmm.com/terms'),
                          ),
                          ListTile(
                            title: Text(s.privacyPolicy),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () => _open(
                              context,
                              'https://www.autoxmm.com/privacy',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton(
            onPressed: () => _open(context, 'https://www.autoxmm.com'),
            child: const Text('www.autoxmm.com'),
          ),
        ),
      ),
    );
  }
}
