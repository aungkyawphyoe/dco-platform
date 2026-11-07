import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/onboarding/tour_targets.dart';
import '../../../core/providers.dart';
import '../data/repositories/tour_state_repository_impl.dart';
import '../domain/entities/tour_progress.dart';
import '../domain/repositories/tour_state_repository.dart';

/// Testing aid: when true the offer ignores stored progress, so the tour can be
/// exercised on every app launch. On by default in debug builds only; force it
/// with `--dart-define=DCO_TOUR_ALWAYS=true` (or `false` to opt out).
const bool kAlwaysOfferTour = bool.fromEnvironment(
  'DCO_TOUR_ALWAYS',
  defaultValue: kDebugMode,
);

final alwaysOfferTourProvider = Provider<bool>((ref) => kAlwaysOfferTour);

final tourStateRepositoryProvider = Provider<TourStateRepository>((ref) {
  return TourStateRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// Persisted, account-scoped tour progress.
class TourProgressController extends AsyncNotifier<TourProgress> {
  @override
  Future<TourProgress> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null || userId.isEmpty) {
      return const TourProgress.notSeen();
    }
    return ref.watch(tourStateRepositoryProvider).load(userId);
  }

  Future<void> _persist(TourStatus status) async {
    final next = TourProgress(version: kTourVersion, status: status);
    final userId = ref.read(currentUserIdProvider);
    if (userId != null && userId.isNotEmpty) {
      await ref.read(tourStateRepositoryProvider).save(userId, next);
    }
    state = AsyncData(next);
  }

  Future<void> markDismissed() => _persist(TourStatus.dismissed);

  Future<void> markCompleted() => _persist(TourStatus.completed);
}

final tourProgressProvider =
    AsyncNotifierProvider<TourProgressController, TourProgress>(
      TourProgressController.new,
    );

enum TourPhase { idle, offered, running }

class TourState {
  const TourState({
    this.phase = TourPhase.idle,
    this.index = 0,
    this.steps = const [],
  });

  final TourPhase phase;
  final int index;
  final List<TourTarget> steps;

  TourTarget? get currentTarget =>
      index >= 0 && index < steps.length ? steps[index] : null;

  TourState copyWith({TourPhase? phase, int? index, List<TourTarget>? steps}) =>
      TourState(
        phase: phase ?? this.phase,
        index: index ?? this.index,
        steps: steps ?? this.steps,
      );
}

/// The four areas the short tour covers, in order.
///
/// Targets are shared identifiers rather than feature widgets. Presentation
/// adapts wording for Personal and Driver accounts and silently falls back when
/// a target's anchor is unavailable.
List<TourTarget> tourStepsFor() => const [
  TourTarget.vehicle,
  TourTarget.maintenance,
  TourTarget.expenses,
  TourTarget.settings,
];

class TourController extends Notifier<TourState> {
  final _automaticallyOfferedAccounts = <String>{};
  @override
  TourState build() => const TourState();

  bool offer(List<TourTarget> steps, {String? automaticFor}) {
    if (state.phase != TourPhase.idle || steps.isEmpty) return false;
    // Survives overlay remounts, but resets with the app's ProviderScope.
    if (automaticFor != null &&
        !_automaticallyOfferedAccounts.add(automaticFor)) {
      return false;
    }
    state = TourState(phase: TourPhase.offered, steps: steps);
    return true;
  }

  void begin() {
    if (state.phase != TourPhase.offered || state.steps.isEmpty) return;
    state = state.copyWith(phase: TourPhase.running, index: 0);
  }

  void start(List<TourTarget> steps) {
    if (steps.isEmpty) return;
    state = TourState(phase: TourPhase.running, index: 0, steps: steps);
  }

  Future<void> next() async {
    if (state.phase != TourPhase.running) return;
    if (state.index + 1 >= state.steps.length) {
      await complete();
      return;
    }
    state = state.copyWith(index: state.index + 1);
  }

  Future<void> back() async {
    if (state.phase != TourPhase.running) return;
    if (state.index == 0) {
      await skip();
      return;
    }
    state = state.copyWith(index: state.index - 1);
  }

  Future<void> notNow() async {
    state = const TourState();
    await ref.read(tourProgressProvider.notifier).markDismissed();
  }

  Future<void> skip() async {
    if (state.phase == TourPhase.idle) return;
    state = const TourState();
    await ref.read(tourProgressProvider.notifier).markDismissed();
  }

  Future<void> complete() async {
    if (state.phase == TourPhase.idle) return;
    state = const TourState();
    await ref.read(tourProgressProvider.notifier).markCompleted();
  }
}

final tourControllerProvider = NotifierProvider<TourController, TourState>(
  TourController.new,
);
