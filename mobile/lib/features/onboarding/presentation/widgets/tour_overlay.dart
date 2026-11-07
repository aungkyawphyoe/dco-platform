import 'dart:math' as math;

import 'package:dco_mobile/core/onboarding/tour_targets.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/storage/entry_preferences.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_card.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tour_controller.dart';

/// Presents the optional post-login tour above the app shell.
///
/// The offer never covers the screen. Once started, hints point at registered
/// [TourAnchor] controls and fall back to a centred card when a target is not
/// currently laid out (for example while data loads or after a route change).
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({super.key, required this.currentBranch});

  /// Index of the active bottom tab. The automatic offer waits for Garage.
  final int currentBranch;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay> {
  final GlobalKey _overlayKey = GlobalKey(debugLabel: 'tour-overlay');
  Rect? _targetRect;
  Size? _overlaySize;
  TourTarget? _measuredTarget;
  bool _measureScheduled = false;
  String? _offerScheduledFor;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final progress = ref.watch(tourProgressProvider).valueOrNull;
    final tour = ref.watch(tourControllerProvider);
    final activeVehicle = ref.watch(activeVehicleProvider);
    final postAuthRoute = ref.watch(postAuthRouteProvider);
    final driver = ref.watch(driverOrganizationIdProvider) != null;
    final alwaysOffer = ref.watch(alwaysOfferTourProvider);

    final eligible =
        userId != null &&
        (alwaysOffer || progress?.shouldOffer == true) &&
        activeVehicle.hasValue &&
        postAuthRoute == null &&
        widget.currentBranch == 0 &&
        tour.phase == TourPhase.idle;

    if (userId == null) _offerScheduledFor = null;

    final offerKey = userId;
    if (eligible && _offerScheduledFor != offerKey) {
      _offerScheduledFor = offerKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(currentUserIdProvider) != userId ||
            widget.currentBranch != 0 ||
            ref.read(postAuthRouteProvider) != null) {
          _offerScheduledFor = null;
          return;
        }
        final offered = ref
            .read(tourControllerProvider.notifier)
            .offer(tourStepsFor(), automaticFor: userId);
        if (offered && alwaysOffer) {
          debugPrint(
            '[tour] DCO_TOUR_ALWAYS active — offering once this launch',
          );
        }
      });
    }

    if (tour.phase == TourPhase.idle && !eligible) {
      return const SizedBox.shrink();
    }

    if (tour.phase == TourPhase.offered) {
      if (widget.currentBranch != 0) return const SizedBox.shrink();
      return SizedBox.expand(
        key: _overlayKey,
        child: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 92,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: _OfferCard(
                  onNotNow: () =>
                      ref.read(tourControllerProvider.notifier).notNow(),
                  onShowMe: () =>
                      ref.read(tourControllerProvider.notifier).begin(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (tour.phase != TourPhase.running) return const SizedBox.shrink();

    final target = tour.currentTarget;
    if (target != null) _scheduleMeasure(target);

    final size = _overlaySize ?? MediaQuery.sizeOf(context);
    final rect = _effectiveRect(
      _measuredTarget == target ? _targetRect : null,
      size,
    );
    final hasVehicle = activeVehicle.valueOrNull != null;
    final copy = _copyFor(
      context,
      target,
      driver: driver,
      hasVehicle: hasVehicle,
    );

    return SizedBox.expand(
      key: _overlayKey,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          ref.read(tourControllerProvider.notifier).back();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(
                  painter: _TourScrimPainter(
                    rect: rect,
                    scrim: Theme.of(
                      context,
                    ).colorScheme.scrim.withValues(alpha: 0.62),
                    accent: context.tokens.text.accent,
                  ),
                ),
              ),
            ),
            _HintPosition(
              targetRect: rect,
              overlaySize: size,
              child: _TourHintCard(
                step: tour.index + 1,
                total: tour.steps.length,
                title: copy.title,
                body: copy.body,
                onBack: tour.index == 0
                    ? null
                    : () => ref.read(tourControllerProvider.notifier).back(),
                onSkip: () => ref.read(tourControllerProvider.notifier).skip(),
                onNext: () => ref.read(tourControllerProvider.notifier).next(),
                last: tour.index + 1 >= tour.steps.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleMeasure(TourTarget target) {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      _measure(target);
    });
  }

  void _measure(TourTarget target) {
    final overlayBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize) return;

    final targetContext = ref
        .read(tourTargetRegistryProvider)
        .keyFor(target)
        ?.currentContext;
    final targetBox = targetContext?.findRenderObject() as RenderBox?;

    Rect? rect;
    if (targetBox != null && targetBox.attached && targetBox.hasSize) {
      rect =
          overlayBox.globalToLocal(targetBox.localToGlobal(Offset.zero)) &
          targetBox.size;
    }

    final size = overlayBox.size;
    if (rect == _targetRect &&
        size == _overlaySize &&
        target == _measuredTarget) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _targetRect = rect;
      _overlaySize = size;
      _measuredTarget = target;
    });
  }

  /// A target that leaves no usable room for a hint — an empty state filling
  /// the body, for example — is treated as unavailable so the hint centres
  /// instead of covering the control it describes.
  Rect? _effectiveRect(Rect? rect, Size overlay) {
    if (rect == null) return null;
    const margin = 16.0;
    const gap = 12.0;
    if (rect.height > overlay.height * 0.6) return null;
    final below = overlay.height - rect.bottom - gap - margin;
    final above = rect.top - gap - margin;
    if (below < 160 && above < 160) return null;
    return rect;
  }

  ({String title, String body}) _copyFor(
    BuildContext context,
    TourTarget? target, {
    required bool driver,
    required bool hasVehicle,
  }) {
    final s = AppLocalizations.of(context)!;
    switch (target) {
      case TourTarget.vehicle:
        if (driver) {
          return (
            title: s.tourVehicleTitle,
            body: hasVehicle
                ? s.tourVehicleDriverBody
                : s.tourVehicleDriverEmptyBody,
          );
        }
        return (
          title: s.tourVehicleTitle,
          body: hasVehicle ? s.tourVehicleBody : s.tourVehicleEmptyBody,
        );
      case TourTarget.maintenance:
        return (title: s.tourMaintenanceTitle, body: s.tourMaintenanceBody);
      case TourTarget.expenses:
        return (title: s.tourExpensesTitle, body: s.tourExpensesBody);
      case TourTarget.settings:
        return (title: s.tourSettingsTitle, body: s.tourSettingsBody);
      case null:
        return (title: s.tourOfferTitle, body: s.tourOfferBody);
    }
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.onNotNow, required this.onShowMe});

  final VoidCallback onNotNow;
  final VoidCallback onShowMe;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return DcoCard(
      emphasized: true,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s4,
        vertical: tokens.space.s3,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tokens.space.s3,
        runSpacing: tokens.space.s1,
        children: [
          Semantics(
            container: true,
            hint: s.tourOfferBody,
            child: Text(
              s.tourOfferTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.space.s2,
            runSpacing: tokens.space.s1,
            children: [
              TextButton(
                onPressed: onNotNow,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text(s.tourNotNow),
              ),
              FilledButton(
                onPressed: onShowMe,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.button.primary.background,
                  foregroundColor: tokens.text.onAccent,
                ),
                child: Text(s.tourShowMe),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TourHintCard extends StatelessWidget {
  const _TourHintCard({
    required this.step,
    required this.total,
    required this.title,
    required this.body,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
    required this.last,
  });

  final int step;
  final int total;
  final String title;
  final String body;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return DcoCard(
      emphasized: true,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: tokens.space.s2,
                children: [
                  Text(
                    s.tourStepOf(step, total),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  ),
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(s.tourSkip),
                  ),
                ],
              ),
              SizedBox(height: tokens.space.s1),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: tokens.space.s2),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
              SizedBox(height: tokens.space.s4),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: tokens.space.s2,
                runSpacing: tokens.space.s1,
                children: [
                  if (onBack != null)
                    TextButton(
                      onPressed: onBack,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text(s.tourBack),
                    ),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.button.primary.background,
                      foregroundColor: tokens.text.onAccent,
                    ),
                    child: Text(last ? s.tourDone : s.tourNext),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Places the hint below the target when there is room, otherwise above it,
/// and clamps the card to the remaining viewport so large text can scroll.
class _HintPosition extends StatelessWidget {
  const _HintPosition({
    required this.targetRect,
    required this.overlaySize,
    required this.child,
  });

  final Rect? targetRect;
  final Size overlaySize;
  final Widget child;

  static const _margin = 16.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final rect = targetRect;
    if (rect == null) {
      return Positioned(
        left: _margin,
        right: _margin,
        top: _margin,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: overlaySize.height - _margin * 2,
          ),
          child: child,
        ),
      );
    }

    final belowSpace = overlaySize.height - rect.bottom - _gap - _margin;
    final aboveSpace = rect.top - _gap - _margin;
    final placeBelow = belowSpace >= 180 || belowSpace >= aboveSpace;
    final maxHeight = (placeBelow ? belowSpace : aboveSpace)
        .clamp(120.0, math.max(120.0, overlaySize.height - _margin * 2))
        .toDouble();

    if (placeBelow) {
      return Positioned(
        left: _margin,
        right: _margin,
        top: rect.bottom + _gap,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: child,
        ),
      );
    }
    return Positioned(
      left: _margin,
      right: _margin,
      bottom: overlaySize.height - rect.top + _gap,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: child,
      ),
    );
  }
}

class _TourScrimPainter extends CustomPainter {
  const _TourScrimPainter({
    required this.rect,
    required this.scrim,
    required this.accent,
  });

  final Rect? rect;
  final Color scrim;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = rect == null
        ? null
        : (Path()..addRRect(
            RRect.fromRectAndRadius(
              rect!.inflate(6),
              const Radius.circular(14),
            ),
          ));
    final path = hole == null
        ? full
        : Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(path, Paint()..color = scrim);
    if (hole != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect!.inflate(6), const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TourScrimPainter old) =>
      old.rect != rect || old.scrim != scrim || old.accent != accent;
}
