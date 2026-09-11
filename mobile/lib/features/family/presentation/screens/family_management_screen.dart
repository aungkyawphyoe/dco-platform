import 'package:dco_mobile/core/router/routes.dart';
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
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Family'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: 'Enter share code',
            labelText: 'Share Code',
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                context.go(AppRoutes.familyJoin(code));
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;
    final familyAsync = ref.watch(myFamilyProvider);
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        bottom: familyAsync.valueOrNull != null
            ? TabBar(
                controller: _tabController,
                labelColor: tokens.text.accent,
                unselectedLabelColor: tokens.text.tertiary,
                indicatorColor: tokens.text.accent,
                tabs: const [
                  Tab(icon: Icon(Icons.people), text: 'Members'),
                  Tab(icon: Icon(Icons.directions_car), text: 'Vehicles'),
                  Tab(icon: Icon(Icons.share), text: 'Invite'),
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
                      'No family yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: tokens.space.s2),
                    Text(
                      'Create a family to share vehicles,\nor join an existing one.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.text.tertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    DcoButton(
                      label: 'Create Family',
                      onPressed: () => context.go('/settings/family/new'),
                    ),
                    const SizedBox(height: 12),
                    DcoButton(
                      label: 'Join Family',
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
