import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/settings/domain/entities/email_reminder_settings.dart';
import 'package:dco_mobile/features/settings/domain/entities/user_preferences.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// User-configurable reminder thresholds: how far ahead the upcoming OS
/// reminder fires, and the remaining distance that counts as "due soon".
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final prefs =
        ref.watch(userPreferencesProvider).valueOrNull ?? UserPreferences.defaults;
    final userId = ref.watch(sessionControllerProvider).valueOrNull?.user.id;

    Future<void> save(UserPreferences next) async {
      if (userId == null) return;
      await ref.read(preferencesRepositoryProvider).save(userId: userId, preferences: next);
    }

    final daysValue = s.remindersSoonDaysValue(prefs.soonDays);
    final distanceValue = MileageFormat.labeled(
      MileageUnit.km.toStorage(prefs.soonDistanceKm),
      prefs.lengthUnit,
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.remindersTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radius.lg),
              boxShadow: tokens.shadows.card,
            ),
            child: Material(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(tokens.radius.lg),
              child: Padding(
                padding: EdgeInsets.all(tokens.space.s4),
                child: Text(
                  s.remindersIntro(daysValue, distanceValue),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.text.caption,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.space.s6),
          const _EmailReminderSection(),
          SizedBox(height: tokens.space.s6),
          _ThresholdSection(
            title: s.remindersSoonDaysLabel,
            help: s.remindersSoonDaysHelp,
            value: daysValue,
            child: Slider(
              value: prefs.soonDays.toDouble().clamp(
                DueThresholds.minDays.toDouble(),
                DueThresholds.maxDays.toDouble(),
              ),
              min: DueThresholds.minDays.toDouble(),
              max: DueThresholds.maxDays.toDouble(),
              divisions: DueThresholds.maxDays - DueThresholds.minDays,
              label: daysValue,
              onChanged: (value) =>
                  save(prefs.copyWith(soonDays: value.round())),
            ),
          ),
          SizedBox(height: tokens.space.s6),
          _ThresholdSection(
            title: s.remindersSoonDistanceLabel,
            help: s.remindersSoonDistanceHelp,
            value: distanceValue,
            child: Slider(
              value: prefs.soonDistanceKm.clamp(
                DueThresholds.minKm,
                DueThresholds.maxKm,
              ),
              min: DueThresholds.minKm,
              max: DueThresholds.maxKm,
              divisions: ((DueThresholds.maxKm - DueThresholds.minKm) /
                      DueThresholds.stepKm)
                  .round(),
              label: distanceValue,
              onChanged: (value) {
                final snapped = (value / DueThresholds.stepKm).round() *
                    DueThresholds.stepKm;
                save(prefs.copyWith(soonDistanceKm: snapped));
              },
            ),
          ),
          SizedBox(height: tokens.space.s6),
          Center(
            child: DcoButton(
              label: s.remindersReset,
              variant: DcoButtonVariant.secondary,
              onPressed: () => save(
                prefs.copyWith(
                  soonDays: DueThresholds.defaults.soonDays,
                  soonDistanceKm: DueThresholds.defaults.soonDistanceKm,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdSection extends StatelessWidget {
  const _ThresholdSection({
    required this.title,
    required this.help,
    required this.value,
    required this.child,
  });

  final String title;
  final String help;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.text.caption,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.space.s2),
        Text(
          help,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.text.caption,
          ),
        ),
        SizedBox(height: tokens.space.s3),
        child,
      ],
    );
  }
}

class _EmailReminderSection extends ConsumerStatefulWidget {
  const _EmailReminderSection();

  @override
  ConsumerState<_EmailReminderSection> createState() =>
      _EmailReminderSectionState();
}

class _EmailReminderSectionState extends ConsumerState<_EmailReminderSection> {
  EmailReminderSettings? _settings;
  int? _leadDays;
  bool _saving = false;
  bool _failed = false;

  Future<void> _save(EmailReminderSettings next) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final saved = await ref
          .read(emailReminderSettingsApiProvider)
          .update(enabled: next.enabled, leadDays: next.leadDays);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _leadDays = null;
        _saving = false;
      });
      ref.invalidate(emailReminderSettingsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final asyncSettings = ref.watch(emailReminderSettingsProvider);
    final settings = _settings ?? asyncSettings.valueOrNull;

    if (settings == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          boxShadow: tokens.shadows.card,
        ),
        child: Material(
          color: tokens.background.card,
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          child: Padding(
            padding: EdgeInsets.all(tokens.space.s4),
            child: Row(
              children: [
                if (asyncSettings.hasError)
                  Expanded(
                    child: Text(
                      s.remindersEmailSaveError,
                      style: TextStyle(color: tokens.status.dangerFg),
                    ),
                  )
                else
                  Expanded(child: Text(s.remindersEmailTitle)),
                if (asyncSettings.hasError)
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(emailReminderSettingsProvider),
                    child: Text(s.retry),
                  )
                else
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;
    final leadDays = _leadDays ?? settings.leadDays;
    final canToggle = !_saving && (settings.available || settings.enabled);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        boxShadow: tokens.shadows.card,
      ),
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.space.s4,
            tokens.space.s3,
            tokens.space.s4,
            tokens.space.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s.remindersEmailTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  user != null && user.email.isNotEmpty
                      ? '${s.remindersEmailBody}\n${s.remindersEmailTo(user.email)}'
                      : s.remindersEmailBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.text.caption,
                  ),
                ),
                value: settings.enabled,
                onChanged: canToggle
                    ? (value) => _save(settings.copyWith(enabled: value))
                    : null,
              ),
              if (!settings.available)
                Padding(
                  padding: EdgeInsets.only(top: tokens.space.s2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          user != null && user.email.isEmpty
                              ? s.remindersEmailUnavailable
                              : s.remindersEmailNeedsVerification,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.caption),
                        ),
                      ),
                      if (user != null && user.email.isNotEmpty)
                        TextButton(
                          onPressed: () => context.push(AppRoutes.verifyEmail),
                          child: Text(s.remindersEmailVerify),
                        ),
                    ],
                  ),
                ),
              if (settings.enabled) ...[
                SizedBox(height: tokens.space.s3),
                _ThresholdSection(
                  title: s.remindersEmailLeadLabel,
                  help: s.remindersEmailLeadHelp,
                  value: s.remindersSoonDaysValue(leadDays),
                  child: Slider(
                    value: leadDays.toDouble(),
                    min: DueThresholds.minDays.toDouble(),
                    max: DueThresholds.maxDays.toDouble(),
                    divisions: DueThresholds.maxDays - DueThresholds.minDays,
                    label: s.remindersSoonDaysValue(leadDays),
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _leadDays = value.round()),
                    onChangeEnd: _saving
                        ? null
                        : (value) => _save(
                            settings.copyWith(leadDays: value.round()),
                          ),
                  ),
                ),
              ],
              if (_failed)
                Padding(
                  padding: EdgeInsets.only(top: tokens.space.s2),
                  child: Text(
                    s.remindersEmailSaveError,
                    style: TextStyle(color: tokens.status.dangerFg),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
