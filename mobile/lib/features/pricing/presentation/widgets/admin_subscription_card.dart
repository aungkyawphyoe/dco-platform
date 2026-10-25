import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../../core/gating/providers.dart';
import '../../../../core/widgets/dco_card.dart';
import '../../../garage/providers.dart';
import '../../providers.dart';

class AdminSubscriptionCard extends ConsumerStatefulWidget {
  const AdminSubscriptionCard({super.key});
  @override
  ConsumerState<AdminSubscriptionCard> createState() =>
      _AdminSubscriptionCardState();
}

class _AdminSubscriptionCardState extends ConsumerState<AdminSubscriptionCard> {
  bool busy = false;
  String? error;
  Future<void> select(String id) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(dioProvider)
          .post('/me/free-vehicle', data: {'vehicle_id': id});
      await ref.read(pricingRepositoryProvider).refresh();
      await ref
          .read(licenseControllerProvider.notifier)
          .refreshIfStale(force: true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = Localizations.localeOf(context).languageCode == 'my'
              ? 'ရွေးချယ်မှု မသိမ်းနိုင်ပါ။ အင်တာနက်ချိတ်ဆက်ပြီး ပြန်ကြိုးစားပါ။'
              : 'Could not save selection. Connect and retry, or contact your admin if selection is locked.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionStatusProvider).valueOrNull;
    if (sub?.managed != true) return const SizedBox.shrink();
    final my = Localizations.localeOf(context).languageCode == 'my';
    final claims = ref.watch(licenseControllerProvider).valueOrNull;
    final free = claims?.planId == 'free';
    final term = sub!.adminTerm;
    final vehicles = ref.watch(garageVehiclesProvider).valueOrNull ?? const [];
    final user = ref.watch(currentUserIdProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: DcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              my ? 'စာရင်းသွင်းမှု အခြေအနေ' : 'Subscription status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (term != null)
              Text(
                '${term['plan']} · ${term['source']}\n${my ? 'ကုန်ဆုံးရက်' : 'Term ends'}: ${DateTime.parse(term['endsAt'] as String).toLocal()}',
              ),
            if (term?['source'] == 'direct')
              Text(
                '${my ? 'ခွင့်ပြုကာလကုန်ဆုံးရက်' : 'Grace ends'}: ${DateTime.parse(term!['accessEndsAt'] as String).toLocal()}',
              ),
            if (term?['status'] == 'grace')
              Text(
                my
                    ? 'ခွင့်ပြုကာလအတွင်း ဖြစ်ပါသည်။ စာရင်းသွင်းမှု သက်တမ်းတိုးရန် အက်ဒမင်ကို ဆက်သွယ်ပါ။'
                    : 'You are in the seven-day grace period. Contact your admin to renew.',
              ),
            if (free) ...[
              Text(
                my
                    ? 'Free အစီအစဉ်တွင် ကားတစ်စီးကိုသာ ပြင်ဆင်နိုင်ပါသည်။ အခြားမှတ်တမ်းများကို ဖတ်ရှုနိုင်ပါသည်။'
                    : 'Free allows one editable vehicle. Other vehicles and records remain readable.',
              ),
              for (final v in vehicles.where(
                (v) => v.userId == user && !v.archived,
              ))
                ListTile(
                  title: Text(v.name),
                  subtitle: v.id == sub.freeVehicleId
                      ? Text(my ? 'ရွေးချယ်ထားသည်' : 'Selected · locked')
                      : null,
                  trailing: sub.freeVehicleId == null
                      ? TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        my
                                            ? 'ကားရွေးချယ်မည်လား'
                                            : 'Select this vehicle?',
                                      ),
                                      content: Text(
                                        my
                                            ? 'ရွေးချယ်ပြီးနောက် အက်ဒမင်မှသာ ပြောင်းနိုင်ပါမည်။'
                                            : 'Only an admin can change this selection while you remain on Free.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(
                                            my ? 'မလုပ်တော့ပါ' : 'Cancel',
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text(
                                            my ? 'အတည်ပြုမည်' : 'Confirm',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) await select(v.id);
                                },
                          child: Text(my ? 'ရွေးမည်' : 'Select'),
                        )
                      : null,
                ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
