import '../../../../generated/app_localizations.dart';

/// Localized, user-facing message for a failed sync cycle. Sync is
/// offline-first, so every message reassures the user that local changes are
/// safe and will retry.
String syncErrorMessage(AppLocalizations strings, String? code) {
  return switch (code) {
    'network' ||
    'timeout' ||
    'bad_certificate' ||
    'connection_error' ||
    'connection_closed' ||
    'unknown_host' => strings.syncErrorNetwork,
    'unauthorized' ||
    'unauthenticated' ||
    'invalid_refresh' ||
    'reauth_required' ||
    'session_expired' => strings.syncErrorSession,
    'rate_limited' => strings.syncErrorRateLimited,
    'server' ||
    'service_unavailable' ||
    'server_unavailable' ||
    'rate_limit_unavailable' ||
    'billing_unavailable' ||
    'license_unavailable' => strings.syncErrorServer,
    'LIMIT_EXCEEDED' ||
    'share_limit_reached' ||
    'import_limit_exceeded' ||
    'subscription_read_only' ||
    'vehicle_read_only' => strings.syncErrorPlan,
    'media_too_large' ||
    'payload_too_large' ||
    'photo_too_large' ||
    'report_too_large' => strings.syncErrorStorage,
    'forbidden' ||
    'insufficient_permission' ||
    'insufficient_org_role' ||
    'no_vehicle_access' => strings.syncErrorForbidden,
    'conflict' ||
    'request_conflict' ||
    'revision_conflict' ||
    'operation_id_conflict' ||
    'id_conflict' ||
    'currency_mismatch' ||
    'review_mismatch' ||
    'vehicle_changed' ||
    'work_order_changed' => strings.syncErrorConflict,
    'validation' ||
    'invalid_request' ||
    'invalid_amount' ||
    'invalid_quantity' ||
    'invalid_money_precision' ||
    'amount_too_large' => strings.syncErrorValidation,
    _ when code?.startsWith('currency_') == true => strings.syncErrorConflict,
    _ => strings.syncErrorGeneric,
  };
}
