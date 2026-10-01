import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/dco_tokens.dart';
import '../../../../generated/app_localizations.dart';

typedef LicensePhotoCaptureCallback = Future<void> Function(String side);

class LicensePhotoCard extends StatelessWidget {
  const LicensePhotoCard({
    super.key,
    required this.frontMediaId,
    required this.backMediaId,
    required this.onCapture,
  });

  final String? frontMediaId;
  final String? backMediaId;
  final LicensePhotoCaptureCallback onCapture;

  static const aspectRatio = 3.0 / 2.0;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.profileLicensePhotos,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 500;
            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: _buildPhotoSlot(
                      context,
                      tokens,
                      s.userDetailFront,
                      frontMediaId,
                      () => onCapture('front'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPhotoSlot(
                      context,
                      tokens,
                      s.userDetailBack,
                      backMediaId,
                      () => onCapture('back'),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _buildPhotoSlot(
                  context,
                  tokens,
                  s.userDetailFront,
                  frontMediaId,
                  () => onCapture('front'),
                ),
                const SizedBox(height: 12),
                _buildPhotoSlot(
                  context,
                  tokens,
                  s.userDetailBack,
                  backMediaId,
                  () => onCapture('back'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhotoSlot(
    BuildContext context,
    DcoTokens tokens,
    String label,
    String? mediaId,
    VoidCallback onTap,
  ) {
    if (mediaId == null || mediaId.isEmpty) {
      return _buildEmptySlot(context, tokens, label, onTap);
    }
    return _buildImageSlot(context, tokens, label, mediaId, onTap);
  }

  Widget _buildEmptySlot(
    BuildContext context,
    DcoTokens tokens,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.background.input,
          borderRadius: BorderRadius.circular(tokens.radius.md),
          border: Border.all(color: tokens.border.defaultColor),
        ),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 32, color: tokens.icon.inactive),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: tokens.text.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSlot(
    BuildContext context,
    DcoTokens tokens,
    String label,
    String mediaId,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.background.input,
          borderRadius: BorderRadius.circular(tokens.radius.md),
          border: Border.all(color: tokens.border.defaultColor),
        ),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radius.md),
            child: Consumer(
              builder: (context, ref, _) {
                final urlAsync = ref.watch(mediaUrlProvider(mediaId));
                return urlAsync.when(
                  loading: () => Container(color: tokens.background.skeleton),
                  error: (_, __) =>
                      _buildEmptySlot(context, tokens, label, onTap),
                  data: (url) {
                    if (url == null || url.isEmpty) {
                      return _buildEmptySlot(context, tokens, label, onTap);
                    }
                    return Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          _buildEmptySlot(context, tokens, label, onTap),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
