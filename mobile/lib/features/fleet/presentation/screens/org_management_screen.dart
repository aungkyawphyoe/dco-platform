import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/org_members_tab.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/org_settings_tab.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/org_vehicles_tab.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/org_workshops_tab.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Organization management — admin-only drawer/hub destination with
/// Members / Vehicles / Workshops / Settings tabs (FRD §18).
class OrgManagementScreen extends ConsumerStatefulWidget {
  const OrgManagementScreen({super.key});

  @override
  ConsumerState<OrgManagementScreen> createState() =>
      _OrgManagementScreenState();
}

class _OrgManagementScreenState
    extends ConsumerState<OrgManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgCtx = ref.watch(entitlementsProvider).valueOrNull?.organization;

    if (orgCtx == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.fleetOrgTitle)),
        body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }

    final orgId = orgCtx.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.fleetOrgTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: tokens.text.accent,
          unselectedLabelColor: tokens.text.tertiary,
          indicatorColor: tokens.text.accent,
          tabs: [
            Tab(text: s.fleetOrgMembersTab),
            Tab(text: s.fleetOrgVehiclesTab),
            Tab(text: s.fleetOrgWorkshopsTab),
            Tab(text: s.fleetOrgSettingsTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OrgMembersTab(orgId: orgId, canManage: orgCtx.canManageOrg),
          OrgVehiclesTab(orgId: orgId, canAdd: orgCtx.canOperate),
          OrgWorkshopsTab(orgId: orgId),
          OrgSettingsTab(orgId: orgId),
        ],
      ),
    );
  }
}
