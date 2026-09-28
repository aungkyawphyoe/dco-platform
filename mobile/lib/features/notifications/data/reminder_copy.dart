import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/features/notifications/domain/reminder_policy.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Localized copy for OS reminder banners and in-app feed rows.
class ReminderCopy {
  ReminderCopy(this.locale);

  final Locale locale;

  static final Set<String> _datesReady = <String>{};

  /// Ensures [DateFormat] can render [locale]. No-op after the first call.
  Future<void> ensureInitialized() async {
    if (_datesReady.add(locale.toString())) {
      await initializeDateFormatting(locale.toString());
    }
  }

  AppLocalizations get _s => lookupAppLocalizations(locale);

  String title(ReminderPhase phase) {
    final raw = switch (phase) {
      ReminderPhase.upcoming => _s.notificationsReminderUpcomingTitle,
      ReminderPhase.due => _s.notificationsReminderDueTitle,
    };
    return ReminderPolicy.clip(raw, ReminderPolicy.titleMax);
  }

  /// Body always carries the plan item name plus its due date and/or due
  /// mileage, whichever the item has.
  String body({
    required String name,
    DateTime? dueOn,
    double? dueMileage,
    required MileageUnit unit,
  }) {
    final raw = switch ((dueOn, dueMileage)) {
      (final date?, final mileage?) => _s.notificationsReminderBodyBoth(
          _date(date),
          MileageFormat.labeled(mileage, unit),
          name,
        ),
      (final date?, null) => _s.notificationsReminderBodyDate(_date(date), name),
      (null, final mileage?) =>
        _s.notificationsReminderBodyMileage(MileageFormat.labeled(mileage, unit), name),
      (null, null) => name,
    };
    return ReminderPolicy.clip(raw, ReminderPolicy.bodyMax);
  }

  String _date(DateTime value) => DateFormat.yMMMd(locale.toString()).format(value);
}
