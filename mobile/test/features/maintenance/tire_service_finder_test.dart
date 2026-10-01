import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/maintenance/domain/tire_service_finder.dart';
import 'package:flutter_test/flutter_test.dart';

ServiceRecord _record({
  String id = 'r1',
  String title = 'Oil change',
  required DateTime servicedOn,
  List<ServiceLine> items = const [],
  List<AssignedPart> parts = const [],
}) {
  return ServiceRecord(
    id: id,
    vehicleId: 'v1',
    title: title,
    servicedOn: servicedOn,
    odometer: 12000,
    totalCost: 50,
    items: items,
    parts: parts,
    updatedAt: servicedOn,
    createdAt: servicedOn,
  );
}

void main() {
  group('TireServiceFinder', () {
    test('returns null when no record mentions tyres', () {
      final records = [
        _record(title: 'Oil change', servicedOn: DateTime(2026, 1, 10)),
        _record(title: 'Brake pads', servicedOn: DateTime(2026, 2, 10)),
      ];
      expect(TireServiceFinder.latest(records), isNull);
    });

    test('matches on title keywords (tire / tyre)', () {
      final records = [
        _record(
          id: 'a',
          title: 'Tire rotation',
          servicedOn: DateTime(2026, 1, 10),
        ),
        _record(
          id: 'b',
          title: 'Front tyre change',
          servicedOn: DateTime(2026, 2, 10),
        ),
      ];
      expect(TireServiceFinder.latest(records)!.id, 'b');
    });

    test('matches on service line names', () {
      final records = [
        _record(
          title: 'General service',
          servicedOn: DateTime(2026, 3, 1),
          items: [
            const ServiceLine(id: 'l1', name: 'Wheel alignment'),
          ],
        ),
      ];
      expect(TireServiceFinder.latest(records), isNotNull);
    });

    test('matches on part names', () {
      final records = [
        _record(
          title: 'Replacement',
          servicedOn: DateTime(2026, 3, 1),
          parts: const [AssignedPart(id: 'p1', partId: 'x', name: 'Tyre set')],
        ),
      ];
      expect(TireServiceFinder.latest(records), isNotNull);
    });

    test('picks the newest matching record, not the newest record overall', () {
      final records = [
        _record(
          id: 'tires',
          title: 'Tire rotation',
          servicedOn: DateTime(2026, 1, 10),
        ),
        _record(
          id: 'oil',
          title: 'Oil change',
          servicedOn: DateTime(2026, 4, 10),
        ),
      ];
      expect(TireServiceFinder.latest(records)!.id, 'tires');
    });
  });
}
