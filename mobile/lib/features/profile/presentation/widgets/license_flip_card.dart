import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../generated/app_localizations.dart';

/// Read-only driving license card that flips between the front and back
/// photos with a 3D Y-rotation. Each side degrades independently to a
/// placeholder when it has no media (or the media cannot be fetched).
class LicenseFlipCard extends StatefulWidget {
  const LicenseFlipCard({
    super.key,
    required this.frontMediaId,
    required this.backMediaId,
  });

  final String? frontMediaId;
  final String? backMediaId;

  static const aspectRatio = 3.0 / 2.0;

  @override
  State<LicenseFlipCard> createState() => _LicenseFlipCardState();
}

class _LicenseFlipCardState extends State<LicenseFlipCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _controllerInstance;

  AnimationController get _controller => _controllerInstance ??=
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );

  bool _showFront = true;

  static bool _hasMedia(String? mediaId) => mediaId != null && mediaId.isNotEmpty;

  bool get _flippable =>
      _hasMedia(widget.frontMediaId) || _hasMedia(widget.backMediaId);

  @override
  void dispose() {
    _controllerInstance?.dispose();
    super.dispose();
  }

  void _flip() {
    if (!_flippable || _controller.isAnimating) return;
    _controller.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() => _showFront = !_showFront);
      _controller.value = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.border.defaultColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: LicenseFlipCard.aspectRatio,
        child: _flippable
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _flip,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value;
                    final showFront = t < 0.5 ? _showFront : !_showFront;
                    final angle = t * math.pi;
                    Widget face = showFront
                        ? _buildSide(context, tokens, s, widget.frontMediaId, s.userDetailFront)
                        : _buildSide(context, tokens, s, widget.backMediaId, s.userDetailBack);
                    if (angle > math.pi / 2) {
                      face = Transform(
                        transform: Matrix4.diagonal3Values(-1, 1, 1),
                        child: face,
                      );
                    }
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      alignment: Alignment.center,
                      child: face,
                    );
                  },
                ),
              )
            : _buildSide(
                context,
                tokens,
                s,
                null,
                s.userDetailDrivingLicenseSection,
              ),
      ),
    );
  }

  Widget _buildSide(
    BuildContext context,
    DcoTokens tokens,
    AppLocalizations s,
    String? mediaId,
    String label,
  ) {
    if (!_hasMedia(mediaId)) {
      return _placeholder(context, tokens, label);
    }
    return Consumer(
      builder: (context, ref, _) {
        final urlAsync = ref.watch(mediaUrlProvider(mediaId!));
        return urlAsync.when(
          loading: () => ColoredBox(color: tokens.background.skeleton),
          error: (_, _) => _placeholder(context, tokens, label),
          data: (url) {
            if (url == null || url.isEmpty) {
              return _placeholder(context, tokens, label);
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _placeholder(context, tokens, label),
                ),
                Positioned(
                  top: tokens.space.s2,
                  left: tokens.space.s2,
                  child: _sideChip(context, tokens, label),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sideChip(BuildContext context, DcoTokens tokens, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s2,
        vertical: tokens.space.s1,
      ),
      decoration: BoxDecoration(
        color: tokens.background.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: tokens.text.caption),
      ),
    );
  }

  Widget _placeholder(BuildContext context, DcoTokens tokens, String label) {
    return ColoredBox(
      color: tokens.background.input,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_outlined, size: 40, color: tokens.icon.inactive),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: tokens.text.caption),
          ),
        ],
      ),
    );
  }
}
