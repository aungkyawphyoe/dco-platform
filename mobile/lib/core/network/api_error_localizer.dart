import '../../generated/app_localizations.dart';

/// Converts a backend/network error code into a user-facing, localized
/// message. Raw server messages are intentionally never shown: they are
/// developer-facing and can change without notice.
String localizedApiError(AppLocalizations strings, String? code) {
  return switch (code) {
    null || '' || 'unknown' => strings.apiErrorGeneric,
    'network' ||
    'connection_error' ||
    'connection_closed' ||
    'unknown_host' => strings.apiErrorNetwork,
    'timeout' => strings.apiErrorTimeout,
    'bad_certificate' => strings.apiErrorSecureConnection,
    'cancelled' => '',
    'unauthorized' ||
    'unauthenticated' ||
    'invalid_refresh' ||
    'reauth_required' => strings.apiErrorSessionExpired,
    'invalid_token' => strings.apiErrorInvalidLink,
    'forbidden' ||
    'insufficient_permission' ||
    'insufficient_org_role' ||
    'no_vehicle_access' => strings.apiErrorForbidden,
    'not_found' ||
    'vehicle_not_found' ||
    'organization_not_found' ||
    'user_not_found' => strings.apiErrorNotFound,
    'conflict' ||
    'request_conflict' ||
    'revision_conflict' ||
    'operation_id_conflict' ||
    'id_conflict' ||
    'currency_mismatch' ||
    'review_mismatch' ||
    'vehicle_changed' ||
    'work_order_changed' => strings.apiErrorConflict,
    'validation' ||
    'invalid_request' ||
    'invalid_amount' ||
    'invalid_quantity' ||
    'invalid_money_precision' ||
    'amount_too_large' => strings.apiErrorValidation,
    'rate_limited' => strings.apiErrorRateLimited,
    'server' ||
    'service_unavailable' ||
    'server_unavailable' ||
    'rate_limit_unavailable' ||
    'billing_unavailable' ||
    'license_unavailable' => strings.apiErrorServer,
    'media_too_large' ||
    'payload_too_large' ||
    'photo_too_large' ||
    'report_too_large' => strings.apiErrorFileTooLarge,
    'invalid_credentials' => strings.apiErrorInvalidCredentials,
    'deactivated' => strings.apiErrorAccountDeactivated,
    'email_taken' => strings.apiErrorEmailTaken,
    'invalid_code' => strings.apiErrorCodeInvalid,
    'provider_not_configured' ||
    'auth_not_configured' => strings.apiErrorProviderNotConfigured,
    'invalid_flow' => strings.apiErrorFlowExpired,
    'delivery_failed' => strings.apiErrorDeliveryFailed,
    'email_verification_required' => strings.apiErrorEmailVerificationRequired,
    'account_link_required' ||
    'identity_in_use' => strings.apiErrorAccountLinkRequired,
    'invalid_password' => strings.apiErrorCurrentPasswordIncorrect,
    'email_required' => strings.apiErrorEmailRequired,
    'email_mismatch' => strings.apiErrorEmailMismatch,
    'no_email_on_account' => strings.apiErrorNoEmailOnAccount,
    'already_verified' ||
    'verification_not_needed' => strings.apiErrorAlreadyVerified,
    'password_change_required' => strings.apiErrorPasswordChangeRequired,
    'portal_access_restricted' => strings.apiErrorPortalAccessRestricted,
    'fleet_access_required' ||
    'enterprise_org_required' => strings.apiErrorFleetAccessRequired,
    'LIMIT_EXCEEDED' ||
    'share_limit_reached' ||
    'import_limit_exceeded' => strings.apiErrorPlanLimit,
    'subscription_read_only' ||
    'vehicle_read_only' => strings.apiErrorReadOnlyPlan,
    'duplicate_plate' || 'plate_taken' => strings.apiErrorDuplicatePlate,
    'duplicate_vin' || 'vin_taken' => strings.apiErrorDuplicateVin,
    'mileage_decrease' ||
    'odometer_regression' ||
    'invalid_odometer' => strings.apiErrorMileage,
    'currency_locked' ||
    'currency_not_enabled' ||
    'currency_required' ||
    'currency_immutable' ||
    'currency_migration_review_required' ||
    'analytics_currency_required' => strings.apiErrorCurrency,
    'driver_not_assigned' ||
    'vehicle_not_assigned' ||
    'not_assigned_to_vehicle' => strings.apiErrorVehicleNotAssigned,
    'invitation_expired' ||
    'invitation_not_found' ||
    'share_code_expired' ||
    'share_code_not_found' => strings.apiErrorInvitation,
    _ when code.startsWith('currency_') => strings.apiErrorCurrency,
    _ => strings.apiErrorGeneric,
  };
}
