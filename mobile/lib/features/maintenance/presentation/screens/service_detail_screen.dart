import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final lengthUnit = ref.watch(lengthUnitProvider);
    final currency = ref.watch(currencyProvider).code;

    return Scaffold(
      appBar: AppBar(title: Text(s.serviceDetailTitle)),
      body: FutureBuilder(
        future: ref.read(maintenanceRepositoryProvider).getServiceRecord(serviceId),
        builder: (context, snapshot) {
          if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: tokens.text.accent));
          }
          final record = snapshot.data;
          if (record == null) {
            return DcoEmptyState(
              title: s.serviceDetailNotFound,
              body: s.serviceDetailNotFoundBody,
            );
          }
          final money = MoneyFormat.labeled(record.totalCost, currency);
          final odometer = MileageFormat.labeled(record.odometer, lengthUnit);
          return ListView(
            padding: EdgeInsets.all(tokens.space.s5),
            children: [
              Text(record.title, style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: tokens.space.s2),
              Text(
                DateFormat.yMMMd().format(record.servicedOn),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
              ),
              SizedBox(height: tokens.space.s5),
              _kv(context, s.serviceDetailMileage, odometer),
              _kv(context, s.serviceDetailTotal, money),
              if (record.workshopName != null) _kv(context, s.serviceDetailWorkshop, record.workshopName!),
              if (record.notes != null) _kv(context, s.serviceDetailNotes, record.notes!),
              SizedBox(height: tokens.space.s5),
              Text(s.serviceDetailServices, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: tokens.space.s3),
              ...record.items.map((item) {
                final cost = item.lineCost == null
                    ? '—'
                    : MoneyFormat.labeled(item.lineCost!, currency);
                return Padding(
                  padding: EdgeInsets.only(bottom: tokens.space.s3),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.name)),
                      Text(
                        cost,
                        style: GoogleFonts.ibmPlexMono(color: tokens.text.secondary, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }),
              if (record.parts.isNotEmpty) ...[
                SizedBox(height: tokens.space.s5),
                Text(s.serviceDetailParts, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: tokens.space.s3),
                ...record.parts.map(
                  (part) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.space.s3),
                    child: Text(part.name),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: tokens.space.s1),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
