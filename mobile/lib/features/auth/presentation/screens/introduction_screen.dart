import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/entry_preferences.dart';
import '../../../../core/router/routes.dart';
import '../../../../generated/app_localizations.dart';
import '../widgets/language_action.dart';
import 'welcome_screen.dart';

class IntroductionScreen extends ConsumerStatefulWidget {
  const IntroductionScreen({super.key});
  @override
  ConsumerState<IntroductionScreen> createState() => _IntroductionScreenState();
}

class _IntroductionScreenState extends ConsumerState<IntroductionScreen> {
  int page = -1;
  Future<void> finish([bool login = false]) async {
    await ref.read(entryPreferencesProvider.notifier).complete();
    if (mounted && login) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(entryPreferencesProvider);
    final s = AppLocalizations.of(context)!;
    if (entry.isLoading) return const AuthLoadingScreen();
    if (entry.hasError) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(entryPreferencesProvider),
            child: Text(s.retry),
          ),
        ),
      );
    }
    if (entry.valueOrNull?.completed == true) return const WelcomeScreen();
    final titles = [
      s.introGarageTitle,
      s.introMaintenanceTitle,
      s.introExpensesTitle,
    ];
    final captions = [
      s.introGarageBody,
      s.introMaintenanceBody,
      s.introExpensesBody,
    ];
    return Scaffold(
      appBar: AppBar(
        actions: [
          const LanguageAction(),
          TextButton(
            key: const Key('welcome-sign-in'),
            onPressed: () => finish(true),
            child: Text(s.signIn),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      height: 220,
                      child: CustomPaint(
                        painter: GarageIllustration(
                          page: page,
                          colors: Theme.of(context).colorScheme,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    page < 0 ? s.chooseLanguage : titles[page],
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    page < 0 ? s.languageIntro : captions[page],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  if (page < 0) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'my', label: Text('မြန်မာ')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {entry.valueOrNull?.language ?? 'en'},
                      onSelectionChanged: (v) => ref
                          .read(entryPreferencesProvider.notifier)
                          .language(v.first),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Semantics(
                      label: '${page + 1} / 3',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => Padding(
                            padding: const EdgeInsets.all(5),
                            child: Icon(
                              i == page
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  FilledButton(
                    onPressed: () =>
                        page == 2 ? finish() : setState(() => page++),
                    child: Text(page == 2 ? s.authGetStarted : s.authNext),
                  ),
                  if (page >= 0)
                    TextButton(onPressed: finish, child: Text(s.authSkip)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Original code-drawn artwork; text stays in localized widgets.
class GarageIllustration extends CustomPainter {
  GarageIllustration({required this.page, required this.colors});
  final int page;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate((size.width - 280) / 2, (size.height - 200) / 2);
    final fill = Paint()..color = colors.surfaceContainerHighest;
    final line = Paint()
      ..color = colors.onSurfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 5, 260, 185),
        const Radius.circular(28),
      ),
      fill,
    );
    canvas.drawLine(const Offset(25, 166), const Offset(255, 166), line);
    if (page <= 0) {
      canvas.drawPath(
        Path()
          ..moveTo(44, 130)
          ..lineTo(61, 92)
          ..lineTo(93, 72)
          ..lineTo(174, 72)
          ..lineTo(205, 110)
          ..lineTo(235, 120)
          ..lineTo(235, 148)
          ..lineTo(44, 148)
          ..close(),
        line,
      );
      canvas.drawLine(const Offset(104, 78), const Offset(90, 110), line);
      canvas.drawLine(const Offset(90, 110), const Offset(193, 110), line);
      for (final x in [80.0, 199.0]) {
        canvas.drawCircle(Offset(x, 148), 17, Paint()..color = colors.surface);
        canvas.drawCircle(Offset(x, 148), 17, line);
        canvas.drawCircle(Offset(x, 148), 6, line);
      }
    } else if (page == 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(58, 36, 164, 123),
          const Radius.circular(12),
        ),
        line,
      );
      canvas.drawLine(const Offset(58, 72), const Offset(222, 72), line);
      for (final x in [90.0, 190.0]) {
        canvas.drawLine(Offset(x, 24), Offset(x, 48), line);
      }
      canvas.drawPath(
        Path()
          ..moveTo(108, 111)
          ..lineTo(132, 132)
          ..lineTo(177, 91),
        line..strokeWidth = 5,
      );
    } else {
      for (var i = 0; i < 4; i++) {
        final height = [35.0, 72.0, 54.0, 105.0][i];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(48 + i * 49, 155 - height, 28, height),
            const Radius.circular(6),
          ),
          line,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GarageIllustration old) =>
      old.page != page || old.colors != colors;
}
