import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/entry_preferences.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../generated/app_localizations.dart';
import '../widgets/auth_illustration.dart';
import '../widgets/language_action.dart';
import 'welcome_screen.dart';

const List<String> _onboardingArt = [
  'assets/onboarding/01-car-home.svg',
  'assets/onboarding/02-service-reminders.svg',
  'assets/onboarding/03-spending.svg',
];

class IntroductionScreen extends ConsumerStatefulWidget {
  const IntroductionScreen({super.key});
  @override
  ConsumerState<IntroductionScreen> createState() => _IntroductionScreenState();
}

class _IntroductionScreenState extends ConsumerState<IntroductionScreen> {
  late final PageController _pageController;
  late final ValueNotifier<double> _scroll;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scroll = ValueNotifier<double>(0);
    _pageController.addListener(_trackScroll);
  }

  void _trackScroll() {
    final page = _pageController.page;
    if (page != null) _scroll.value = page;
  }

  @override
  void dispose() {
    _pageController.removeListener(_trackScroll);
    _pageController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    await ref.read(entryPreferencesProvider.notifier).complete();
  }

  void _next() {
    final index = _scroll.value.round();
    if (index >= _onboardingArt.length - 1) {
      finish();
      return;
    }
    final motion = context.tokens.motion;
    final reduce = MediaQuery.disableAnimationsOf(context);
    _pageController.animateToPage(
      index + 1,
      duration: Duration(milliseconds: reduce ? 0 : motion.base),
      curve: Curves.easeOutCubic,
    );
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
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(actions: const [LanguageAction()]),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingArt.length,
                itemBuilder: (context, index) => _OnboardingPage(
                  index: index,
                  asset: _onboardingArt[index],
                  title: titles[index],
                  body: captions[index],
                  scroll: _scroll,
                  reduceMotion: reduce,
                ),
              ),
            ),
            _OnboardingControls(scroll: _scroll, onSkip: finish, onNext: _next),
          ],
        ),
      ),
    );
  }
}

class _OnboardingControls extends StatelessWidget {
  const _OnboardingControls({
    required this.scroll,
    required this.onSkip,
    required this.onNext,
  });

  final ValueNotifier<double> scroll;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s5,
        vertical: tokens.space.s4,
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: scroll,
        builder: (context, page, _) {
          final index = page.round().clamp(0, _onboardingArt.length - 1);
          final last = index == _onboardingArt.length - 1;
          return Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space.s2,
                      ),
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: onSkip,
                    child: Text(
                      s.authSkip,
                      maxLines: 1,
                      style: TextStyle(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Semantics(
                label: '${index + 1} / ${_onboardingArt.length}',
                child: _PageDots(
                  count: _onboardingArt.length,
                  active: index,
                  reduceMotion: reduce,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space.s2,
                      ),
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: onNext,
                    child: Text(
                      last ? s.authGetStarted : s.authNext,
                      maxLines: 1,
                      style: TextStyle(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.active,
    required this.reduceMotion,
  });

  final int count;
  final int active;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space.s1),
            child: AnimatedContainer(
              duration: Duration(
                milliseconds: reduceMotion ? 0 : tokens.motion.fast,
              ),
              curve: Curves.easeOutCubic,
              width: i == active ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == active ? tokens.text.primary : tokens.text.caption,
                borderRadius: BorderRadius.circular(tokens.radius.full),
              ),
            ),
          ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.index,
    required this.asset,
    required this.title,
    required this.body,
    required this.scroll,
    required this.reduceMotion,
  });

  final int index;
  final String asset;
  final String title;
  final String body;
  final ValueNotifier<double> scroll;
  final bool reduceMotion;

  Widget _enter({
    required double from,
    required double to,
    required Duration duration,
    required Widget child,
  }) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Interval(from, to, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final stagger = Duration(milliseconds: tokens.motion.slow);
    return LayoutBuilder(
      builder: (context, constraints) {
        final artWidth = math.min(
          constraints.maxWidth - tokens.space.s5 * 2,
          420.0,
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.space.s5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SizedBox(
                      width: artWidth,
                      child: _enter(
                        from: 0,
                        to: 0.65,
                        duration: stagger,
                        child: _Illustration(
                          asset: asset,
                          index: index,
                          viewportWidth: constraints.maxWidth,
                          scroll: scroll,
                          reduceMotion: reduceMotion,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.space.s6),
                  _enter(
                    from: 0.2,
                    to: 0.8,
                    duration: stagger,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  SizedBox(height: tokens.space.s3),
                  _enter(
                    from: 0.35,
                    to: 1,
                    duration: stagger,
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.text.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.asset,
    required this.index,
    required this.viewportWidth,
    required this.scroll,
    required this.reduceMotion,
  });

  final String asset;
  final int index;
  final double viewportWidth;
  final ValueNotifier<double> scroll;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final art = AuthIllustration(asset: asset);
    if (reduceMotion) return art;
    return ValueListenableBuilder<double>(
      valueListenable: scroll,
      builder: (context, page, child) {
        final delta = (index - page).clamp(-1.0, 1.0);
        return Transform.translate(
          offset: Offset(delta * viewportWidth * 0.35, 0),
          child: Transform.scale(scale: 1 - delta.abs() * 0.06, child: child),
        );
      },
      child: art,
    );
  }
}
