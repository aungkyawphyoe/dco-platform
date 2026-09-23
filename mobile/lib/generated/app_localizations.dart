import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_my.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('my'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DCO'**
  String get appTitle;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'inactive'**
  String get inactive;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @syncDefaultError.
  ///
  /// In en, this message translates to:
  /// **'Your changes will retry automatically.'**
  String get syncDefaultError;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @somethingWentWrongTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get somethingWentWrongTryAgain;

  /// No description provided for @navGarage.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get navGarage;

  /// No description provided for @navMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get navMaintenance;

  /// No description provided for @navExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get navExpenses;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get navSettings;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Your garage, on the phone.'**
  String get welcomeTagline;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Track maintenance, documents, and spend for every vehicle you own — even offline.'**
  String get welcomeBody;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPassword;

  /// No description provided for @createAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAnAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @signUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed'**
  String get signUpFailed;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get signInFailed;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @resetPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email. We send a reset link if the account exists.'**
  String get resetPasswordBody;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'If that email is registered, we sent a reset link.'**
  String get resetLinkSent;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed'**
  String get resetFailed;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @authIncorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect'**
  String get authIncorrectCredentials;

  /// No description provided for @authEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'That email is already registered'**
  String get authEmailAlreadyRegistered;

  /// No description provided for @authNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again'**
  String get authNetworkError;

  /// No description provided for @authTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again shortly'**
  String get authTooManyAttempts;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Sign in again'**
  String get authSessionExpired;

  /// No description provided for @authUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get authUnknownError;

  /// No description provided for @dashboardNoVehicle.
  ///
  /// In en, this message translates to:
  /// **'No vehicle'**
  String get dashboardNoVehicle;

  /// No description provided for @dashboardGarageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get dashboardGarageTooltip;

  /// No description provided for @dashboardNotificationsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get dashboardNotificationsTooltip;

  /// No description provided for @dashboardVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get dashboardVerifyEmail;

  /// No description provided for @dashboardResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get dashboardResend;

  /// No description provided for @dashboardLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load dashboard'**
  String get dashboardLoadError;

  /// No description provided for @dashboardEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle'**
  String get dashboardEmptyTitle;

  /// No description provided for @dashboardEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first car to see spend, upcoming service, and history here.'**
  String get dashboardEmptyBody;

  /// No description provided for @dashboardOwnershipSummary.
  ///
  /// In en, this message translates to:
  /// **'Ownership Summary'**
  String get dashboardOwnershipSummary;

  /// No description provided for @dashboardTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get dashboardTotalSpent;

  /// No description provided for @dashboardThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get dashboardThisMonth;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboardQuickActions;

  /// No description provided for @dashboardHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get dashboardHistory;

  /// No description provided for @dashboardCharge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get dashboardCharge;

  /// No description provided for @dashboardRefuel.
  ///
  /// In en, this message translates to:
  /// **'Refuel'**
  String get dashboardRefuel;

  /// No description provided for @dashboardInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get dashboardInsurance;

  /// No description provided for @dashboardNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get dashboardNotes;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardNoServicesYet.
  ///
  /// In en, this message translates to:
  /// **'No services yet'**
  String get dashboardNoServicesYet;

  /// No description provided for @dashboardNextMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Next Maintenance'**
  String get dashboardNextMaintenance;

  /// No description provided for @dashboardNoPlanItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No plan items yet'**
  String get dashboardNoPlanItemsYet;

  /// No description provided for @dashboardAddPlanItem.
  ///
  /// In en, this message translates to:
  /// **'Add a plan item'**
  String get dashboardAddPlanItem;

  /// No description provided for @dashboardLogService.
  ///
  /// In en, this message translates to:
  /// **'Log Service'**
  String get dashboardLogService;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @overdueBy.
  ///
  /// In en, this message translates to:
  /// **'Overdue by {count, plural, =1{# day} other{# days}}'**
  String overdueBy(num count);

  /// No description provided for @dueIn.
  ///
  /// In en, this message translates to:
  /// **'Due in {distance}'**
  String dueIn(Object distance);

  /// No description provided for @dueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get dueSoon;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due {distance}'**
  String due(Object distance);

  /// No description provided for @garageMyGarage.
  ///
  /// In en, this message translates to:
  /// **'My Garage'**
  String get garageMyGarage;

  /// No description provided for @garageRegisterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle'**
  String get garageRegisterTooltip;

  /// No description provided for @garageLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load garage'**
  String get garageLoadError;

  /// No description provided for @garageEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No vehicles yet'**
  String get garageEmptyTitle;

  /// No description provided for @garageEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to start tracking maintenance, documents, and spend.'**
  String get garageEmptyBody;

  /// No description provided for @garageSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Switch failed'**
  String get garageSwitchFailed;

  /// No description provided for @garageSwitchFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Your change stays on this device and syncs later.'**
  String get garageSwitchFailedBody;

  /// No description provided for @garageAddCardTitle.
  ///
  /// In en, this message translates to:
  /// **'+ Register Another Vehicle'**
  String get garageAddCardTitle;

  /// No description provided for @garageAddCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track maintenance, expenses & documents'**
  String get garageAddCardSubtitle;

  /// No description provided for @garageFamilyBadge.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get garageFamilyBadge;

  /// No description provided for @vehicleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Vehicle'**
  String get vehicleEditTitle;

  /// No description provided for @vehicleRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Vehicle'**
  String get vehicleRegisterTitle;

  /// No description provided for @vehicleRequiredInfo.
  ///
  /// In en, this message translates to:
  /// **'Required Information'**
  String get vehicleRequiredInfo;

  /// No description provided for @vehicleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get vehicleNameLabel;

  /// No description provided for @vehicleYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year *'**
  String get vehicleYearLabel;

  /// No description provided for @vehicleMakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Make *'**
  String get vehicleMakeLabel;

  /// No description provided for @vehicleModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model *'**
  String get vehicleModelLabel;

  /// No description provided for @vehiclePlateLabel.
  ///
  /// In en, this message translates to:
  /// **'License Plate *'**
  String get vehiclePlateLabel;

  /// No description provided for @vehicleMileageLabel.
  ///
  /// In en, this message translates to:
  /// **'Mileage *'**
  String get vehicleMileageLabel;

  /// No description provided for @vehicleFuelTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fuel Type *'**
  String get vehicleFuelTypeLabel;

  /// No description provided for @vehicleFuelTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Fuel type is required'**
  String get vehicleFuelTypeRequired;

  /// No description provided for @vehicleOptionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Optional Details'**
  String get vehicleOptionalDetails;

  /// No description provided for @vehicleVinLabel.
  ///
  /// In en, this message translates to:
  /// **'VIN'**
  String get vehicleVinLabel;

  /// No description provided for @vehicleColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get vehicleColorLabel;

  /// No description provided for @vehicleNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get vehicleNicknameLabel;

  /// No description provided for @vehiclePurchaseDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get vehiclePurchaseDateLabel;

  /// No description provided for @vehicleArchiveButton.
  ///
  /// In en, this message translates to:
  /// **'Archive vehicle'**
  String get vehicleArchiveButton;

  /// No description provided for @vehicleArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this vehicle?'**
  String get vehicleArchiveTitle;

  /// No description provided for @vehicleArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'Records stay attached and hidden. This does not permanently delete them.'**
  String get vehicleArchiveBody;

  /// No description provided for @vehicleArchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get vehicleArchiveAction;

  /// No description provided for @vehicleAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get vehicleAddPhoto;

  /// No description provided for @vehicleSetActive.
  ///
  /// In en, this message translates to:
  /// **'Set active'**
  String get vehicleSetActive;

  /// No description provided for @vehicleEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get vehicleEditTooltip;

  /// No description provided for @vehicleRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from family'**
  String get vehicleRemoveTooltip;

  /// No description provided for @vehiclePlateDuplicate.
  ///
  /// In en, this message translates to:
  /// **'That license plate is already in your garage'**
  String get vehiclePlateDuplicate;

  /// No description provided for @vehicleVinDuplicate.
  ///
  /// In en, this message translates to:
  /// **'That VIN already belongs to a vehicle'**
  String get vehicleVinDuplicate;

  /// No description provided for @vehicleMileageDecrease.
  ///
  /// In en, this message translates to:
  /// **'Mileage cannot decrease'**
  String get vehicleMileageDecrease;

  /// No description provided for @vehicleNotFound.
  ///
  /// In en, this message translates to:
  /// **'Vehicle not found'**
  String get vehicleNotFound;

  /// No description provided for @vehicleNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get vehicleNameRequired;

  /// No description provided for @vehicleMakeRequired.
  ///
  /// In en, this message translates to:
  /// **'Make is required'**
  String get vehicleMakeRequired;

  /// No description provided for @vehicleModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Model is required'**
  String get vehicleModelRequired;

  /// No description provided for @vehicleYearRequired.
  ///
  /// In en, this message translates to:
  /// **'Year is required'**
  String get vehicleYearRequired;

  /// No description provided for @vehicleYearInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid year'**
  String get vehicleYearInvalid;

  /// No description provided for @vehicleYearRange.
  ///
  /// In en, this message translates to:
  /// **'Year must be between 1900 and {max}'**
  String vehicleYearRange(Object max);

  /// No description provided for @vehiclePlateRequired.
  ///
  /// In en, this message translates to:
  /// **'License plate is required'**
  String get vehiclePlateRequired;

  /// No description provided for @vehiclePlateMaxLength.
  ///
  /// In en, this message translates to:
  /// **'License plate must be 20 characters or fewer'**
  String get vehiclePlateMaxLength;

  /// No description provided for @vehicleMileageRequired.
  ///
  /// In en, this message translates to:
  /// **'Mileage is required'**
  String get vehicleMileageRequired;

  /// No description provided for @vehicleMileageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mileage'**
  String get vehicleMileageInvalid;

  /// No description provided for @vehicleMileageNegative.
  ///
  /// In en, this message translates to:
  /// **'Mileage cannot be negative'**
  String get vehicleMileageNegative;

  /// No description provided for @vehicleVinLength.
  ///
  /// In en, this message translates to:
  /// **'VIN must be 17 characters'**
  String get vehicleVinLength;

  /// No description provided for @fuelPetrol.
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get fuelPetrol;

  /// No description provided for @fuelElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get fuelElectric;

  /// No description provided for @fuelHybridPlugin.
  ///
  /// In en, this message translates to:
  /// **'Hybrid plugin'**
  String get fuelHybridPlugin;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get maintenanceHistoryTooltip;

  /// No description provided for @maintenanceLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load maintenance'**
  String get maintenanceLoadError;

  /// No description provided for @maintenanceNoActiveVehicle.
  ///
  /// In en, this message translates to:
  /// **'No active vehicle'**
  String get maintenanceNoActiveVehicle;

  /// No description provided for @maintenanceNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to plan service and keep history.'**
  String get maintenanceNoActiveVehicleBody;

  /// No description provided for @maintenanceUpcomingReminders.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Reminders'**
  String get maintenanceUpcomingReminders;

  /// No description provided for @maintenanceNothingDue.
  ///
  /// In en, this message translates to:
  /// **'Nothing due'**
  String get maintenanceNothingDue;

  /// No description provided for @maintenanceScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get maintenanceScheduled;

  /// No description provided for @maintenanceNothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get maintenanceNothingScheduled;

  /// No description provided for @maintenanceServiceHistory.
  ///
  /// In en, this message translates to:
  /// **'Service History'**
  String get maintenanceServiceHistory;

  /// No description provided for @maintenanceNoServicesLogged.
  ///
  /// In en, this message translates to:
  /// **'No services logged'**
  String get maintenanceNoServicesLogged;

  /// No description provided for @maintenanceRegisterService.
  ///
  /// In en, this message translates to:
  /// **'Register service'**
  String get maintenanceRegisterService;

  /// No description provided for @maintenanceLoadFromReceipt.
  ///
  /// In en, this message translates to:
  /// **'Load from Receipt'**
  String get maintenanceLoadFromReceipt;

  /// No description provided for @maintenancePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Plan'**
  String get maintenancePlanTitle;

  /// No description provided for @maintenancePlanNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to build a maintenance plan.'**
  String get maintenancePlanNoActiveVehicleBody;

  /// No description provided for @maintenancePlanLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load plan'**
  String get maintenancePlanLoadError;

  /// No description provided for @maintenancePlanEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No plan items yet'**
  String get maintenancePlanEmptyTitle;

  /// No description provided for @maintenancePlanEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a custom item or pick from suggested services.'**
  String get maintenancePlanEmptyBody;

  /// No description provided for @maintenancePlanAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add Maintenance Item'**
  String get maintenancePlanAddItem;

  /// No description provided for @maintenancePlanAddSuggested.
  ///
  /// In en, this message translates to:
  /// **'Add Suggested Items'**
  String get maintenancePlanAddSuggested;

  /// No description provided for @serviceHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Service History'**
  String get serviceHistoryTitle;

  /// No description provided for @serviceHistoryNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to see services logged against it.'**
  String get serviceHistoryNoActiveVehicleBody;

  /// No description provided for @serviceHistoryLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load services'**
  String get serviceHistoryLoadError;

  /// No description provided for @serviceHistoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No services yet'**
  String get serviceHistoryEmptyTitle;

  /// No description provided for @serviceHistoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Logged services for this vehicle will show up here.'**
  String get serviceHistoryEmptyBody;

  /// No description provided for @serviceDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serviceDetailTitle;

  /// No description provided for @serviceDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Service not found'**
  String get serviceDetailNotFound;

  /// No description provided for @serviceDetailNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This record is no longer available.'**
  String get serviceDetailNotFoundBody;

  /// No description provided for @serviceDetailMileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get serviceDetailMileage;

  /// No description provided for @serviceDetailTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get serviceDetailTotal;

  /// No description provided for @serviceDetailWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get serviceDetailWorkshop;

  /// No description provided for @serviceDetailNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get serviceDetailNotes;

  /// No description provided for @serviceDetailServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get serviceDetailServices;

  /// No description provided for @serviceDetailParts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get serviceDetailParts;

  /// No description provided for @registerServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Service'**
  String get registerServiceTitle;

  /// No description provided for @registerServiceNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle before logging a service.'**
  String get registerServiceNoActiveVehicleBody;

  /// No description provided for @registerServiceJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get registerServiceJobTitle;

  /// No description provided for @registerServiceDate.
  ///
  /// In en, this message translates to:
  /// **'Date *'**
  String get registerServiceDate;

  /// No description provided for @registerServiceMileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage *'**
  String get registerServiceMileage;

  /// No description provided for @registerServiceNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get registerServiceNotes;

  /// No description provided for @registerServiceSection.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get registerServiceSection;

  /// No description provided for @registerServiceCostHint.
  ///
  /// In en, this message translates to:
  /// **'cost'**
  String get registerServiceCostHint;

  /// No description provided for @registerServiceAddService.
  ///
  /// In en, this message translates to:
  /// **'add service'**
  String get registerServiceAddService;

  /// No description provided for @registerServicePartsSection.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get registerServicePartsSection;

  /// No description provided for @registerServiceAssignPart.
  ///
  /// In en, this message translates to:
  /// **'assign part'**
  String get registerServiceAssignPart;

  /// No description provided for @registerServiceTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get registerServiceTotal;

  /// No description provided for @registerServiceAddServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get registerServiceAddServiceTitle;

  /// No description provided for @registerServiceAddServiceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No due or scheduled items left. Add a custom service below.'**
  String get registerServiceAddServiceEmpty;

  /// No description provided for @registerServiceCustomService.
  ///
  /// In en, this message translates to:
  /// **'Custom service'**
  String get registerServiceCustomService;

  /// No description provided for @registerServiceCustomHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Alignment'**
  String get registerServiceCustomHint;

  /// No description provided for @registerServiceAddCustom.
  ///
  /// In en, this message translates to:
  /// **'Add custom'**
  String get registerServiceAddCustom;

  /// No description provided for @registerServiceAssignPartTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign part'**
  String get registerServiceAssignPartTitle;

  /// No description provided for @registerServiceAssignPartEmpty.
  ///
  /// In en, this message translates to:
  /// **'No parts in the catalog yet. Add one, then assign it here.'**
  String get registerServiceAssignPartEmpty;

  /// No description provided for @registerServiceAssignPartAllAssigned.
  ///
  /// In en, this message translates to:
  /// **'Every part is already assigned to this service.'**
  String get registerServiceAssignPartAllAssigned;

  /// No description provided for @registerServiceAddNewPart.
  ///
  /// In en, this message translates to:
  /// **'Add a new part'**
  String get registerServiceAddNewPart;

  /// No description provided for @planItemFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Service Item'**
  String get planItemFormEditTitle;

  /// No description provided for @planItemFormCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Service Item'**
  String get planItemFormCreateTitle;

  /// No description provided for @planItemFormName.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get planItemFormName;

  /// No description provided for @planItemFormSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule *'**
  String get planItemFormSchedule;

  /// No description provided for @planItemFormActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get planItemFormActive;

  /// No description provided for @planItemFormRecurring.
  ///
  /// In en, this message translates to:
  /// **'recurring'**
  String get planItemFormRecurring;

  /// No description provided for @planItemFormRepeatEvery.
  ///
  /// In en, this message translates to:
  /// **'Repeat every'**
  String get planItemFormRepeatEvery;

  /// No description provided for @planItemFormUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get planItemFormUnit;

  /// No description provided for @planItemFormEveryMileage.
  ///
  /// In en, this message translates to:
  /// **'Every (mileage)'**
  String get planItemFormEveryMileage;

  /// No description provided for @planItemFormOverrideStart.
  ///
  /// In en, this message translates to:
  /// **'Override Tracking Start'**
  String get planItemFormOverrideStart;

  /// No description provided for @planItemFormOverrideHelper.
  ///
  /// In en, this message translates to:
  /// **'The highest value out of this or your most recent service will prevail.'**
  String get planItemFormOverrideHelper;

  /// No description provided for @planItemFormDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get planItemFormDate;

  /// No description provided for @planItemFormDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Date *'**
  String get planItemFormDateRequired;

  /// No description provided for @planItemFormMileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get planItemFormMileage;

  /// No description provided for @planItemFormMileageRequired.
  ///
  /// In en, this message translates to:
  /// **'Mileage *'**
  String get planItemFormMileageRequired;

  /// No description provided for @planItemFormNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get planItemFormNotes;

  /// No description provided for @suggestedItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Items'**
  String get suggestedItemsTitle;

  /// No description provided for @suggestedItemsNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to add suggested items.'**
  String get suggestedItemsNoActiveVehicleBody;

  /// No description provided for @suggestedItemsAllAdded.
  ///
  /// In en, this message translates to:
  /// **'All suggested items added'**
  String get suggestedItemsAllAdded;

  /// No description provided for @suggestedItemsAllAddedBody.
  ///
  /// In en, this message translates to:
  /// **'You can still create a custom service item from the plan.'**
  String get suggestedItemsAllAddedBody;

  /// No description provided for @suggestedItemAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {itemName}'**
  String suggestedItemAdd(Object itemName);

  /// No description provided for @planItemTileOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get planItemTileOverdue;

  /// No description provided for @planItemTileOverdueBy.
  ///
  /// In en, this message translates to:
  /// **'Overdue by {count, plural, =1{# day} other{# days}}'**
  String planItemTileOverdueBy(num count);

  /// No description provided for @planItemTileNextMileage.
  ///
  /// In en, this message translates to:
  /// **'Next Mileage: '**
  String get planItemTileNextMileage;

  /// No description provided for @planItemTileNextDate.
  ///
  /// In en, this message translates to:
  /// **'Next Date: '**
  String get planItemTileNextDate;

  /// No description provided for @planItemTileNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date set'**
  String get planItemTileNoDueDate;

  /// No description provided for @planItemTileRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining: '**
  String get planItemTileRemaining;

  /// No description provided for @planItemTileTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'Time left: '**
  String get planItemTileTimeLeft;

  /// No description provided for @planItemTileDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get planItemTileDay;

  /// No description provided for @planItemTileDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get planItemTileDays;

  /// No description provided for @maintenanceMileageDecrease.
  ///
  /// In en, this message translates to:
  /// **'Mileage cannot decrease'**
  String get maintenanceMileageDecrease;

  /// No description provided for @maintenanceVehicleNotFound.
  ///
  /// In en, this message translates to:
  /// **'Vehicle not found'**
  String get maintenanceVehicleNotFound;

  /// No description provided for @maintenancePlanItemNotFound.
  ///
  /// In en, this message translates to:
  /// **'Plan item not found'**
  String get maintenancePlanItemNotFound;

  /// No description provided for @maintenanceServiceRecordNotFound.
  ///
  /// In en, this message translates to:
  /// **'Service record not found'**
  String get maintenanceServiceRecordNotFound;

  /// No description provided for @planItemNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get planItemNameRequired;

  /// No description provided for @planItemNameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be {max} characters or fewer'**
  String planItemNameMaxLength(Object max);

  /// No description provided for @planItemScheduleRequired.
  ///
  /// In en, this message translates to:
  /// **'Set a time interval, a mileage interval, or both'**
  String get planItemScheduleRequired;

  /// No description provided for @planItemDueRequired.
  ///
  /// In en, this message translates to:
  /// **'Set a due date, a due mileage, or both'**
  String get planItemDueRequired;

  /// No description provided for @planItemMileageRequired.
  ///
  /// In en, this message translates to:
  /// **'Mileage is required'**
  String get planItemMileageRequired;

  /// No description provided for @planItemMileageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mileage'**
  String get planItemMileageInvalid;

  /// No description provided for @planItemWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number greater than 0'**
  String get planItemWholeNumber;

  /// No description provided for @planItemDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Date is required'**
  String get planItemDateRequired;

  /// No description provided for @planItemAtLeastOneService.
  ///
  /// In en, this message translates to:
  /// **'Add at least one service'**
  String get planItemAtLeastOneService;

  /// No description provided for @planItemTotalRequired.
  ///
  /// In en, this message translates to:
  /// **'Total is required'**
  String get planItemTotalRequired;

  /// No description provided for @planItemAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get planItemAmountInvalid;

  /// No description provided for @catalogMileageUpdate.
  ///
  /// In en, this message translates to:
  /// **'Mileage Update'**
  String get catalogMileageUpdate;

  /// No description provided for @catalogRoutine.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get catalogRoutine;

  /// No description provided for @catalogOilChange.
  ///
  /// In en, this message translates to:
  /// **'Oil Change'**
  String get catalogOilChange;

  /// No description provided for @catalogAirFilterCabin.
  ///
  /// In en, this message translates to:
  /// **'Air Filter (Cabin)'**
  String get catalogAirFilterCabin;

  /// No description provided for @catalogNewTires.
  ///
  /// In en, this message translates to:
  /// **'New Tires'**
  String get catalogNewTires;

  /// No description provided for @catalogBrakeChange.
  ///
  /// In en, this message translates to:
  /// **'Brake Change'**
  String get catalogBrakeChange;

  /// No description provided for @catalogBrakeFluid.
  ///
  /// In en, this message translates to:
  /// **'Brake Fluid'**
  String get catalogBrakeFluid;

  /// No description provided for @catalogBelts.
  ///
  /// In en, this message translates to:
  /// **'Belts'**
  String get catalogBelts;

  /// No description provided for @catalogFuelFilter.
  ///
  /// In en, this message translates to:
  /// **'Fuel Filter'**
  String get catalogFuelFilter;

  /// No description provided for @catalogWash.
  ///
  /// In en, this message translates to:
  /// **'Wash'**
  String get catalogWash;

  /// No description provided for @catalogBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get catalogBattery;

  /// No description provided for @catalogAirConditioning.
  ///
  /// In en, this message translates to:
  /// **'Air Conditioning'**
  String get catalogAirConditioning;

  /// No description provided for @catalogRotateTires.
  ///
  /// In en, this message translates to:
  /// **'Rotate Tires'**
  String get catalogRotateTires;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @expensesAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expensesAddTooltip;

  /// No description provided for @expensesNoActiveVehicle.
  ///
  /// In en, this message translates to:
  /// **'No active vehicle'**
  String get expensesNoActiveVehicle;

  /// No description provided for @expensesNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to log spend. Fuel here is money only — not a fuel log.'**
  String get expensesNoActiveVehicleBody;

  /// No description provided for @expensesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load expenses'**
  String get expensesLoadError;

  /// No description provided for @expensesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get expensesEmptyTitle;

  /// No description provided for @expensesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Log spend for {vehicleName}. Fuel is money only — not a fuel log.'**
  String expensesEmptyBody(Object vehicleName);

  /// No description provided for @expensesAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expensesAddExpense;

  /// No description provided for @expensesNoMatching.
  ///
  /// In en, this message translates to:
  /// **'No matching expenses'**
  String get expensesNoMatching;

  /// No description provided for @expensesNoMatchingBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different category.'**
  String get expensesNoMatchingBody;

  /// No description provided for @expensesThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get expensesThisMonth;

  /// No description provided for @expensesTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get expensesTotal;

  /// No description provided for @expensesAllFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get expensesAllFilter;

  /// No description provided for @expenseFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get expenseFormEditTitle;

  /// No description provided for @expenseFormAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expenseFormAddTitle;

  /// No description provided for @expenseFormNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to log spend.'**
  String get expenseFormNoActiveVehicleBody;

  /// No description provided for @expenseFormNotFound.
  ///
  /// In en, this message translates to:
  /// **'Expense not found'**
  String get expenseFormNotFound;

  /// No description provided for @expenseFormNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted.'**
  String get expenseFormNotFoundBody;

  /// No description provided for @expenseFormCategory.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get expenseFormCategory;

  /// No description provided for @expenseFormCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get expenseFormCategoryHint;

  /// No description provided for @expenseFormCategorySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expenseFormCategorySheetTitle;

  /// No description provided for @expenseFormAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount *'**
  String get expenseFormAmount;

  /// No description provided for @expenseFormDate.
  ///
  /// In en, this message translates to:
  /// **'Date *'**
  String get expenseFormDate;

  /// No description provided for @expenseFormNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get expenseFormNotes;

  /// No description provided for @expenseFormNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get expenseFormNotesHint;

  /// No description provided for @expenseFormReceiptSection.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get expenseFormReceiptSection;

  /// No description provided for @expenseFormAddReceipt.
  ///
  /// In en, this message translates to:
  /// **'Add receipt photo'**
  String get expenseFormAddReceipt;

  /// No description provided for @expenseFormReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get expenseFormReplace;

  /// No description provided for @expenseFormPartsSection.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get expenseFormPartsSection;

  /// No description provided for @expenseFormAssignPart.
  ///
  /// In en, this message translates to:
  /// **'assign part'**
  String get expenseFormAssignPart;

  /// No description provided for @expenseFormAssignPartTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign part'**
  String get expenseFormAssignPartTitle;

  /// No description provided for @expenseFormAssignPartEmpty.
  ///
  /// In en, this message translates to:
  /// **'No parts in the catalog yet. Add one, then assign it here.'**
  String get expenseFormAssignPartEmpty;

  /// No description provided for @expenseFormAssignPartAllAssigned.
  ///
  /// In en, this message translates to:
  /// **'Every part is already assigned to this expense.'**
  String get expenseFormAssignPartAllAssigned;

  /// No description provided for @expenseFormAddNewPart.
  ///
  /// In en, this message translates to:
  /// **'Add a new part'**
  String get expenseFormAddNewPart;

  /// No description provided for @expenseFormDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete expense'**
  String get expenseFormDeleteButton;

  /// No description provided for @expenseFormDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get expenseFormDeleteTitle;

  /// No description provided for @expenseFormDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the entry and its receipt photo. This cannot be undone.'**
  String get expenseFormDeleteBody;

  /// No description provided for @expenseFormCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera or photo access was denied. You can save without a photo.'**
  String get expenseFormCameraDenied;

  /// No description provided for @expenseFormCameraOption.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get expenseFormCameraOption;

  /// No description provided for @expenseFormPhotoLibraryOption.
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get expenseFormPhotoLibraryOption;

  /// No description provided for @expenseNotFound.
  ///
  /// In en, this message translates to:
  /// **'Expense not found'**
  String get expenseNotFound;

  /// No description provided for @expenseCategoryFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get expenseCategoryFuel;

  /// No description provided for @expenseCategoryMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get expenseCategoryMaintenance;

  /// No description provided for @expenseCategoryInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get expenseCategoryInsurance;

  /// No description provided for @expenseCategoryParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get expenseCategoryParking;

  /// No description provided for @expenseCategoryTolls.
  ///
  /// In en, this message translates to:
  /// **'Tolls'**
  String get expenseCategoryTolls;

  /// No description provided for @expenseCategoryParts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get expenseCategoryParts;

  /// No description provided for @expenseCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseCategoryOther;

  /// No description provided for @expenseCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Category is required'**
  String get expenseCategoryRequired;

  /// No description provided for @expenseAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount is required'**
  String get expenseAmountRequired;

  /// No description provided for @expenseAmountTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than 0'**
  String get expenseAmountTooSmall;

  /// No description provided for @expenseAmountTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Amount must be 999,999.99 or less'**
  String get expenseAmountTooLarge;

  /// No description provided for @expenseDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Date is required'**
  String get expenseDateRequired;

  /// No description provided for @expenseDateTooFarFuture.
  ///
  /// In en, this message translates to:
  /// **'Date cannot be more than one day in the future'**
  String get expenseDateTooFarFuture;

  /// No description provided for @expenseNotesMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Notes must be {max} characters or fewer'**
  String expenseNotesMaxLength(Object max);

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsTitle;

  /// No description provided for @documentsNoActiveVehicle.
  ///
  /// In en, this message translates to:
  /// **'No active vehicle'**
  String get documentsNoActiveVehicle;

  /// No description provided for @documentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get documentsEmptyTitle;

  /// No description provided for @documentsEmptyBodyNoVehicle.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to store insurance, registration, and receipts.'**
  String get documentsEmptyBodyNoVehicle;

  /// No description provided for @documentsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Upload insurance, registration, and receipts for {vehicleName}.'**
  String documentsEmptyBody(Object vehicleName);

  /// No description provided for @documentsAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get documentsAddTooltip;

  /// No description provided for @documentsNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to store documents.'**
  String get documentsNoActiveVehicleBody;

  /// No description provided for @documentsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load documents'**
  String get documentsLoadError;

  /// No description provided for @documentsAddDocument.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get documentsAddDocument;

  /// No description provided for @documentCategoryInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get documentCategoryInsurance;

  /// No description provided for @documentCategoryRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get documentCategoryRegistration;

  /// No description provided for @documentCategoryInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get documentCategoryInvoice;

  /// No description provided for @documentCategoryWarranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get documentCategoryWarranty;

  /// No description provided for @documentCategoryReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get documentCategoryReceipt;

  /// No description provided for @documentCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get documentCategoryOther;

  /// No description provided for @documentFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Document'**
  String get documentFormEditTitle;

  /// No description provided for @documentFormAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Document'**
  String get documentFormAddTitle;

  /// No description provided for @documentFormName.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get documentFormName;

  /// No description provided for @documentFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Insurance Policy 2025'**
  String get documentFormNameHint;

  /// No description provided for @documentFormCategory.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get documentFormCategory;

  /// No description provided for @documentFormCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get documentFormCategoryHint;

  /// No description provided for @documentFormCategorySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get documentFormCategorySheetTitle;

  /// No description provided for @documentFormNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get documentFormNotes;

  /// No description provided for @documentFormNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get documentFormNotesHint;

  /// No description provided for @documentFormFileSection.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get documentFormFileSection;

  /// No description provided for @documentFormAddFile.
  ///
  /// In en, this message translates to:
  /// **'Add file'**
  String get documentFormAddFile;

  /// No description provided for @documentFormReplaceFile.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get documentFormReplaceFile;

  /// No description provided for @documentFormDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete document'**
  String get documentFormDeleteButton;

  /// No description provided for @documentFormDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this document?'**
  String get documentFormDeleteTitle;

  /// No description provided for @documentFormDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the document and its file. This cannot be undone.'**
  String get documentFormDeleteBody;

  /// No description provided for @documentFormFileRequired.
  ///
  /// In en, this message translates to:
  /// **'Please attach a file'**
  String get documentFormFileRequired;

  /// No description provided for @documentFormCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera or photo access was denied. You can save without a file.'**
  String get documentFormCameraDenied;

  /// No description provided for @documentFormCameraOption.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get documentFormCameraOption;

  /// No description provided for @documentFormGalleryOption.
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get documentFormGalleryOption;

  /// No description provided for @documentFormPdfOption.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get documentFormPdfOption;

  /// No description provided for @documentFormPickError.
  ///
  /// In en, this message translates to:
  /// **'Could not pick file. Try again.'**
  String get documentFormPickError;

  /// No description provided for @documentFormNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to store documents.'**
  String get documentFormNoActiveVehicleBody;

  /// No description provided for @documentFormNotFound.
  ///
  /// In en, this message translates to:
  /// **'Document not found'**
  String get documentFormNotFound;

  /// No description provided for @documentFormNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted.'**
  String get documentFormNotFoundBody;

  /// No description provided for @documentFormAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get documentFormAttachFile;

  /// No description provided for @documentFormReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get documentFormReplace;

  /// No description provided for @documentViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get documentViewerTitle;

  /// No description provided for @documentViewerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Document not found'**
  String get documentViewerNotFound;

  /// No description provided for @documentViewerNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This document could not be loaded.'**
  String get documentViewerNotFoundBody;

  /// No description provided for @documentViewerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get documentViewerEdit;

  /// No description provided for @documentViewerNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file'**
  String get documentViewerNoFile;

  /// No description provided for @documentViewerNoFileBody.
  ///
  /// In en, this message translates to:
  /// **'This document has no file attached.'**
  String get documentViewerNoFileBody;

  /// No description provided for @documentViewerRemote.
  ///
  /// In en, this message translates to:
  /// **'Cloud document'**
  String get documentViewerRemote;

  /// No description provided for @documentViewerRemoteBody.
  ///
  /// In en, this message translates to:
  /// **'This file is stored in the cloud and will sync when online.'**
  String get documentViewerRemoteBody;

  /// No description provided for @documentInfoCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get documentInfoCategory;

  /// No description provided for @documentInfoAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get documentInfoAdded;

  /// No description provided for @documentInfoNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get documentInfoNotes;

  /// No description provided for @documentInfoStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get documentInfoStatus;

  /// No description provided for @documentStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get documentStatusSynced;

  /// No description provided for @documentStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get documentStatusQueued;

  /// No description provided for @documentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Document not found'**
  String get documentNotFound;

  /// No description provided for @partsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get partsTitle;

  /// No description provided for @partsAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a part'**
  String get partsAddTooltip;

  /// No description provided for @partsNoActiveVehicle.
  ///
  /// In en, this message translates to:
  /// **'No active vehicle'**
  String get partsNoActiveVehicle;

  /// No description provided for @partsNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to keep a parts catalog for it.'**
  String get partsNoActiveVehicleBody;

  /// No description provided for @partsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load parts'**
  String get partsLoadError;

  /// No description provided for @partsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No parts yet'**
  String get partsEmptyTitle;

  /// No description provided for @partsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add parts for {vehicleName}. Assign them when you log a service or an expense.'**
  String partsEmptyBody(Object vehicleName);

  /// No description provided for @partsAddPart.
  ///
  /// In en, this message translates to:
  /// **'Add a part'**
  String get partsAddPart;

  /// No description provided for @partFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Part'**
  String get partFormEditTitle;

  /// No description provided for @partFormAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Part'**
  String get partFormAddTitle;

  /// No description provided for @partFormName.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get partFormName;

  /// No description provided for @partFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'Oil filter'**
  String get partFormNameHint;

  /// No description provided for @partFormBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get partFormBrand;

  /// No description provided for @partFormBrandHint.
  ///
  /// In en, this message translates to:
  /// **'Bosch'**
  String get partFormBrandHint;

  /// No description provided for @partFormPartNumber.
  ///
  /// In en, this message translates to:
  /// **'Part number'**
  String get partFormPartNumber;

  /// No description provided for @partFormPartNumberHint.
  ///
  /// In en, this message translates to:
  /// **'OF-1234'**
  String get partFormPartNumberHint;

  /// No description provided for @partFormNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get partFormNotes;

  /// No description provided for @partFormNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Size, source, or fitment'**
  String get partFormNotesHint;

  /// No description provided for @partDuplicate.
  ///
  /// In en, this message translates to:
  /// **'That part is already in this vehicle'**
  String get partDuplicate;

  /// No description provided for @partNotFound.
  ///
  /// In en, this message translates to:
  /// **'Part not found'**
  String get partNotFound;

  /// No description provided for @partNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get partNameRequired;

  /// No description provided for @partNameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be {max} characters or fewer'**
  String partNameMaxLength(Object max);

  /// No description provided for @partBrandMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Brand must be {max} characters or fewer'**
  String partBrandMaxLength(Object max);

  /// No description provided for @partNumberMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Part number must be {max} characters or fewer'**
  String partNumberMaxLength(Object max);

  /// No description provided for @partNotesMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Notes must be {max} characters or fewer'**
  String partNotesMaxLength(Object max);

  /// No description provided for @fuelLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Refuel'**
  String get fuelLogsTitle;

  /// No description provided for @fuelLogsTypesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Fuel Types'**
  String get fuelLogsTypesTooltip;

  /// No description provided for @fuelLogsAddChargeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a charge'**
  String get fuelLogsAddChargeTooltip;

  /// No description provided for @fuelLogsAddRefuelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a refill'**
  String get fuelLogsAddRefuelTooltip;

  /// No description provided for @fuelLogsNoActiveVehicle.
  ///
  /// In en, this message translates to:
  /// **'No active vehicle'**
  String get fuelLogsNoActiveVehicle;

  /// No description provided for @fuelLogsNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to log fuel or charging.'**
  String get fuelLogsNoActiveVehicleBody;

  /// No description provided for @fuelLogsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load {title}'**
  String fuelLogsLoadError(Object title);

  /// No description provided for @fuelLogsEmptyTitleCharges.
  ///
  /// In en, this message translates to:
  /// **'No charges yet'**
  String get fuelLogsEmptyTitleCharges;

  /// No description provided for @fuelLogsEmptyTitleRefuels.
  ///
  /// In en, this message translates to:
  /// **'No refuels yet'**
  String get fuelLogsEmptyTitleRefuels;

  /// No description provided for @fuelLogsEmptyBodyCharges.
  ///
  /// In en, this message translates to:
  /// **'Log charging for {vehicleName}.'**
  String fuelLogsEmptyBodyCharges(Object vehicleName);

  /// No description provided for @fuelLogsEmptyBodyRefuels.
  ///
  /// In en, this message translates to:
  /// **'Log a refill for {vehicleName}.'**
  String fuelLogsEmptyBodyRefuels(Object vehicleName);

  /// No description provided for @fuelLogsNoMatching.
  ///
  /// In en, this message translates to:
  /// **'No matching logs'**
  String get fuelLogsNoMatching;

  /// No description provided for @fuelLogsNoMatchingBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different fuel type or date filter.'**
  String get fuelLogsNoMatchingBody;

  /// No description provided for @fuelLogsAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get fuelLogsAllTypes;

  /// No description provided for @fuelLogsAllDates.
  ///
  /// In en, this message translates to:
  /// **'All dates'**
  String get fuelLogsAllDates;

  /// No description provided for @fuelLogsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get fuelLogsThisMonth;

  /// No description provided for @fuelLogFormTypeSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel Type'**
  String get fuelLogFormTypeSheetTitle;

  /// No description provided for @fuelLogFormAddFuelType.
  ///
  /// In en, this message translates to:
  /// **'Add fuel type'**
  String get fuelLogFormAddFuelType;

  /// No description provided for @fuelLogFormTypesLink.
  ///
  /// In en, this message translates to:
  /// **'Fuel Types'**
  String get fuelLogFormTypesLink;

  /// No description provided for @fuelLogFormDate.
  ///
  /// In en, this message translates to:
  /// **'Date *'**
  String get fuelLogFormDate;

  /// No description provided for @fuelLogFormFuelType.
  ///
  /// In en, this message translates to:
  /// **'Fuel Type *'**
  String get fuelLogFormFuelType;

  /// No description provided for @fuelLogFormFuelTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Add a fuel type'**
  String get fuelLogFormFuelTypeHint;

  /// No description provided for @fuelLogFormSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get fuelLogFormSelect;

  /// No description provided for @fuelLogFormAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount *'**
  String get fuelLogFormAmount;

  /// No description provided for @fuelLogFormCost.
  ///
  /// In en, this message translates to:
  /// **'Cost *'**
  String get fuelLogFormCost;

  /// No description provided for @fuelTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel Types'**
  String get fuelTypesTitle;

  /// No description provided for @fuelTypesAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a fuel type'**
  String get fuelTypesAddTooltip;

  /// No description provided for @fuelTypesNoActiveVehicle.
  ///
  /// In en, this message translates to:
  /// **'No active vehicle'**
  String get fuelTypesNoActiveVehicle;

  /// No description provided for @fuelTypesNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to keep a fuel type catalog.'**
  String get fuelTypesNoActiveVehicleBody;

  /// No description provided for @fuelTypesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load fuel types'**
  String get fuelTypesLoadError;

  /// No description provided for @fuelTypesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No fuel types yet'**
  String get fuelTypesEmptyTitle;

  /// No description provided for @fuelTypesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add petrol, diesel, electricity, or your own names.'**
  String get fuelTypesEmptyBody;

  /// No description provided for @fuelTypesAddFuelType.
  ///
  /// In en, this message translates to:
  /// **'Add fuel type'**
  String get fuelTypesAddFuelType;

  /// No description provided for @fuelTypesNoMatching.
  ///
  /// In en, this message translates to:
  /// **'No matching types'**
  String get fuelTypesNoMatching;

  /// No description provided for @fuelTypesNoMatchingBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different filter or add a type.'**
  String get fuelTypesNoMatchingBody;

  /// No description provided for @fuelTypesAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get fuelTypesAll;

  /// No description provided for @fuelTypesLiquid.
  ///
  /// In en, this message translates to:
  /// **'Liquid'**
  String get fuelTypesLiquid;

  /// No description provided for @fuelTypesElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get fuelTypesElectric;

  /// No description provided for @fuelTypeFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Fuel Type'**
  String get fuelTypeFormEditTitle;

  /// No description provided for @fuelTypeFormAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Fuel Type'**
  String get fuelTypeFormAddTitle;

  /// No description provided for @fuelTypeFormName.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get fuelTypeFormName;

  /// No description provided for @fuelTypeFormNameHintElectric.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get fuelTypeFormNameHintElectric;

  /// No description provided for @fuelTypeFormNameHintPetrol.
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get fuelTypeFormNameHintPetrol;

  /// No description provided for @fuelTypeFormKind.
  ///
  /// In en, this message translates to:
  /// **'Kind *'**
  String get fuelTypeFormKind;

  /// No description provided for @fuelTypeFormUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit *'**
  String get fuelTypeFormUnit;

  /// No description provided for @fuelTypeDuplicate.
  ///
  /// In en, this message translates to:
  /// **'That fuel type is already in your catalog'**
  String get fuelTypeDuplicate;

  /// No description provided for @fuelTypeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Fuel type not found'**
  String get fuelTypeNotFound;

  /// No description provided for @fuelLogNotFound.
  ///
  /// In en, this message translates to:
  /// **'Log not found'**
  String get fuelLogNotFound;

  /// No description provided for @fuelTypeMismatch.
  ///
  /// In en, this message translates to:
  /// **'That fuel type does not match this vehicle'**
  String get fuelTypeMismatch;

  /// No description provided for @fuelNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get fuelNameRequired;

  /// No description provided for @fuelNameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be {max} characters or fewer'**
  String fuelNameMaxLength(Object max);

  /// No description provided for @fuelUnitInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid unit'**
  String get fuelUnitInvalid;

  /// No description provided for @fuelDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Date is required'**
  String get fuelDateRequired;

  /// No description provided for @fuelDateTooFuture.
  ///
  /// In en, this message translates to:
  /// **'Date cannot be in the future'**
  String get fuelDateTooFuture;

  /// No description provided for @fuelTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Fuel type is required'**
  String get fuelTypeRequired;

  /// No description provided for @fuelAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount is required'**
  String get fuelAmountRequired;

  /// No description provided for @fuelAmountTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than 0'**
  String get fuelAmountTooSmall;

  /// No description provided for @fuelAmountTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Amount is too large'**
  String get fuelAmountTooLarge;

  /// No description provided for @fuelCostRequired.
  ///
  /// In en, this message translates to:
  /// **'Cost is required'**
  String get fuelCostRequired;

  /// No description provided for @fuelCostInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid cost'**
  String get fuelCostInvalid;

  /// No description provided for @fuelCostTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Cost is too large'**
  String get fuelCostTooLarge;

  /// No description provided for @fuelKindLiquid.
  ///
  /// In en, this message translates to:
  /// **'Liquid'**
  String get fuelKindLiquid;

  /// No description provided for @fuelKindElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get fuelKindElectric;

  /// No description provided for @fuelLogRefuel.
  ///
  /// In en, this message translates to:
  /// **'Refuel'**
  String get fuelLogRefuel;

  /// No description provided for @fuelLogCharge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get fuelLogCharge;

  /// No description provided for @fuelLogAddRefuel.
  ///
  /// In en, this message translates to:
  /// **'Add Refuel'**
  String get fuelLogAddRefuel;

  /// No description provided for @fuelLogAddCharge.
  ///
  /// In en, this message translates to:
  /// **'Add Charge'**
  String get fuelLogAddCharge;

  /// No description provided for @fuelLogEditRefuel.
  ///
  /// In en, this message translates to:
  /// **'Edit Refuel'**
  String get fuelLogEditRefuel;

  /// No description provided for @fuelLogEditCharge.
  ///
  /// In en, this message translates to:
  /// **'Edit Charge'**
  String get fuelLogEditCharge;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free Plan'**
  String get settingsFreePlan;

  /// No description provided for @settingsManageVehicles.
  ///
  /// In en, this message translates to:
  /// **'Manage vehicles'**
  String get settingsManageVehicles;

  /// No description provided for @settingsDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get settingsDocuments;

  /// No description provided for @settingsLocalization.
  ///
  /// In en, this message translates to:
  /// **'Localization'**
  String get settingsLocalization;

  /// No description provided for @settingsUnitFormat.
  ///
  /// In en, this message translates to:
  /// **'Unit and Format'**
  String get settingsUnitFormat;

  /// No description provided for @settingsSyncSection.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsSyncSection;

  /// No description provided for @settingsFamilySection.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get settingsFamilySection;

  /// No description provided for @settingsLoadingFamily.
  ///
  /// In en, this message translates to:
  /// **'Loading family...'**
  String get settingsLoadingFamily;

  /// No description provided for @settingsFamilyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load family'**
  String get settingsFamilyLoadError;

  /// No description provided for @settingsFamilyTapRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get settingsFamilyTapRetry;

  /// No description provided for @settingsFamilyFallback.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get settingsFamilyFallback;

  /// No description provided for @settingsFamilySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create or join a family to share vehicles'**
  String get settingsFamilySubtitle;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get settingsSyncNow;

  /// No description provided for @settingsSyncStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get settingsSyncStatusFailed;

  /// No description provided for @settingsSyncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get settingsSyncStatusSyncing;

  /// No description provided for @settingsSyncStatusJustSynced.
  ///
  /// In en, this message translates to:
  /// **'Just synced'**
  String get settingsSyncStatusJustSynced;

  /// No description provided for @settingsSyncStatusMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced {minutes}m ago'**
  String settingsSyncStatusMinutesAgo(Object minutes);

  /// No description provided for @settingsSyncStatusHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced {hours}h ago'**
  String settingsSyncStatusHoursAgo(Object hours);

  /// No description provided for @settingsSyncStatusDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced {days}d ago'**
  String settingsSyncStatusDaysAgo(Object days);

  /// No description provided for @settingsSyncTapToSync.
  ///
  /// In en, this message translates to:
  /// **'Tap to sync your data'**
  String get settingsSyncTapToSync;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profilePhoto;

  /// No description provided for @profilePhotoTapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change photo'**
  String get profilePhotoTapToChange;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get profileNameHint;

  /// No description provided for @profileContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact Number'**
  String get profileContactPhone;

  /// No description provided for @profileContactPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number (optional)'**
  String get profileContactPhoneHint;

  /// No description provided for @profileAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileAddress;

  /// No description provided for @profileAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get profileAddressHint;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profileEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get profileEmailVerified;

  /// No description provided for @profileEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get profileEmailNotVerified;

  /// No description provided for @profileMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get profileMemberSince;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get profileSave;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileSaved;

  /// No description provided for @profileCompleteBanner.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get profileCompleteBanner;

  /// No description provided for @profileCompleteBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get profileCompleteBannerAction;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get profileDeleteAccountTitle;

  /// No description provided for @profileDeleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This will deactivate your account and archive all your vehicles. You will not be able to sign in again.'**
  String get profileDeleteAccountBody;

  /// No description provided for @profileDeleteAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm'**
  String get profileDeleteAccountPassword;

  /// No description provided for @profileDeleteAccountBlocked.
  ///
  /// In en, this message translates to:
  /// **'You are the Primary Owner of a family. Transfer ownership or dissolve your family before deleting your account.'**
  String get profileDeleteAccountBlocked;

  /// No description provided for @profileDeleteAccountSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get profileDeleteAccountSuccess;

  /// No description provided for @localizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Localization'**
  String get localizationTitle;

  /// No description provided for @localizationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get localizationLanguage;

  /// No description provided for @localizationHelper.
  ///
  /// In en, this message translates to:
  /// **'App copy stays in English for now. This stores your choice.'**
  String get localizationHelper;

  /// No description provided for @unitsFormatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unit and Format'**
  String get unitsFormatsTitle;

  /// No description provided for @unitsFormatsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get unitsFormatsCurrency;

  /// No description provided for @unitsFormatsCurrencyHelper.
  ///
  /// In en, this message translates to:
  /// **'USD shows cents. MMK shows whole kyat, and large amounts use K or M (25K, 23M).'**
  String get unitsFormatsCurrencyHelper;

  /// No description provided for @unitsFormatsLengthUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit of length'**
  String get unitsFormatsLengthUnit;

  /// No description provided for @unitsFormatsLengthUnitHelper.
  ///
  /// In en, this message translates to:
  /// **'Odometer, service intervals, and due mileage follow this unit.'**
  String get unitsFormatsLengthUnitHelper;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageMyanmar.
  ///
  /// In en, this message translates to:
  /// **'Myanmar'**
  String get languageMyanmar;

  /// No description provided for @currencyUSD.
  ///
  /// In en, this message translates to:
  /// **'US Dollar (USD)'**
  String get currencyUSD;

  /// No description provided for @currencyMMK.
  ///
  /// In en, this message translates to:
  /// **'Myanmar Kyat (MMK)'**
  String get currencyMMK;

  /// No description provided for @unitMilesShort.
  ///
  /// In en, this message translates to:
  /// **'mi'**
  String get unitMilesShort;

  /// No description provided for @unitKilometersShort.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get unitKilometersShort;

  /// No description provided for @unitMilesFull.
  ///
  /// In en, this message translates to:
  /// **'Miles'**
  String get unitMilesFull;

  /// No description provided for @unitKilometersFull.
  ///
  /// In en, this message translates to:
  /// **'Kilometers'**
  String get unitKilometersFull;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications'**
  String get notificationsLoadError;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Due reminders will show up here.'**
  String get notificationsEmptyBody;

  /// No description provided for @notificationsMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get notificationsMarkDone;

  /// No description provided for @notificationsDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get notificationsDismiss;

  /// No description provided for @notificationsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get notificationsRestore;

  /// No description provided for @insuranceTitle.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get insuranceTitle;

  /// No description provided for @insuranceNoActiveVehicle.
  ///
  /// In en, this message translates to:
  /// **'No active vehicle'**
  String get insuranceNoActiveVehicle;

  /// No description provided for @insuranceComingLater.
  ///
  /// In en, this message translates to:
  /// **'Insurance coming later'**
  String get insuranceComingLater;

  /// No description provided for @insuranceNoActiveVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'Register a vehicle to keep policies against it.'**
  String get insuranceNoActiveVehicleBody;

  /// No description provided for @insuranceEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Policies for {vehicleName} will live here. For now, store insurance papers in Documents.'**
  String insuranceEmptyBody(Object vehicleName);

  /// No description provided for @familyJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Family'**
  String get familyJoinTitle;

  /// No description provided for @familyCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Family'**
  String get familyCreateTitle;

  /// No description provided for @familyJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining family...'**
  String get familyJoining;

  /// No description provided for @familyCreateHeading.
  ///
  /// In en, this message translates to:
  /// **'Create Your Family'**
  String get familyCreateHeading;

  /// No description provided for @familyCreateBody.
  ///
  /// In en, this message translates to:
  /// **'Invite members to share vehicles and manage access together.'**
  String get familyCreateBody;

  /// No description provided for @familyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Family Name'**
  String get familyNameLabel;

  /// No description provided for @familyNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Smith Family'**
  String get familyNameHint;

  /// No description provided for @familyNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Family name is required'**
  String get familyNameRequired;

  /// No description provided for @familyNameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be 100 characters or fewer'**
  String get familyNameMaxLength;

  /// No description provided for @familyCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get familyCreating;

  /// No description provided for @familyCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Family'**
  String get familyCreateButton;

  /// No description provided for @familyCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Family created! Share the code with family members.'**
  String get familyCreatedSuccess;

  /// No description provided for @familyCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create family: {error}'**
  String familyCreateFailed(Object error);

  /// No description provided for @familyJoinedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Joined family successfully!'**
  String get familyJoinedSuccess;

  /// No description provided for @familyJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join family: {error}'**
  String familyJoinFailed(Object error);

  /// No description provided for @familyCreatedHeading.
  ///
  /// In en, this message translates to:
  /// **'Family Created!'**
  String get familyCreatedHeading;

  /// No description provided for @familyCreatedBody.
  ///
  /// In en, this message translates to:
  /// **'Share this code with family members so they can join.'**
  String get familyCreatedBody;

  /// No description provided for @familyShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share Code'**
  String get familyShareCode;

  /// No description provided for @familyShareCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Scan with DCO app to join'**
  String get familyShareCodeHelper;

  /// No description provided for @familyCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get familyCopyCode;

  /// No description provided for @familyCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied!'**
  String get familyCodeCopied;

  /// No description provided for @familyShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get familyShare;

  /// No description provided for @familyShareText.
  ///
  /// In en, this message translates to:
  /// **'Join my DCO family! Code: {code}'**
  String familyShareText(Object code);

  /// No description provided for @familyCodeExpiryHelper.
  ///
  /// In en, this message translates to:
  /// **'Code expires in 7 days. Regenerating invalidates the old code.'**
  String get familyCodeExpiryHelper;

  /// No description provided for @familyGoToManagement.
  ///
  /// In en, this message translates to:
  /// **'Go to Family Management'**
  String get familyGoToManagement;

  /// No description provided for @familyManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get familyManagementTitle;

  /// No description provided for @familyManagementMembersTab.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get familyManagementMembersTab;

  /// No description provided for @familyManagementVehiclesTab.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get familyManagementVehiclesTab;

  /// No description provided for @familyManagementInviteTab.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get familyManagementInviteTab;

  /// No description provided for @familyManagementJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Family'**
  String get familyManagementJoinTitle;

  /// No description provided for @familyManagementJoinHint.
  ///
  /// In en, this message translates to:
  /// **'Enter share code'**
  String get familyManagementJoinHint;

  /// No description provided for @familyManagementJoinLabel.
  ///
  /// In en, this message translates to:
  /// **'Share Code'**
  String get familyManagementJoinLabel;

  /// No description provided for @familyManagementJoinButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get familyManagementJoinButton;

  /// No description provided for @familyManagementNoFamily.
  ///
  /// In en, this message translates to:
  /// **'No family yet'**
  String get familyManagementNoFamily;

  /// No description provided for @familyManagementNoFamilyBody.
  ///
  /// In en, this message translates to:
  /// **'Create a family to share vehicles,\nor join an existing one.'**
  String get familyManagementNoFamilyBody;

  /// No description provided for @familyManagementCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Family'**
  String get familyManagementCreateButton;

  /// No description provided for @familyManagementJoinFamilyButton.
  ///
  /// In en, this message translates to:
  /// **'Join Family'**
  String get familyManagementJoinFamilyButton;

  /// No description provided for @membersTabEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get membersTabEmptyTitle;

  /// No description provided for @membersTabEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Invite family to get started.'**
  String get membersTabEmptyBody;

  /// No description provided for @membersTabManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage {name}'**
  String membersTabManageTitle(Object name);

  /// No description provided for @membersTabRoleSection.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get membersTabRoleSection;

  /// No description provided for @membersTabRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get membersTabRoleMember;

  /// No description provided for @membersTabRoleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get membersTabRoleDriver;

  /// No description provided for @membersTabSaveRole.
  ///
  /// In en, this message translates to:
  /// **'Save Role'**
  String get membersTabSaveRole;

  /// No description provided for @membersTabRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove from Family'**
  String get membersTabRemoveButton;

  /// No description provided for @membersTabRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Member?'**
  String get membersTabRemoveTitle;

  /// No description provided for @membersTabRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the family?'**
  String membersTabRemoveBody(Object name);

  /// No description provided for @membersTabRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get membersTabRemoveAction;

  /// No description provided for @membersTabYouBadge.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get membersTabYouBadge;

  /// No description provided for @membersTabPrimaryOwner.
  ///
  /// In en, this message translates to:
  /// **'Primary Owner'**
  String get membersTabPrimaryOwner;

  /// No description provided for @membersTabLicenseValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get membersTabLicenseValid;

  /// No description provided for @membersTabLicenseExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get membersTabLicenseExpiringSoon;

  /// No description provided for @membersTabLicenseExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get membersTabLicenseExpired;

  /// No description provided for @membersTabLicenseNone.
  ///
  /// In en, this message translates to:
  /// **'No License'**
  String get membersTabLicenseNone;

  /// No description provided for @membersTabVehicleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{# vehicle} other{# vehicles}}'**
  String membersTabVehicleCount(num count);

  /// No description provided for @vehiclesTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Vehicles'**
  String get vehiclesTabTitle;

  /// No description provided for @vehiclesTabAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get vehiclesTabAdd;

  /// No description provided for @vehiclesTabEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No vehicles in family'**
  String get vehiclesTabEmptyTitle;

  /// No description provided for @vehiclesTabEmptyBodyOwner.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add\" to share a vehicle with your family'**
  String get vehiclesTabEmptyBodyOwner;

  /// No description provided for @vehiclesTabEmptyBodyNonOwner.
  ///
  /// In en, this message translates to:
  /// **'Ask the owner to share a vehicle'**
  String get vehiclesTabEmptyBodyNonOwner;

  /// No description provided for @vehiclesTabSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a vehicle to share'**
  String get vehiclesTabSelectTitle;

  /// No description provided for @vehiclesTabSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose vehicles from your garage to share with your family'**
  String get vehiclesTabSelectSubtitle;

  /// No description provided for @vehiclesTabNoVehiclesToAdd.
  ///
  /// In en, this message translates to:
  /// **'No vehicles available to add. Add vehicles to your garage first.'**
  String get vehiclesTabNoVehiclesToAdd;

  /// No description provided for @vehiclesTabAddSelected.
  ///
  /// In en, this message translates to:
  /// **'Add {count,plural, =1{1 vehicle} other{{count} vehicles}}'**
  String vehiclesTabAddSelected(num count);

  /// No description provided for @vehiclesTabRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Vehicle'**
  String get vehiclesTabRemoveTitle;

  /// No description provided for @vehiclesTabRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {vehicleName} from family?'**
  String vehiclesTabRemoveBody(Object vehicleName);

  /// No description provided for @inviteTabHeading.
  ///
  /// In en, this message translates to:
  /// **'Share Your Family'**
  String get inviteTabHeading;

  /// No description provided for @inviteTabBody.
  ///
  /// In en, this message translates to:
  /// **'Invite family members to join and share vehicles.'**
  String get inviteTabBody;

  /// No description provided for @inviteTabShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share Code'**
  String get inviteTabShareCode;

  /// No description provided for @inviteTabShareCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Scan with DCO app to join'**
  String get inviteTabShareCodeHelper;

  /// No description provided for @inviteTabCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get inviteTabCopyCode;

  /// No description provided for @inviteTabCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied!'**
  String get inviteTabCodeCopied;

  /// No description provided for @inviteTabShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get inviteTabShare;

  /// No description provided for @inviteTabShareText.
  ///
  /// In en, this message translates to:
  /// **'Join my DCO family! Code: {code}'**
  String inviteTabShareText(Object code);

  /// No description provided for @inviteTabRegenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Code'**
  String get inviteTabRegenerateButton;

  /// No description provided for @inviteTabRegenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Share Code?'**
  String get inviteTabRegenerateTitle;

  /// No description provided for @inviteTabRegenerateBody.
  ///
  /// In en, this message translates to:
  /// **'This will invalidate the current code. Members with the old code won\'t be able to join.'**
  String get inviteTabRegenerateBody;

  /// No description provided for @inviteTabRegenerateAction.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get inviteTabRegenerateAction;

  /// No description provided for @inviteTabCodeExpiryHelper.
  ///
  /// In en, this message translates to:
  /// **'Code expires in 7 days. Regenerating invalidates the old code.'**
  String get inviteTabCodeExpiryHelper;

  /// No description provided for @carDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Car Detail'**
  String get carDetailTitle;

  /// No description provided for @carDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Vehicle not found'**
  String get carDetailNotFound;

  /// No description provided for @carDetailNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This vehicle could not be loaded.'**
  String get carDetailNotFoundBody;

  /// No description provided for @carDetailIdentitySection.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Identity'**
  String get carDetailIdentitySection;

  /// No description provided for @carDetailVinPrefix.
  ///
  /// In en, this message translates to:
  /// **'VIN: '**
  String get carDetailVinPrefix;

  /// No description provided for @carDetailDocumentsSection.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get carDetailDocumentsSection;

  /// No description provided for @carDetailAddDocument.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get carDetailAddDocument;

  /// No description provided for @carDetailNoDocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get carDetailNoDocuments;

  /// No description provided for @carDetailNoDocumentsBody.
  ///
  /// In en, this message translates to:
  /// **'Add registration, insurance, or other documents.'**
  String get carDetailNoDocumentsBody;

  /// No description provided for @carDetailAddDocumentAction.
  ///
  /// In en, this message translates to:
  /// **'Add Document'**
  String get carDetailAddDocumentAction;

  /// No description provided for @carDetailDriversSection.
  ///
  /// In en, this message translates to:
  /// **'Assigned Drivers'**
  String get carDetailDriversSection;

  /// No description provided for @carDetailManageDrivers.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get carDetailManageDrivers;

  /// No description provided for @carDetailNoDrivers.
  ///
  /// In en, this message translates to:
  /// **'No drivers assigned'**
  String get carDetailNoDrivers;

  /// No description provided for @carDetailNoDriversBody.
  ///
  /// In en, this message translates to:
  /// **'Add family members as drivers for this vehicle.'**
  String get carDetailNoDriversBody;

  /// No description provided for @carDetailAssignDriver.
  ///
  /// In en, this message translates to:
  /// **'Assign Driver'**
  String get carDetailAssignDriver;

  /// No description provided for @carDetailLicenseValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get carDetailLicenseValid;

  /// No description provided for @carDetailLicenseExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get carDetailLicenseExpiringSoon;

  /// No description provided for @carDetailLicenseExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get carDetailLicenseExpired;

  /// No description provided for @carDetailLicenseNone.
  ///
  /// In en, this message translates to:
  /// **'No License'**
  String get carDetailLicenseNone;

  /// No description provided for @carDetailFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Full Access'**
  String get carDetailFullAccess;

  /// No description provided for @carDetailDriveOnly.
  ///
  /// In en, this message translates to:
  /// **'Drive Only'**
  String get carDetailDriveOnly;

  /// No description provided for @carDetailQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get carDetailQuickActions;

  /// No description provided for @carDetailLogService.
  ///
  /// In en, this message translates to:
  /// **'Log Service'**
  String get carDetailLogService;

  /// No description provided for @carDetailLogFuel.
  ///
  /// In en, this message translates to:
  /// **'Log Fuel'**
  String get carDetailLogFuel;

  /// No description provided for @carDetailAddDocumentButton.
  ///
  /// In en, this message translates to:
  /// **'Add Document'**
  String get carDetailAddDocumentButton;

  /// No description provided for @carDetailManageDriversButton.
  ///
  /// In en, this message translates to:
  /// **'Manage Drivers'**
  String get carDetailManageDriversButton;

  /// No description provided for @carDetailManageDriversSheet.
  ///
  /// In en, this message translates to:
  /// **'Manage Drivers'**
  String get carDetailManageDriversSheet;

  /// No description provided for @carDetailCurrentDrivers.
  ///
  /// In en, this message translates to:
  /// **'Current Drivers'**
  String get carDetailCurrentDrivers;

  /// No description provided for @carDetailAddDriver.
  ///
  /// In en, this message translates to:
  /// **'Add Driver'**
  String get carDetailAddDriver;

  /// No description provided for @carDetailAllAssigned.
  ///
  /// In en, this message translates to:
  /// **'All family members are already assigned'**
  String get carDetailAllAssigned;

  /// No description provided for @carDetailLicensePrefix.
  ///
  /// In en, this message translates to:
  /// **'License: '**
  String get carDetailLicensePrefix;

  /// No description provided for @carDetailAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get carDetailAssign;

  /// No description provided for @userDetailProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get userDetailProfileTitle;

  /// No description provided for @userDetailMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Member Detail'**
  String get userDetailMemberTitle;

  /// No description provided for @userDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userDetailNotFound;

  /// No description provided for @userDetailTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get userDetailTakePhoto;

  /// No description provided for @userDetailChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get userDetailChooseGallery;

  /// No description provided for @userDetailUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload: {error}'**
  String userDetailUploadFailed(Object error);

  /// No description provided for @userDetailEditLicenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Driving License'**
  String get userDetailEditLicenseTitle;

  /// No description provided for @userDetailLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'License Number'**
  String get userDetailLicenseNumber;

  /// No description provided for @userDetailLicenseNumberHint.
  ///
  /// In en, this message translates to:
  /// **'D1234567'**
  String get userDetailLicenseNumberHint;

  /// No description provided for @userDetailIssuingCountry.
  ///
  /// In en, this message translates to:
  /// **'Issuing Country (ISO)'**
  String get userDetailIssuingCountry;

  /// No description provided for @userDetailIssuingCountryHint.
  ///
  /// In en, this message translates to:
  /// **'US'**
  String get userDetailIssuingCountryHint;

  /// No description provided for @userDetailExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date (YYYY-MM-DD)'**
  String get userDetailExpiryDate;

  /// No description provided for @userDetailExpiryDateHint.
  ///
  /// In en, this message translates to:
  /// **'2028-12-31'**
  String get userDetailExpiryDateHint;

  /// No description provided for @userDetailCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get userDetailCategories;

  /// No description provided for @userDetailCategoriesHint.
  ///
  /// In en, this message translates to:
  /// **'B, BE'**
  String get userDetailCategoriesHint;

  /// No description provided for @userDetailLeaveFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Family?'**
  String get userDetailLeaveFamilyTitle;

  /// No description provided for @userDetailLeaveFamilyBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this family? You will lose access to shared vehicles.'**
  String get userDetailLeaveFamilyBody;

  /// No description provided for @userDetailLeaveFamilyAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get userDetailLeaveFamilyAction;

  /// No description provided for @userDetailLeftFamily.
  ///
  /// In en, this message translates to:
  /// **'Left family'**
  String get userDetailLeftFamily;

  /// No description provided for @userDetailRemoveMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Member?'**
  String get userDetailRemoveMemberTitle;

  /// No description provided for @userDetailRemoveMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this member from the family? They will lose access to all shared vehicles.'**
  String get userDetailRemoveMemberBody;

  /// No description provided for @userDetailRemoveMemberAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get userDetailRemoveMemberAction;

  /// No description provided for @userDetailMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get userDetailMemberRemoved;

  /// No description provided for @userDetailUploadLicensePhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload License Photo'**
  String get userDetailUploadLicensePhoto;

  /// No description provided for @userDetailPrimaryOwner.
  ///
  /// In en, this message translates to:
  /// **'Primary Owner'**
  String get userDetailPrimaryOwner;

  /// No description provided for @userDetailMemberRole.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get userDetailMemberRole;

  /// No description provided for @userDetailDriverRole.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get userDetailDriverRole;

  /// No description provided for @userDetailDrivingLicenseSection.
  ///
  /// In en, this message translates to:
  /// **'Driving License'**
  String get userDetailDrivingLicenseSection;

  /// No description provided for @userDetailEditLicense.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get userDetailEditLicense;

  /// No description provided for @userDetailUploadLicense.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get userDetailUploadLicense;

  /// No description provided for @userDetailNoLicense.
  ///
  /// In en, this message translates to:
  /// **'No license uploaded'**
  String get userDetailNoLicense;

  /// No description provided for @userDetailNoLicenseBody.
  ///
  /// In en, this message translates to:
  /// **'Add your driving license to track expiry and share with family.'**
  String get userDetailNoLicenseBody;

  /// No description provided for @userDetailUploadLicenseAction.
  ///
  /// In en, this message translates to:
  /// **'Upload License'**
  String get userDetailUploadLicenseAction;

  /// No description provided for @userDetailFront.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get userDetailFront;

  /// No description provided for @userDetailBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get userDetailBack;

  /// No description provided for @userDetailExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get userDetailExpires;

  /// No description provided for @userDetailNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get userDetailNumber;

  /// No description provided for @userDetailCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get userDetailCountry;

  /// No description provided for @userDetailLicenseValid.
  ///
  /// In en, this message translates to:
  /// **'License Valid'**
  String get userDetailLicenseValid;

  /// No description provided for @userDetailLicenseExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get userDetailLicenseExpiringSoon;

  /// No description provided for @userDetailLicenseExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get userDetailLicenseExpired;

  /// No description provided for @userDetailLicenseNone.
  ///
  /// In en, this message translates to:
  /// **'No License'**
  String get userDetailLicenseNone;

  /// No description provided for @userDetailAccessLevelSection.
  ///
  /// In en, this message translates to:
  /// **'Access Level'**
  String get userDetailAccessLevelSection;

  /// No description provided for @userDetailPrimaryOwnerDescription.
  ///
  /// In en, this message translates to:
  /// **'Primary Owner'**
  String get userDetailPrimaryOwnerDescription;

  /// No description provided for @userDetailFullControl.
  ///
  /// In en, this message translates to:
  /// **'Full control over family'**
  String get userDetailFullControl;

  /// No description provided for @userDetailManageAllVehicles.
  ///
  /// In en, this message translates to:
  /// **'Manage all vehicles'**
  String get userDetailManageAllVehicles;

  /// No description provided for @userDetailAddRemoveMembers.
  ///
  /// In en, this message translates to:
  /// **'Add/remove members'**
  String get userDetailAddRemoveMembers;

  /// No description provided for @userDetailAssignDriversPerm.
  ///
  /// In en, this message translates to:
  /// **'Assign drivers'**
  String get userDetailAssignDriversPerm;

  /// No description provided for @userDetailTransferOwnership.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get userDetailTransferOwnership;

  /// No description provided for @userDetailMemberDescription.
  ///
  /// In en, this message translates to:
  /// **'Member (Secondary Owner)'**
  String get userDetailMemberDescription;

  /// No description provided for @userDetailFullAccessAssigned.
  ///
  /// In en, this message translates to:
  /// **'Full access to assigned vehicles'**
  String get userDetailFullAccessAssigned;

  /// No description provided for @userDetailLogMaintenanceExpenses.
  ///
  /// In en, this message translates to:
  /// **'Log maintenance & expenses'**
  String get userDetailLogMaintenanceExpenses;

  /// No description provided for @userDetailManageDocumentsPerm.
  ///
  /// In en, this message translates to:
  /// **'Manage documents'**
  String get userDetailManageDocumentsPerm;

  /// No description provided for @userDetailAssignDriversToVehicles.
  ///
  /// In en, this message translates to:
  /// **'Assign drivers to vehicles'**
  String get userDetailAssignDriversToVehicles;

  /// No description provided for @userDetailDriverDescription.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get userDetailDriverDescription;

  /// No description provided for @userDetailViewAssignedVehicles.
  ///
  /// In en, this message translates to:
  /// **'View assigned vehicles'**
  String get userDetailViewAssignedVehicles;

  /// No description provided for @userDetailLogFuelCharge.
  ///
  /// In en, this message translates to:
  /// **'Log fuel/charge'**
  String get userDetailLogFuelCharge;

  /// No description provided for @userDetailViewMaintenanceDue.
  ///
  /// In en, this message translates to:
  /// **'View maintenance due'**
  String get userDetailViewMaintenanceDue;

  /// No description provided for @userDetailViewDocumentsPerm.
  ///
  /// In en, this message translates to:
  /// **'View documents'**
  String get userDetailViewDocumentsPerm;

  /// No description provided for @userDetailPermissionsSection.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get userDetailPermissionsSection;

  /// No description provided for @userDetailMyVehiclesSection.
  ///
  /// In en, this message translates to:
  /// **'My Vehicles'**
  String get userDetailMyVehiclesSection;

  /// No description provided for @userDetailActionsSection.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get userDetailActionsSection;

  /// No description provided for @userDetailLeaveFamilyButton.
  ///
  /// In en, this message translates to:
  /// **'Leave Family'**
  String get userDetailLeaveFamilyButton;

  /// No description provided for @userDetailAdminActionsSection.
  ///
  /// In en, this message translates to:
  /// **'Admin Actions'**
  String get userDetailAdminActionsSection;

  /// No description provided for @userDetailChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change Role'**
  String get userDetailChangeRole;

  /// No description provided for @userDetailAssignVehicles.
  ///
  /// In en, this message translates to:
  /// **'Assign Vehicles'**
  String get userDetailAssignVehicles;

  /// No description provided for @userDetailRemoveFromFamily.
  ///
  /// In en, this message translates to:
  /// **'Remove from Family'**
  String get userDetailRemoveFromFamily;

  /// No description provided for @userDetailChangeRoleSheet.
  ///
  /// In en, this message translates to:
  /// **'Change Role'**
  String get userDetailChangeRoleSheet;

  /// No description provided for @userDetailCurrentRole.
  ///
  /// In en, this message translates to:
  /// **'Current: {role}'**
  String userDetailCurrentRole(Object role);

  /// No description provided for @userDetailNewRole.
  ///
  /// In en, this message translates to:
  /// **'New Role'**
  String get userDetailNewRole;

  /// No description provided for @userDetailSaveRole.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get userDetailSaveRole;

  /// No description provided for @userDetailAssignVehiclesSheet.
  ///
  /// In en, this message translates to:
  /// **'Assign Vehicles'**
  String get userDetailAssignVehiclesSheet;

  /// No description provided for @userDetailNoVehiclesInGarage.
  ///
  /// In en, this message translates to:
  /// **'No vehicles in garage'**
  String get userDetailNoVehiclesInGarage;

  /// No description provided for @familyRolePrimaryOwner.
  ///
  /// In en, this message translates to:
  /// **'Primary Owner'**
  String get familyRolePrimaryOwner;

  /// No description provided for @familyRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get familyRoleMember;

  /// No description provided for @familyRoleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get familyRoleDriver;

  /// No description provided for @drawerQuickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get drawerQuickAccess;

  /// No description provided for @drawerFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get drawerFeatures;

  /// No description provided for @drawerStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get drawerStats;

  /// No description provided for @drawerFamilyFleet.
  ///
  /// In en, this message translates to:
  /// **'Family & Fleet'**
  String get drawerFamilyFleet;

  /// No description provided for @drawerSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get drawerSync;

  /// No description provided for @drawerDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get drawerDocuments;

  /// No description provided for @drawerParts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get drawerParts;

  /// No description provided for @drawerMaintenancePlan.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Plan'**
  String get drawerMaintenancePlan;

  /// No description provided for @drawerInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get drawerInsurance;

  /// No description provided for @drawerRefuelStats.
  ///
  /// In en, this message translates to:
  /// **'Refuel Stats'**
  String get drawerRefuelStats;

  /// No description provided for @drawerMaintenanceStats.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Stats'**
  String get drawerMaintenanceStats;

  /// No description provided for @drawerExpenseStats.
  ///
  /// In en, this message translates to:
  /// **'Expense Stats'**
  String get drawerExpenseStats;

  /// No description provided for @drawerFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get drawerFamily;

  /// No description provided for @drawerFleet.
  ///
  /// In en, this message translates to:
  /// **'Fleet'**
  String get drawerFleet;

  /// No description provided for @refuelStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Refuel Stats'**
  String get refuelStatsTitle;

  /// No description provided for @maintenanceStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Stats'**
  String get maintenanceStatsTitle;

  /// No description provided for @expenseStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense Stats'**
  String get expenseStatsTitle;

  /// No description provided for @fleetTitle.
  ///
  /// In en, this message translates to:
  /// **'Fleet Mode'**
  String get fleetTitle;

  /// No description provided for @syncStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatusTitle;

  /// No description provided for @syncAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get syncAutoSync;

  /// No description provided for @syncAutoSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync data when connected'**
  String get syncAutoSyncDescription;

  /// No description provided for @syncManualSync.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncManualSync;

  /// No description provided for @syncPendingItems.
  ///
  /// In en, this message translates to:
  /// **'Pending Items'**
  String get syncPendingItems;

  /// No description provided for @syncPendingItemsDescription.
  ///
  /// In en, this message translates to:
  /// **'Changes waiting to be synced to the server'**
  String get syncPendingItemsDescription;

  /// No description provided for @syncNoPendingItems.
  ///
  /// In en, this message translates to:
  /// **'All changes synced'**
  String get syncNoPendingItems;

  /// No description provided for @syncStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get syncStatusConnected;

  /// No description provided for @syncStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncStatusOffline;

  /// No description provided for @syncLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get syncLastSynced;

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get syncNever;

  /// No description provided for @syncHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How syncing works'**
  String get syncHowItWorks;

  /// No description provided for @syncHowItWorksDescription.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored locally first, then synced to the server when connected. Offline changes are queued and sent automatically.'**
  String get syncHowItWorksDescription;

  /// No description provided for @syncVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get syncVehicles;

  /// No description provided for @syncMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get syncMaintenance;

  /// No description provided for @syncExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get syncExpenses;

  /// No description provided for @syncDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get syncDocuments;

  /// No description provided for @syncParts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get syncParts;

  /// No description provided for @syncFuelLogs.
  ///
  /// In en, this message translates to:
  /// **'Fuel Logs'**
  String get syncFuelLogs;

  /// No description provided for @syncOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get syncOther;

  /// No description provided for @registerSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Service Logged!'**
  String get registerSuccessTitle;

  /// No description provided for @registerSuccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your maintenance record has been saved successfully.'**
  String get registerSuccessSubtitle;

  /// No description provided for @registerSuccessDetails.
  ///
  /// In en, this message translates to:
  /// **'Logged Details'**
  String get registerSuccessDetails;

  /// No description provided for @registerSuccessBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get registerSuccessBackHome;

  /// No description provided for @registerErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get registerErrorGeneric;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// No description provided for @notesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get notesEmptyTitle;

  /// No description provided for @notesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Capture ideas, checklists, and reminders in one place.'**
  String get notesEmptyBody;

  /// No description provided for @notesNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get notesNewNote;

  /// No description provided for @notesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load notes'**
  String get notesLoadError;

  /// No description provided for @noteFormAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get noteFormAddTitle;

  /// No description provided for @noteFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get noteFormEditTitle;

  /// No description provided for @noteFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get noteFormTitle;

  /// No description provided for @noteFormTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Note title (optional)'**
  String get noteFormTitleHint;

  /// No description provided for @noteFormBody.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteFormBody;

  /// No description provided for @noteFormBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Start writing…'**
  String get noteFormBodyHint;

  /// No description provided for @noteUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get noteUntitled;

  /// No description provided for @noteEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Note cannot be empty'**
  String get noteEmptyError;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

  /// No description provided for @noteUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get noteUndo;

  /// No description provided for @noteDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get noteDelete;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'my'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'my':
      return AppLocalizationsMy();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
