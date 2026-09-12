import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/family/providers.dart';
import 'package:dco_mobile/features/family/presentation/screens/members_tab.dart';
import 'package:dco_mobile/features/family/presentation/screens/vehicles_tab.dart';
import 'package:dco_mobile/features/family/presentation/screens/invite_tab.dart';

class FamilyManagementScreen extends ConsumerStatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  ConsumerState<FamilyManagementScreen> createState() =>
      _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends ConsumerState<FamilyManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showJoinDialog(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.familyManagementJoinTitle),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(
            hintText: s.familyManagementJoinHint,
            labelText: s.familyManagementJoinLabel,
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                context.go(AppRoutes.familyJoin(code));
              }
            },
            child: Text(s.familyManagementJoinButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<DcoTokens>()!;
    final familyAsync = ref.watch(myFamilyProvider);
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.familyManagementTitle),
        bottom: familyAsync.valueOrNull != null
            ? TabBar(
                controller: _tabController,
                labelColor: tokens.text.accent,
                unselectedLabelColor: tokens.text.tertiary,
                indicatorColor: tokens.text.accent,
                tabs: [
                  Tab(icon: const Icon(Icons.people), text: s.familyManagementMembersTab),
                  Tab(icon: const Icon(Icons.directions_car), text: s.familyManagementVehiclesTab),
                  Tab(icon: const Icon(Icons.share), text: s.familyManagementInviteTab),
                ],
              )
            : null,
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (family) {
          if (family == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.space.s3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.family_restroom,
                      size: 64,
                      color: tokens.text.tertiary,
                    ),
                    SizedBox(height: tokens.space.s4),
                    Text(
                      s.familyManagementNoFamily,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: tokens.space.s2),
                    Text(
                      s.familyManagementNoFamilyBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.text.tertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    DcoButton(
                      label: s.familyManagementCreateButton,
                      onPressed: () => context.go('/settings/family/new'),
                    ),
                    const SizedBox(height: 12),
                    DcoButton(
                      label: s.familyManagementJoinFamilyButton,
                      variant: DcoButtonVariant.secondary,
                      onPressed: () => _showJoinDialog(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              MembersTab(family: family, membersAsync: membersAsync),
              VehiclesTab(family: family),
              InviteTab(family: family),
            ],
          );
        },
      ),
    );
  }
}
