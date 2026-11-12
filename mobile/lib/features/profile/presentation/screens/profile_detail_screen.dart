import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/auth/domain/entities/session.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/entities/user_detail.dart';
import 'package:dco_mobile/features/vehicle_sharing/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';

/// Read-only profile detail: license credentials, profile
/// image with user name, phone number, and address. Editing lives on the
/// profile edit screen (`/profile/edit`), reachable from the app bar.
class ProfileDetailScreen extends ConsumerWidget {
  final String userId;

  const ProfileDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final currentUserId = ref.watch(currentUserIdProvider);
    final isSelf = userId == currentUserId;
    final detailAsync = ref.watch(userDetailProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelf ? s.userDetailProfileTitle : s.userDetailMemberTitle,
        ),
        actions: isSelf
            ? [
                IconButton(
                  icon: Icon(Icons.edit, color: tokens.icon.active),
                  tooltip: s.edit,
                  onPressed: () => context.push(AppRoutes.profileEdit),
                ),
              ]
            : null,
      ),
      body: isSelf
          ? _buildSelfBody(context, ref, s, tokens, detailAsync)
          : _buildMemberBody(context, ref, s, tokens, detailAsync),
    );
  }

  Widget _buildSelfBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations s,
    DcoTokens tokens,
    AsyncValue<UserDetail?> detailAsync,
  ) {
    final sessionAsync = ref.watch(sessionControllerProvider);
    final sessionUser = sessionAsync.valueOrNull?.user;

    if (sessionUser == null) {
      return sessionAsync.hasError
          ? _errorState(
              context,
              s,
              tokens,
              sessionAsync.error ?? s.error,
              () => ref.invalidate(sessionControllerProvider),
            )
          : Center(child: CircularProgressIndicator(color: tokens.text.accent));
    }

    return _buildContent(
      context,
      ref,
      s,
      tokens,
      detailAsync: detailAsync,
      selfUser: sessionUser,
      name: sessionUser.displayName ?? sessionUser.email,
      photoMediaId: sessionUser.profilePhotoMediaId,
      phone: sessionUser.contactPhone,
      email: sessionUser.email,
      address: sessionUser.address,
    );
  }

  Widget _buildMemberBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations s,
    DcoTokens tokens,
    AsyncValue<UserDetail?> detailAsync,
  ) {
    return detailAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: tokens.text.accent)),
      error: (error, _) => _errorState(
        context,
        s,
        tokens,
        error,
        () => ref.invalidate(userDetailProvider(userId)),
      ),
      data: (detail) {
        if (detail == null) {
          return DcoEmptyState(title: s.userDetailNotFound, body: s.error);
        }
        return _buildContent(
          context,
          ref,
          s,
          tokens,
          detailAsync: detailAsync,
          selfUser: null,
          name: detail.displayName ?? detail.email,
          photoMediaId: detail.profilePhotoMediaId,
          phone: detail.contactPhone,
          email: detail.email,
          address: detail.address,
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations s,
    DcoTokens tokens, {
    required AsyncValue<UserDetail?> detailAsync,
    required User? selfUser,
    required String name,
    required String? photoMediaId,
    required String? phone,
    required String? email,
    required String? address,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.space.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((selfUser == null
                  ? null
                  : ref.watch(myDrivingLicenseProvider).valueOrNull)
              case final license?) ...[
            Text(
              s.profileLicenseSection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${s.profileLicenseNumber}: ${license.licenseNumber ?? "—"}'),
            Text(
              '${s.profileLicenseExpiry}: ${license.expiryDate?.toIso8601String().split("T").first ?? "—"}',
            ),
            if (license.expiryDate != null)
              Chip(
                label: Text(switch (license.status.storage) {
                  'expired' => s.userDetailLicenseExpired,
                  'expiring_soon' => s.userDetailLicenseExpiringSoon,
                  _ => s.userDetailLicenseValid,
                }),
              ),
          ],
          SizedBox(height: tokens.space.s4),
          Row(
            children: [
              _ProfileAvatar(
                photoMediaId: photoMediaId,
                name: name,
                radius: 28,
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: tokens.text.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space.s5),
          _contactRow(context, tokens, Icons.phone_outlined, phone ?? '-'),
          if (selfUser == null) ...[
            SizedBox(height: tokens.space.s2),
            _contactRow(context, tokens, Icons.email_outlined, email ?? '-'),
          ],
          SizedBox(height: tokens.space.s2),
          _contactRow(
            context,
            tokens,
            Icons.location_on_outlined,
            address ?? '-',
          ),
          if (selfUser != null) ...[
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(s.profileAccountCode),
              subtitle: Text(s.profileAccountCodeSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.accountCode),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(s.authConnections),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.accountConnections),
            ),

            SizedBox(height: tokens.space.s3),
            Container(
              padding: EdgeInsets.all(tokens.space.s3),
              decoration: BoxDecoration(
                color: tokens.background.card,
                borderRadius: BorderRadius.circular(tokens.radius.lg),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    color: tokens.icon.inactive,
                    size: 20,
                  ),
                  SizedBox(width: tokens.space.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selfUser.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          selfUser.emailVerified
                              ? s.profileEmailVerified
                              : s.profileEmailNotVerified,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: selfUser.emailVerified
                                    ? tokens.status.successFg
                                    : tokens.text.caption,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.space.s3),
            if (selfUser.createdAt != null)
              Text(
                '${s.profileMemberSince} ${DateFormat.yMMMd().format(DateTime.parse(selfUser.createdAt!))}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
              ),
            SizedBox(height: tokens.space.s5),
          ],
        ],
      ),
    );
  }

  Widget _contactRow(
    BuildContext context,
    DcoTokens tokens,
    IconData icon,
    String value,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: tokens.space.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tokens.icon.inactive),
          SizedBox(width: tokens.space.s3),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.text.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(
    BuildContext context,
    AppLocalizations s,
    DcoTokens tokens,
    Object error,
    VoidCallback onRetry,
  ) {
    return DcoEmptyState(
      title: s.error,
      body: error.toString(),
      actionLabel: s.retry,
      onAction: onRetry,
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.photoMediaId,
    required this.name,
    required this.radius,
  });

  final String? photoMediaId;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (photoMediaId == null || photoMediaId!.isEmpty) {
      return DcoAvatar(name: name, radius: radius);
    }
    return Consumer(
      builder: (context, ref, _) {
        final urlAsync = ref.watch(mediaUrlProvider(photoMediaId!));
        return urlAsync.when(
          loading: () => DcoAvatar(name: name, radius: radius),
          error: (_, _) => DcoAvatar(name: name, radius: radius),
          data: (url) {
            if (url == null || url.isEmpty) {
              return DcoAvatar(name: name, radius: radius);
            }
            return ClipOval(
              child: SizedBox(
                width: radius * 2,
                height: radius * 2,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      DcoAvatar(name: name, radius: radius),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
