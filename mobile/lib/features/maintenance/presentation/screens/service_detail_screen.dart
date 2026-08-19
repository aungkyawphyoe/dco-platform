import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final unit = ref.watch(activeVehicleProvider).valueOrNull?.mileageUnit.label ?? 'mi';

    return Scaffold(
      appBar: AppBar(title: const Text('Service')),
      body: FutureBuilder(
        future: ref.read(maintenanceRepositoryProvider).getServiceRecord(serviceId),
        builder: (context, snapshot) {
          if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: tokens.text.accent));
          }
          final record = snapshot.data;
          if (record == null) {
            return const DcoEmptyState(
              title: 'Service not found',
              body: 'This record is no longer available.',
            );
          }
          final money = NumberFormat.simpleCurrency().format(record.totalCost);
          final miles = NumberFormat('#,###').format(record.odometer.round());
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
              _kv(context, 'Mileage', '$miles $unit'),
              _kv(context, 'Total', money),
              if (record.workshopName != null) _kv(context, 'Workshop', record.workshopName!),
              if (record.notes != null) _kv(context, 'Notes', record.notes!),
              SizedBox(height: tokens.space.s5),
              Text('Services', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: tokens.space.s3),
              ...record.items.map((item) {
                final cost = item.lineCost == null
                    ? '—'
                    : NumberFormat.simpleCurrency().format(item.lineCost);
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
