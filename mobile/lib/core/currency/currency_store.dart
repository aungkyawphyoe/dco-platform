import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

const operationalCurrencies = {
  'AED',
  'AFN',
  'ALL',
  'AMD',
  'ANG',
  'AOA',
  'ARS',
  'AUD',
  'AWG',
  'AZN',
  'BAM',
  'BBD',
  'BDT',
  'BGN',
  'BHD',
  'BIF',
  'BMD',
  'BND',
  'BOB',
  'BRL',
  'BSD',
  'BTN',
  'BWP',
  'BYN',
  'BZD',
  'CAD',
  'CDF',
  'CHF',
  'CLP',
  'CNY',
  'COP',
  'CRC',
  'CUC',
  'CUP',
  'CVE',
  'CZK',
  'DJF',
  'DKK',
  'DOP',
  'DZD',
  'EGP',
  'ERN',
  'ETB',
  'EUR',
  'FJD',
  'FKP',
  'GBP',
  'GEL',
  'GHS',
  'GIP',
  'GMD',
  'GNF',
  'GTQ',
  'GYD',
  'HKD',
  'HNL',
  'HRK',
  'HTG',
  'HUF',
  'IDR',
  'ILS',
  'INR',
  'IQD',
  'IRR',
  'ISK',
  'JMD',
  'JOD',
  'JPY',
  'KES',
  'KGS',
  'KHR',
  'KMF',
  'KPW',
  'KRW',
  'KWD',
  'KYD',
  'KZT',
  'LAK',
  'LBP',
  'LKR',
  'LRD',
  'LSL',
  'LYD',
  'MAD',
  'MDL',
  'MGA',
  'MKD',
  'MMK',
  'MNT',
  'MOP',
  'MRU',
  'MUR',
  'MVR',
  'MWK',
  'MXN',
  'MYR',
  'MZN',
  'NAD',
  'NGN',
  'NIO',
  'NOK',
  'NPR',
  'NZD',
  'OMR',
  'PAB',
  'PEN',
  'PGK',
  'PHP',
  'PKR',
  'PLN',
  'PYG',
  'QAR',
  'RON',
  'RSD',
  'RUB',
  'RWF',
  'SAR',
  'SBD',
  'SCR',
  'SDG',
  'SEK',
  'SGD',
  'SHP',
  'SLE',
  'SLL',
  'SOS',
  'SRD',
  'SSP',
  'STN',
  'SVC',
  'SYP',
  'SZL',
  'THB',
  'TJS',
  'TMT',
  'TND',
  'TOP',
  'TRY',
  'TTD',
  'TWD',
  'TZS',
  'UAH',
  'UGX',
  'USD',
  'UYU',
  'UZS',
  'VES',
  'VND',
  'VUV',
  'WST',
  'XAF',
  'XCD',
  'XCG',
  'XDR',
  'XOF',
  'XPF',
  'XSU',
  'YER',
  'ZAR',
  'ZMW',
  'ZWG',
  'ZWL',
};

/// Authoritative state cached in the account's record database. Shared vehicles
/// have their own scope; a viewer's personal preference is never their currency.
class CurrencyStore {
  CurrencyStore(this.db);
  final AppDatabase db;
  String key(String userId, String? vehicleId) =>
      'currency:$userId:${vehicleId ?? "scope"}';

  Future<Map<String, dynamic>?> read(String userId, {String? vehicleId}) async {
    final row = await (db.select(
      db.appMeta,
    )..where((r) => r.key.equals(key(userId, vehicleId)))).getSingleOrNull();
    return row?.value == null
        ? null
        : jsonDecode(row!.value!) as Map<String, dynamic>;
  }

  Stream<Map<String, dynamic>?> watch(String userId, {String? vehicleId}) {
    return (db.select(db.appMeta)
          ..where((r) => r.key.equals(key(userId, vehicleId))))
        .watchSingleOrNull()
        .map(
          (row) => row?.value == null
              ? null
              : jsonDecode(row!.value!) as Map<String, dynamic>,
        );
  }

  Future<void> save(
    String userId,
    Map<String, dynamic> state, {
    String? vehicleId,
  }) async {
    if (state['currency'] != null &&
        !operationalCurrencies.contains(state['currency'])) {
      throw const FormatException('Unsupported currency');
    }
    await db
        .into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(
            key: key(userId, vehicleId),
            value: Value(jsonEncode(state)),
          ),
          onConflict: DoUpdate(
            (_) => AppMetaCompanion(value: Value(jsonEncode(state))),
            target: [db.appMeta.key],
          ),
        );
  }

  /// Validate the currency captured by the form; never silently replace it.
  Future<String> validateCreation(
    String userId,
    String intended, {
    String? vehicleId,
  }) async {
    if (!operationalCurrencies.contains(intended)) {
      throw StateError('Unsupported currency');
    }
    var state = await read(userId, vehicleId: vehicleId);
    final account = vehicleId == null ? state : await read(userId);
    if (state == null && vehicleId != null) {
      final vehicle = await (db.select(
        db.vehicleRecords,
      )..where((r) => r.id.equals(vehicleId))).getSingleOrNull();
      // A newly created offline owned vehicle inherits its owner's cached scope.
      // A shared vehicle must have its owner's state fetched explicitly.
      if (vehicle?.userId == userId ||
          (vehicle != null && account?['organization_id'] != null)) {
        state = account;
      }
    }
    if (state == null && account?['enabled'] == true) {
      throw StateError('Sync this vehicle currency before recording costs.');
    }
    final active = state?['enabled'] == true;
    if (active && state?['currency'] == null) {
      throw StateError('Select a currency before recording costs.');
    }
    if (active && state?['review_required'] == true) {
      throw StateError('Currency history requires review.');
    }
    final expected = active ? state!['currency'] : 'MMK';
    if (intended != expected) {
      throw StateError('Currency changed. Re-enter the amount in $expected.');
    }
    return intended;
  }
}
