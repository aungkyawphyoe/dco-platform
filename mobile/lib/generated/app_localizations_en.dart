// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DCO';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get remove => 'Remove';

  @override
  String get done => 'Done';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get none => 'None';

  @override
  String get all => 'All';

  @override
  String get optional => 'Optional';

  @override
  String get required => 'Required';

  @override
  String get active => 'active';

  @override
  String get inactive => 'inactive';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get retryAction => 'Retry';

  @override
  String get syncDefaultError => 'Your changes will retry automatically.';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get somethingWentWrongTryAgain => 'Something went wrong. Try again.';

  @override
  String get navGarage => 'Garage';

  @override
  String get navMaintenance => 'Maintenance';

  @override
  String get navExpenses => 'Expenses';

  @override
  String get navSettings => 'Setting';

  @override
  String get welcomeTagline => 'Your garage, on the phone.';

  @override
  String get welcomeBody =>
      'Track maintenance, documents, and spend for every vehicle you own — even offline.';

  @override
  String get createAccount => 'Create account';

  @override
  String get signIn => 'Sign in';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot password';

  @override
  String get createAnAccount => 'Create an account';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get signUpFailed => 'Sign up failed';

  @override
  String get signInFailed => 'Sign in failed';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get resetPasswordBody =>
      'Enter your email. We send a reset link if the account exists.';

  @override
  String get resetLinkSent =>
      'If that email is registered, we sent a reset link.';

  @override
  String get resetFailed => 'Reset failed';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get authIncorrectCredentials => 'Email or password is incorrect';

  @override
  String get authEmailAlreadyRegistered => 'That email is already registered';

  @override
  String get authNetworkError => 'Check your connection and try again';

  @override
  String get authTooManyAttempts => 'Too many attempts. Try again shortly';

  @override
  String get authSessionExpired => 'Session expired. Sign in again';

  @override
  String get authUnknownError => 'Something went wrong';

  @override
  String get dashboardNoVehicle => 'No vehicle';

  @override
  String get dashboardGarageTooltip => 'Garage';

  @override
  String get dashboardNotificationsTooltip => 'Notifications';

  @override
  String get dashboardVerifyEmail => 'Verify your email';

  @override
  String get dashboardResend => 'Resend';

  @override
  String get dashboardLoadError => 'Could not load dashboard';

  @override
  String get dashboardEmptyTitle => 'Register a vehicle';

  @override
  String get dashboardEmptyBody =>
      'Add your first car to see spend, upcoming service, and history here.';

  @override
  String get dashboardOwnershipSummary => 'Ownership Summary';

  @override
  String get dashboardTotalSpent => 'Total spent';

  @override
  String get dashboardThisMonth => 'This month';

  @override
  String get dashboardQuickActions => 'Quick Actions';

  @override
  String get dashboardHistory => 'History';

  @override
  String get dashboardCharge => 'Charge';

  @override
  String get dashboardRefuel => 'Refuel';

  @override
  String get dashboardInsurance => 'Insurance';

  @override
  String get dashboardNotes => 'Notes';

  @override
  String get dashboardRecentActivity => 'Recent Activity';

  @override
  String get dashboardNoServicesYet => 'No services yet';

  @override
  String get dashboardNextMaintenance => 'Next Maintenance';

  @override
  String get dashboardNoPlanItemsYet => 'No plan items yet';

  @override
  String get dashboardAddPlanItem => 'Add a plan item';

  @override
  String get dashboardLogService => 'Log Service';

  @override
  String get overdue => 'Overdue';

  @override
  String overdueBy(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# days',
      one: '# day',
    );
    return 'Overdue by $_temp0';
  }

  @override
  String dueIn(Object distance) {
    return 'Due in $distance';
  }

  @override
  String get dueSoon => 'Due soon';

  @override
  String due(Object distance) {
    return 'Due $distance';
  }

  @override
  String get garageMyGarage => 'My Garage';

  @override
  String get garageRegisterTooltip => 'Register a vehicle';

  @override
  String get garageLoadError => 'Could not load garage';

  @override
  String get garageEmptyTitle => 'No vehicles yet';

  @override
  String get garageEmptyBody =>
      'Register a vehicle to start tracking maintenance, documents, and spend.';

  @override
  String get garageSwitchFailed => 'Switch failed';

  @override
  String get garageSwitchFailedBody =>
      'Could not reach the server. Your change stays on this device and syncs later.';

  @override
  String get garageAddCardTitle => '+ Register Another Vehicle';

  @override
  String get garageAddCardSubtitle => 'Track maintenance, expenses & documents';

  @override
  String get garageFamilyBadge => 'Family';

  @override
  String get vehicleEditTitle => 'Edit Vehicle';

  @override
  String get vehicleRegisterTitle => 'Register Vehicle';

  @override
  String get vehicleRequiredInfo => 'Required Information';

  @override
  String get vehicleNameLabel => 'Name *';

  @override
  String get vehicleYearLabel => 'Year *';

  @override
  String get vehicleMakeLabel => 'Make *';

  @override
  String get vehicleModelLabel => 'Model *';

  @override
  String get vehiclePlateLabel => 'License Plate *';

  @override
  String get vehicleMileageLabel => 'Mileage *';

  @override
  String get vehicleFuelTypeLabel => 'Fuel Type *';

  @override
  String get vehicleFuelTypeRequired => 'Fuel type is required';

  @override
  String get vehicleOptionalDetails => 'Optional Details';

  @override
  String get vehicleVinLabel => 'VIN';

  @override
  String get vehicleColorLabel => 'Color';

  @override
  String get vehicleNicknameLabel => 'Nickname';

  @override
  String get vehiclePurchaseDateLabel => 'Purchase Date';

  @override
  String get vehicleArchiveButton => 'Archive vehicle';

  @override
  String get vehicleArchiveTitle => 'Archive this vehicle?';

  @override
  String get vehicleArchiveBody =>
      'Records stay attached and hidden. This does not permanently delete them.';

  @override
  String get vehicleArchiveAction => 'Archive';

  @override
  String get vehicleAddPhoto => 'Add photo';

  @override
  String get vehicleSetActive => 'Set active';

  @override
  String get vehicleEditTooltip => 'Edit vehicle';

  @override
  String get vehicleRemoveTooltip => 'Remove from family';

  @override
  String get vehiclePlateDuplicate =>
      'That license plate is already in your garage';

  @override
  String get vehicleVinDuplicate => 'That VIN already belongs to a vehicle';

  @override
  String get vehicleMileageDecrease => 'Mileage cannot decrease';

  @override
  String get vehicleNotFound => 'Vehicle not found';

  @override
  String get vehicleNameRequired => 'Name is required';

  @override
  String get vehicleMakeRequired => 'Make is required';

  @override
  String get vehicleModelRequired => 'Model is required';

  @override
  String get vehicleYearRequired => 'Year is required';

  @override
  String get vehicleYearInvalid => 'Enter a valid year';

  @override
  String vehicleYearRange(Object max) {
    return 'Year must be between 1900 and $max';
  }

  @override
  String get vehiclePlateRequired => 'License plate is required';

  @override
  String get vehiclePlateMaxLength =>
      'License plate must be 20 characters or fewer';

  @override
  String get vehicleMileageRequired => 'Mileage is required';

  @override
  String get vehicleMileageInvalid => 'Enter a valid mileage';

  @override
  String get vehicleMileageNegative => 'Mileage cannot be negative';

  @override
  String get vehicleVinLength => 'VIN must be 17 characters';

  @override
  String get fuelPetrol => 'Petrol';

  @override
  String get fuelElectric => 'Electric';

  @override
  String get fuelHybridPlugin => 'Hybrid plugin';

  @override
  String get maintenanceTitle => 'Maintenance';

  @override
  String get maintenanceHistoryTooltip => 'History';

  @override
  String get maintenanceLoadError => 'Could not load maintenance';

  @override
  String get maintenanceNoActiveVehicle => 'No active vehicle';

  @override
  String get maintenanceNoActiveVehicleBody =>
      'Register a vehicle to plan service and keep history.';

  @override
  String get maintenanceUpcomingReminders => 'Upcoming Reminders';

  @override
  String get maintenanceNothingDue => 'Nothing due';

  @override
  String get maintenanceScheduled => 'Scheduled';

  @override
  String get maintenanceNothingScheduled => 'Nothing scheduled';

  @override
  String get maintenanceServiceHistory => 'Service History';

  @override
  String get maintenanceNoServicesLogged => 'No services logged';

  @override
  String get maintenanceRegisterService => 'Register service';

  @override
  String get maintenanceLoadFromReceipt => 'Load from Receipt';

  @override
  String get maintenancePlanTitle => 'Maintenance Plan';

  @override
  String get maintenancePlanNoActiveVehicleBody =>
      'Register a vehicle to build a maintenance plan.';

  @override
  String get maintenancePlanLoadError => 'Could not load plan';

  @override
  String get maintenancePlanEmptyTitle => 'No plan items yet';

  @override
  String get maintenancePlanEmptyBody =>
      'Add a custom item or pick from suggested services.';

  @override
  String get maintenancePlanAddItem => 'Add Maintenance Item';

  @override
  String get maintenancePlanAddSuggested => 'Add Suggested Items';

  @override
  String get serviceHistoryTitle => 'Service History';

  @override
  String get serviceHistoryNoActiveVehicleBody =>
      'Register a vehicle to see services logged against it.';

  @override
  String get serviceHistoryLoadError => 'Could not load services';

  @override
  String get serviceHistoryEmptyTitle => 'No services yet';

  @override
  String get serviceHistoryEmptyBody =>
      'Logged services for this vehicle will show up here.';

  @override
  String get serviceDetailTitle => 'Service';

  @override
  String get serviceDetailNotFound => 'Service not found';

  @override
  String get serviceDetailNotFoundBody => 'This record is no longer available.';

  @override
  String get serviceDetailMileage => 'Mileage';

  @override
  String get serviceDetailTotal => 'Total';

  @override
  String get serviceDetailWorkshop => 'Workshop';

  @override
  String get serviceDetailNotes => 'Notes';

  @override
  String get serviceDetailServices => 'Services';

  @override
  String get serviceDetailParts => 'Parts';

  @override
  String get registerServiceTitle => 'Register Service';

  @override
  String get registerServiceNoActiveVehicleBody =>
      'Register a vehicle before logging a service.';

  @override
  String get registerServiceJobTitle => 'Job Title';

  @override
  String get registerServiceDate => 'Date *';

  @override
  String get registerServiceMileage => 'Mileage *';

  @override
  String get registerServiceNotes => 'Notes';

  @override
  String get registerServiceSection => 'Service';

  @override
  String get registerServiceCostHint => 'cost';

  @override
  String get registerServiceAddService => 'add service';

  @override
  String get registerServicePartsSection => 'Parts';

  @override
  String get registerServiceAssignPart => 'assign part';

  @override
  String get registerServiceTotal => 'Total';

  @override
  String get registerServiceAddServiceTitle => 'Add service';

  @override
  String get registerServiceAddServiceEmpty =>
      'No due or scheduled items left. Add a custom service below.';

  @override
  String get registerServiceCustomService => 'Custom service';

  @override
  String get registerServiceCustomHint => 'e.g. Alignment';

  @override
  String get registerServiceAddCustom => 'Add custom';

  @override
  String get registerServiceAssignPartTitle => 'Assign part';

  @override
  String get registerServiceAssignPartEmpty =>
      'No parts in the catalog yet. Add one, then assign it here.';

  @override
  String get registerServiceAssignPartAllAssigned =>
      'Every part is already assigned to this service.';

  @override
  String get registerServiceAddNewPart => 'Add a new part';

  @override
  String get planItemFormEditTitle => 'Edit Service Item';

  @override
  String get planItemFormCreateTitle => 'Create Service Item';

  @override
  String get planItemFormName => 'Name *';

  @override
  String get planItemFormSchedule => 'Schedule *';

  @override
  String get planItemFormActive => 'active';

  @override
  String get planItemFormRecurring => 'recurring';

  @override
  String get planItemFormRepeatEvery => 'Repeat every';

  @override
  String get planItemFormUnit => 'Unit';

  @override
  String get planItemFormEveryMileage => 'Every (mileage)';

  @override
  String get planItemFormOverrideStart => 'Override Tracking Start';

  @override
  String get planItemFormOverrideHelper =>
      'The highest value out of this or your most recent service will prevail.';

  @override
  String get planItemFormDate => 'Date';

  @override
  String get planItemFormDateRequired => 'Date *';

  @override
  String get planItemFormMileage => 'Mileage';

  @override
  String get planItemFormMileageRequired => 'Mileage *';

  @override
  String get planItemFormNotes => 'Notes';

  @override
  String get suggestedItemsTitle => 'Maintenance Items';

  @override
  String get suggestedItemsNoActiveVehicleBody =>
      'Register a vehicle to add suggested items.';

  @override
  String get suggestedItemsAllAdded => 'All suggested items added';

  @override
  String get suggestedItemsAllAddedBody =>
      'You can still create a custom service item from the plan.';

  @override
  String suggestedItemAdd(Object itemName) {
    return 'Add $itemName';
  }

  @override
  String get planItemTileOverdue => 'Overdue';

  @override
  String planItemTileOverdueBy(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# days',
      one: '# day',
    );
    return 'Overdue by $_temp0';
  }

  @override
  String get planItemTileNextMileage => 'Next Mileage: ';

  @override
  String get planItemTileNextDate => 'Next Date: ';

  @override
  String get planItemTileNoDueDate => 'No due date set';

  @override
  String get planItemTileRemaining => 'Remaining: ';

  @override
  String get planItemTileTimeLeft => 'Time left: ';

  @override
  String get planItemTileDay => 'day';

  @override
  String get planItemTileDays => 'days';

  @override
  String get maintenanceMileageDecrease => 'Mileage cannot decrease';

  @override
  String get maintenanceVehicleNotFound => 'Vehicle not found';

  @override
  String get maintenancePlanItemNotFound => 'Plan item not found';

  @override
  String get maintenanceServiceRecordNotFound => 'Service record not found';

  @override
  String get planItemNameRequired => 'Name is required';

  @override
  String planItemNameMaxLength(Object max) {
    return 'Name must be $max characters or fewer';
  }

  @override
  String get planItemScheduleRequired =>
      'Set a time interval, a mileage interval, or both';

  @override
  String get planItemDueRequired => 'Set a due date, a due mileage, or both';

  @override
  String get planItemMileageRequired => 'Mileage is required';

  @override
  String get planItemMileageInvalid => 'Enter a valid mileage';

  @override
  String get planItemWholeNumber => 'Enter a whole number greater than 0';

  @override
  String get planItemDateRequired => 'Date is required';

  @override
  String get planItemAtLeastOneService => 'Add at least one service';

  @override
  String get planItemTotalRequired => 'Total is required';

  @override
  String get planItemAmountInvalid => 'Enter a valid amount';

  @override
  String get catalogMileageUpdate => 'Mileage Update';

  @override
  String get catalogRoutine => 'Routine';

  @override
  String get catalogOilChange => 'Oil Change';

  @override
  String get catalogAirFilterCabin => 'Air Filter (Cabin)';

  @override
  String get catalogNewTires => 'New Tires';

  @override
  String get catalogBrakeChange => 'Brake Change';

  @override
  String get catalogBrakeFluid => 'Brake Fluid';

  @override
  String get catalogBelts => 'Belts';

  @override
  String get catalogFuelFilter => 'Fuel Filter';

  @override
  String get catalogWash => 'Wash';

  @override
  String get catalogBattery => 'Battery';

  @override
  String get catalogAirConditioning => 'Air Conditioning';

  @override
  String get catalogRotateTires => 'Rotate Tires';

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get expensesAddTooltip => 'Add expense';

  @override
  String get expensesNoActiveVehicle => 'No active vehicle';

  @override
  String get expensesNoActiveVehicleBody =>
      'Register a vehicle to log spend. Fuel here is money only — not a fuel log.';

  @override
  String get expensesLoadError => 'Could not load expenses';

  @override
  String get expensesEmptyTitle => 'No expenses yet';

  @override
  String expensesEmptyBody(Object vehicleName) {
    return 'Log spend for $vehicleName. Fuel is money only — not a fuel log.';
  }

  @override
  String get expensesAddExpense => 'Add expense';

  @override
  String get expensesNoMatching => 'No matching expenses';

  @override
  String get expensesNoMatchingBody => 'Try a different category.';

  @override
  String get expensesThisMonth => 'This month';

  @override
  String get expensesTotal => 'Total';

  @override
  String get expensesAllFilter => 'All';

  @override
  String get expenseFormEditTitle => 'Edit expense';

  @override
  String get expenseFormAddTitle => 'Add expense';

  @override
  String get expenseFormNoActiveVehicleBody =>
      'Register a vehicle to log spend.';

  @override
  String get expenseFormNotFound => 'Expense not found';

  @override
  String get expenseFormNotFoundBody => 'It may have been deleted.';

  @override
  String get expenseFormCategory => 'Category *';

  @override
  String get expenseFormCategoryHint => 'Choose a category';

  @override
  String get expenseFormCategorySheetTitle => 'Category';

  @override
  String get expenseFormAmount => 'Amount *';

  @override
  String get expenseFormDate => 'Date *';

  @override
  String get expenseFormNotes => 'Notes';

  @override
  String get expenseFormNotesHint => 'Optional';

  @override
  String get expenseFormReceiptSection => 'Receipt';

  @override
  String get expenseFormAddReceipt => 'Add receipt photo';

  @override
  String get expenseFormReplace => 'Replace';

  @override
  String get expenseFormPartsSection => 'Parts';

  @override
  String get expenseFormAssignPart => 'assign part';

  @override
  String get expenseFormAssignPartTitle => 'Assign part';

  @override
  String get expenseFormAssignPartEmpty =>
      'No parts in the catalog yet. Add one, then assign it here.';

  @override
  String get expenseFormAssignPartAllAssigned =>
      'Every part is already assigned to this expense.';

  @override
  String get expenseFormAddNewPart => 'Add a new part';

  @override
  String get expenseFormDeleteButton => 'Delete expense';

  @override
  String get expenseFormDeleteTitle => 'Delete this expense?';

  @override
  String get expenseFormDeleteBody =>
      'This removes the entry and its receipt photo. This cannot be undone.';

  @override
  String get expenseFormCameraDenied =>
      'Camera or photo access was denied. You can save without a photo.';

  @override
  String get expenseFormCameraOption => 'Camera';

  @override
  String get expenseFormPhotoLibraryOption => 'Photo library';

  @override
  String get expenseNotFound => 'Expense not found';

  @override
  String get expenseCategoryFuel => 'Fuel';

  @override
  String get expenseCategoryMaintenance => 'Maintenance';

  @override
  String get expenseCategoryInsurance => 'Insurance';

  @override
  String get expenseCategoryParking => 'Parking';

  @override
  String get expenseCategoryTolls => 'Tolls';

  @override
  String get expenseCategoryParts => 'Parts';

  @override
  String get expenseCategoryOther => 'Other';

  @override
  String get expenseCategoryRequired => 'Category is required';

  @override
  String get expenseAmountRequired => 'Amount is required';

  @override
  String get expenseAmountTooSmall => 'Enter an amount greater than 0';

  @override
  String get expenseAmountTooLarge => 'Amount must be 999,999.99 or less';

  @override
  String get expenseDateRequired => 'Date is required';

  @override
  String get expenseDateTooFarFuture =>
      'Date cannot be more than one day in the future';

  @override
  String expenseNotesMaxLength(Object max) {
    return 'Notes must be $max characters or fewer';
  }

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsNoActiveVehicle => 'No active vehicle';

  @override
  String get documentsEmptyTitle => 'No documents yet';

  @override
  String get documentsEmptyBodyNoVehicle =>
      'Register a vehicle to store insurance, registration, and receipts.';

  @override
  String documentsEmptyBody(Object vehicleName) {
    return 'Upload insurance, registration, and receipts for $vehicleName.';
  }

  @override
  String get documentsAddTooltip => 'Add document';

  @override
  String get documentsNoActiveVehicleBody =>
      'Register a vehicle to store documents.';

  @override
  String get documentsLoadError => 'Could not load documents';

  @override
  String get documentsAddDocument => 'Add document';

  @override
  String get documentCategoryInsurance => 'Insurance';

  @override
  String get documentCategoryRegistration => 'Registration';

  @override
  String get documentCategoryInvoice => 'Invoice';

  @override
  String get documentCategoryWarranty => 'Warranty';

  @override
  String get documentCategoryReceipt => 'Receipt';

  @override
  String get documentCategoryOther => 'Other';

  @override
  String get documentFormEditTitle => 'Edit Document';

  @override
  String get documentFormAddTitle => 'Add Document';

  @override
  String get documentFormName => 'Name *';

  @override
  String get documentFormNameHint => 'e.g., Insurance Policy 2025';

  @override
  String get documentFormCategory => 'Category *';

  @override
  String get documentFormCategoryHint => 'Choose a category';

  @override
  String get documentFormCategorySheetTitle => 'Category';

  @override
  String get documentFormNotes => 'Notes';

  @override
  String get documentFormNotesHint => 'Optional';

  @override
  String get documentFormFileSection => 'File';

  @override
  String get documentFormAddFile => 'Add file';

  @override
  String get documentFormReplaceFile => 'Replace';

  @override
  String get documentFormDeleteButton => 'Delete document';

  @override
  String get documentFormDeleteTitle => 'Delete this document?';

  @override
  String get documentFormDeleteBody =>
      'This removes the document and its file. This cannot be undone.';

  @override
  String get documentFormFileRequired => 'Please attach a file';

  @override
  String get documentFormCameraDenied =>
      'Camera or photo access was denied. You can save without a file.';

  @override
  String get documentFormCameraOption => 'Camera';

  @override
  String get documentFormGalleryOption => 'Photo library';

  @override
  String get documentFormPdfOption => 'PDF';

  @override
  String get documentFormPickError => 'Could not pick file. Try again.';

  @override
  String get documentFormNoActiveVehicleBody =>
      'Register a vehicle to store documents.';

  @override
  String get documentFormNotFound => 'Document not found';

  @override
  String get documentFormNotFoundBody => 'It may have been deleted.';

  @override
  String get documentFormAttachFile => 'Attach file';

  @override
  String get documentFormReplace => 'Replace';

  @override
  String get documentViewerTitle => 'Document';

  @override
  String get documentViewerNotFound => 'Document not found';

  @override
  String get documentViewerNotFoundBody => 'This document could not be loaded.';

  @override
  String get documentViewerEdit => 'Edit';

  @override
  String get documentViewerNoFile => 'No file';

  @override
  String get documentViewerNoFileBody => 'This document has no file attached.';

  @override
  String get documentViewerRemote => 'Cloud document';

  @override
  String get documentViewerRemoteBody =>
      'This file is stored in the cloud and will sync when online.';

  @override
  String get documentInfoCategory => 'Category';

  @override
  String get documentInfoAdded => 'Added';

  @override
  String get documentInfoNotes => 'Notes';

  @override
  String get documentInfoStatus => 'Status';

  @override
  String get documentStatusSynced => 'Synced';

  @override
  String get documentStatusQueued => 'Queued';

  @override
  String get documentNotFound => 'Document not found';

  @override
  String get partsTitle => 'Parts';

  @override
  String get partsAddTooltip => 'Add a part';

  @override
  String get partsNoActiveVehicle => 'No active vehicle';

  @override
  String get partsNoActiveVehicleBody =>
      'Register a vehicle to keep a parts catalog for it.';

  @override
  String get partsLoadError => 'Could not load parts';

  @override
  String get partsEmptyTitle => 'No parts yet';

  @override
  String partsEmptyBody(Object vehicleName) {
    return 'Add parts for $vehicleName. Assign them when you log a service or an expense.';
  }

  @override
  String get partsAddPart => 'Add a part';

  @override
  String get partFormEditTitle => 'Edit Part';

  @override
  String get partFormAddTitle => 'Add Part';

  @override
  String get partFormName => 'Name *';

  @override
  String get partFormNameHint => 'Oil filter';

  @override
  String get partFormBrand => 'Brand';

  @override
  String get partFormBrandHint => 'Bosch';

  @override
  String get partFormPartNumber => 'Part number';

  @override
  String get partFormPartNumberHint => 'OF-1234';

  @override
  String get partFormNotes => 'Notes';

  @override
  String get partFormNotesHint => 'Size, source, or fitment';

  @override
  String get partDuplicate => 'That part is already in this vehicle';

  @override
  String get partNotFound => 'Part not found';

  @override
  String get partNameRequired => 'Name is required';

  @override
  String partNameMaxLength(Object max) {
    return 'Name must be $max characters or fewer';
  }

  @override
  String partBrandMaxLength(Object max) {
    return 'Brand must be $max characters or fewer';
  }

  @override
  String partNumberMaxLength(Object max) {
    return 'Part number must be $max characters or fewer';
  }

  @override
  String partNotesMaxLength(Object max) {
    return 'Notes must be $max characters or fewer';
  }

  @override
  String get fuelLogsTitle => 'Refuel';

  @override
  String get fuelLogsTypesTooltip => 'Fuel Types';

  @override
  String get fuelLogsAddChargeTooltip => 'Add a charge';

  @override
  String get fuelLogsAddRefuelTooltip => 'Add a refill';

  @override
  String get fuelLogsNoActiveVehicle => 'No active vehicle';

  @override
  String get fuelLogsNoActiveVehicleBody =>
      'Register a vehicle to log fuel or charging.';

  @override
  String fuelLogsLoadError(Object title) {
    return 'Could not load $title';
  }

  @override
  String get fuelLogsEmptyTitleCharges => 'No charges yet';

  @override
  String get fuelLogsEmptyTitleRefuels => 'No refuels yet';

  @override
  String fuelLogsEmptyBodyCharges(Object vehicleName) {
    return 'Log charging for $vehicleName.';
  }

  @override
  String fuelLogsEmptyBodyRefuels(Object vehicleName) {
    return 'Log a refill for $vehicleName.';
  }

  @override
  String get fuelLogsNoMatching => 'No matching logs';

  @override
  String get fuelLogsNoMatchingBody =>
      'Try a different fuel type or date filter.';

  @override
  String get fuelLogsAllTypes => 'All types';

  @override
  String get fuelLogsAllDates => 'All dates';

  @override
  String get fuelLogsThisMonth => 'This month';

  @override
  String get fuelLogFormTypeSheetTitle => 'Fuel Type';

  @override
  String get fuelLogFormAddFuelType => 'Add fuel type';

  @override
  String get fuelLogFormTypesLink => 'Fuel Types';

  @override
  String get fuelLogFormDate => 'Date *';

  @override
  String get fuelLogFormFuelType => 'Fuel Type *';

  @override
  String get fuelLogFormFuelTypeHint => 'Add a fuel type';

  @override
  String get fuelLogFormSelect => 'Select';

  @override
  String get fuelLogFormAmount => 'Amount *';

  @override
  String get fuelLogFormCost => 'Cost *';

  @override
  String get fuelTypesTitle => 'Fuel Types';

  @override
  String get fuelTypesAddTooltip => 'Add a fuel type';

  @override
  String get fuelTypesNoActiveVehicle => 'No active vehicle';

  @override
  String get fuelTypesNoActiveVehicleBody =>
      'Register a vehicle to keep a fuel type catalog.';

  @override
  String get fuelTypesLoadError => 'Could not load fuel types';

  @override
  String get fuelTypesEmptyTitle => 'No fuel types yet';

  @override
  String get fuelTypesEmptyBody =>
      'Add petrol, diesel, electricity, or your own names.';

  @override
  String get fuelTypesAddFuelType => 'Add fuel type';

  @override
  String get fuelTypesNoMatching => 'No matching types';

  @override
  String get fuelTypesNoMatchingBody => 'Try a different filter or add a type.';

  @override
  String get fuelTypesAll => 'All';

  @override
  String get fuelTypesLiquid => 'Liquid';

  @override
  String get fuelTypesElectric => 'Electric';

  @override
  String get fuelTypeFormEditTitle => 'Edit Fuel Type';

  @override
  String get fuelTypeFormAddTitle => 'Add Fuel Type';

  @override
  String get fuelTypeFormName => 'Name *';

  @override
  String get fuelTypeFormNameHintElectric => 'Electricity';

  @override
  String get fuelTypeFormNameHintPetrol => 'Petrol';

  @override
  String get fuelTypeFormKind => 'Kind *';

  @override
  String get fuelTypeFormUnit => 'Unit *';

  @override
  String get fuelTypeDuplicate => 'That fuel type is already in your catalog';

  @override
  String get fuelTypeNotFound => 'Fuel type not found';

  @override
  String get fuelLogNotFound => 'Log not found';

  @override
  String get fuelTypeMismatch => 'That fuel type does not match this vehicle';

  @override
  String get fuelNameRequired => 'Name is required';

  @override
  String fuelNameMaxLength(Object max) {
    return 'Name must be $max characters or fewer';
  }

  @override
  String get fuelUnitInvalid => 'Choose a valid unit';

  @override
  String get fuelDateRequired => 'Date is required';

  @override
  String get fuelDateTooFuture => 'Date cannot be in the future';

  @override
  String get fuelTypeRequired => 'Fuel type is required';

  @override
  String get fuelAmountRequired => 'Amount is required';

  @override
  String get fuelAmountTooSmall => 'Enter an amount greater than 0';

  @override
  String get fuelAmountTooLarge => 'Amount is too large';

  @override
  String get fuelCostRequired => 'Cost is required';

  @override
  String get fuelCostInvalid => 'Enter a valid cost';

  @override
  String get fuelCostTooLarge => 'Cost is too large';

  @override
  String get fuelKindLiquid => 'Liquid';

  @override
  String get fuelKindElectric => 'Electric';

  @override
  String get fuelLogRefuel => 'Refuel';

  @override
  String get fuelLogCharge => 'Charge';

  @override
  String get fuelLogAddRefuel => 'Add Refuel';

  @override
  String get fuelLogAddCharge => 'Add Charge';

  @override
  String get fuelLogEditRefuel => 'Edit Refuel';

  @override
  String get fuelLogEditCharge => 'Edit Charge';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsFreePlan => 'Free Plan';

  @override
  String get settingsManageVehicles => 'Manage vehicles';

  @override
  String get settingsDocuments => 'Documents';

  @override
  String get settingsLocalization => 'Localization';

  @override
  String get settingsUnitFormat => 'Unit and Format';

  @override
  String get settingsSyncSection => 'Sync';

  @override
  String get settingsFamilySection => 'Family';

  @override
  String get settingsLoadingFamily => 'Loading family...';

  @override
  String get settingsFamilyLoadError => 'Failed to load family';

  @override
  String get settingsFamilyTapRetry => 'Tap to retry';

  @override
  String get settingsFamilyFallback => 'Family';

  @override
  String get settingsFamilySubtitle =>
      'Create or join a family to share vehicles';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSyncNow => 'Sync now';

  @override
  String get settingsSyncStatusFailed => 'Sync failed';

  @override
  String get settingsSyncStatusSyncing => 'Syncing...';

  @override
  String get settingsSyncStatusJustSynced => 'Just synced';

  @override
  String settingsSyncStatusMinutesAgo(Object minutes) {
    return 'Synced ${minutes}m ago';
  }

  @override
  String settingsSyncStatusHoursAgo(Object hours) {
    return 'Synced ${hours}h ago';
  }

  @override
  String settingsSyncStatusDaysAgo(Object days) {
    return 'Synced ${days}d ago';
  }

  @override
  String get settingsSyncTapToSync => 'Tap to sync your data';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profilePhoto => 'Profile Photo';

  @override
  String get profilePhotoTapToChange => 'Tap to change photo';

  @override
  String get profileName => 'Name';

  @override
  String get profileNameHint => 'Enter your name';

  @override
  String get profileContactPhone => 'Contact Number';

  @override
  String get profileContactPhoneHint => 'Phone number (optional)';

  @override
  String get profileAddress => 'Address';

  @override
  String get profileAddressHint => 'Address (optional)';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileEmailVerified => 'Verified';

  @override
  String get profileEmailNotVerified => 'Not verified';

  @override
  String get profileMemberSince => 'Member since';

  @override
  String get profileSave => 'Save Profile';

  @override
  String get profileSaved => 'Profile updated';

  @override
  String get profileCompleteBanner => 'Complete your profile';

  @override
  String get profileCompleteBannerAction => 'Set up';

  @override
  String get profileDeleteAccount => 'Delete Account';

  @override
  String get profileDeleteAccountTitle => 'Delete Account?';

  @override
  String get profileDeleteAccountBody =>
      'This will deactivate your account and archive all your vehicles. You will not be able to sign in again.';

  @override
  String get profileDeleteAccountPassword => 'Enter your password to confirm';

  @override
  String get profileDeleteAccountBlocked =>
      'You are the Primary Owner of a family. Transfer ownership or dissolve your family before deleting your account.';

  @override
  String get profileDeleteAccountSuccess => 'Your account has been deleted.';

  @override
  String get localizationTitle => 'Localization';

  @override
  String get localizationLanguage => 'Language';

  @override
  String get localizationHelper =>
      'App copy stays in English for now. This stores your choice.';

  @override
  String get unitsFormatsTitle => 'Unit and Format';

  @override
  String get unitsFormatsCurrency => 'Currency';

  @override
  String get unitsFormatsCurrencyHelper =>
      'USD shows cents. MMK shows whole kyat, and large amounts use K or M (25K, 23M).';

  @override
  String get unitsFormatsLengthUnit => 'Unit of length';

  @override
  String get unitsFormatsLengthUnitHelper =>
      'Odometer, service intervals, and due mileage follow this unit.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMyanmar => 'Myanmar';

  @override
  String get currencyUSD => 'US Dollar (USD)';

  @override
  String get currencyMMK => 'Myanmar Kyat (MMK)';

  @override
  String get unitMilesShort => 'mi';

  @override
  String get unitKilometersShort => 'km';

  @override
  String get unitMilesFull => 'Miles';

  @override
  String get unitKilometersFull => 'Kilometers';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsLoadError => 'Could not load notifications';

  @override
  String get notificationsEmptyTitle => 'No notifications';

  @override
  String get notificationsEmptyBody => 'Due reminders will show up here.';

  @override
  String get notificationsMarkDone => 'Mark done';

  @override
  String get notificationsDismiss => 'Dismiss';

  @override
  String get notificationsRestore => 'Restore';

  @override
  String get insuranceTitle => 'Insurance';

  @override
  String get insuranceNoActiveVehicle => 'No active vehicle';

  @override
  String get insuranceComingLater => 'Insurance coming later';

  @override
  String get insuranceNoActiveVehicleBody =>
      'Register a vehicle to keep policies against it.';

  @override
  String insuranceEmptyBody(Object vehicleName) {
    return 'Policies for $vehicleName will live here. For now, store insurance papers in Documents.';
  }

  @override
  String get familyJoinTitle => 'Join Family';

  @override
  String get familyCreateTitle => 'Create Family';

  @override
  String get familyJoining => 'Joining family...';

  @override
  String get familyCreateHeading => 'Create Your Family';

  @override
  String get familyCreateBody =>
      'Invite members to share vehicles and manage access together.';

  @override
  String get familyNameLabel => 'Family Name';

  @override
  String get familyNameHint => 'e.g., Smith Family';

  @override
  String get familyNameRequired => 'Family name is required';

  @override
  String get familyNameMaxLength => 'Name must be 100 characters or fewer';

  @override
  String get familyCreating => 'Creating...';

  @override
  String get familyCreateButton => 'Create Family';

  @override
  String get familyCreatedSuccess =>
      'Family created! Share the code with family members.';

  @override
  String familyCreateFailed(Object error) {
    return 'Failed to create family: $error';
  }

  @override
  String get familyJoinedSuccess => 'Joined family successfully!';

  @override
  String familyJoinFailed(Object error) {
    return 'Failed to join family: $error';
  }

  @override
  String get familyCreatedHeading => 'Family Created!';

  @override
  String get familyCreatedBody =>
      'Share this code with family members so they can join.';

  @override
  String get familyShareCode => 'Share Code';

  @override
  String get familyShareCodeHelper => 'Scan with DCO app to join';

  @override
  String get familyCopyCode => 'Copy Code';

  @override
  String get familyCodeCopied => 'Code copied!';

  @override
  String get familyShare => 'Share';

  @override
  String familyShareText(Object code) {
    return 'Join my DCO family! Code: $code';
  }

  @override
  String get familyCodeExpiryHelper =>
      'Code expires in 7 days. Regenerating invalidates the old code.';

  @override
  String get familyGoToManagement => 'Go to Family Management';

  @override
  String get familyManagementTitle => 'Family';

  @override
  String get familyManagementMembersTab => 'Members';

  @override
  String get familyManagementVehiclesTab => 'Vehicles';

  @override
  String get familyManagementInviteTab => 'Invite';

  @override
  String get familyManagementJoinTitle => 'Join Family';

  @override
  String get familyManagementJoinHint => 'Enter share code';

  @override
  String get familyManagementJoinLabel => 'Share Code';

  @override
  String get familyManagementJoinButton => 'Join';

  @override
  String get familyManagementNoFamily => 'No family yet';

  @override
  String get familyManagementNoFamilyBody =>
      'Create a family to share vehicles,\nor join an existing one.';

  @override
  String get familyManagementCreateButton => 'Create Family';

  @override
  String get familyManagementJoinFamilyButton => 'Join Family';

  @override
  String get membersTabEmptyTitle => 'No members yet';

  @override
  String get membersTabEmptyBody => 'Invite family to get started.';

  @override
  String membersTabManageTitle(Object name) {
    return 'Manage $name';
  }

  @override
  String get membersTabRoleSection => 'Role';

  @override
  String get membersTabRoleMember => 'Member';

  @override
  String get membersTabRoleDriver => 'Driver';

  @override
  String get membersTabSaveRole => 'Save Role';

  @override
  String get membersTabRemoveButton => 'Remove from Family';

  @override
  String get membersTabRemoveTitle => 'Remove Member?';

  @override
  String membersTabRemoveBody(Object name) {
    return 'Remove $name from the family?';
  }

  @override
  String get membersTabRemoveAction => 'Remove';

  @override
  String get membersTabYouBadge => 'You';

  @override
  String get membersTabPrimaryOwner => 'Primary Owner';

  @override
  String get membersTabLicenseValid => 'Valid';

  @override
  String get membersTabLicenseExpiringSoon => 'Expiring Soon';

  @override
  String get membersTabLicenseExpired => 'Expired';

  @override
  String get membersTabLicenseNone => 'No License';

  @override
  String membersTabVehicleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# vehicles',
      one: '# vehicle',
    );
    return '$_temp0';
  }

  @override
  String get vehiclesTabTitle => 'Family Vehicles';

  @override
  String get vehiclesTabAdd => 'Add';

  @override
  String get vehiclesTabEmptyTitle => 'No vehicles in family';

  @override
  String get vehiclesTabEmptyBodyOwner =>
      'Tap \"Add\" to share a vehicle with your family';

  @override
  String get vehiclesTabEmptyBodyNonOwner => 'Ask the owner to share a vehicle';

  @override
  String get vehiclesTabSelectTitle => 'Select a vehicle to share';

  @override
  String get vehiclesTabSelectSubtitle =>
      'Choose vehicles from your garage to share with your family';

  @override
  String get vehiclesTabNoVehiclesToAdd =>
      'No vehicles available to add. Add vehicles to your garage first.';

  @override
  String vehiclesTabAddSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vehicles',
      one: '1 vehicle',
    );
    return 'Add $_temp0';
  }

  @override
  String get vehiclesTabRemoveTitle => 'Remove Vehicle';

  @override
  String vehiclesTabRemoveBody(Object vehicleName) {
    return 'Remove $vehicleName from family?';
  }

  @override
  String get inviteTabHeading => 'Share Your Family';

  @override
  String get inviteTabBody =>
      'Invite family members to join and share vehicles.';

  @override
  String get inviteTabShareCode => 'Share Code';

  @override
  String get inviteTabShareCodeHelper => 'Scan with DCO app to join';

  @override
  String get inviteTabCopyCode => 'Copy Code';

  @override
  String get inviteTabCodeCopied => 'Code copied!';

  @override
  String get inviteTabShare => 'Share';

  @override
  String inviteTabShareText(Object code) {
    return 'Join my DCO family! Code: $code';
  }

  @override
  String get inviteTabRegenerateButton => 'Regenerate Code';

  @override
  String get inviteTabRegenerateTitle => 'Regenerate Share Code?';

  @override
  String get inviteTabRegenerateBody =>
      'This will invalidate the current code. Members with the old code won\'t be able to join.';

  @override
  String get inviteTabRegenerateAction => 'Regenerate';

  @override
  String get inviteTabCodeExpiryHelper =>
      'Code expires in 7 days. Regenerating invalidates the old code.';

  @override
  String get carDetailTitle => 'Car Detail';

  @override
  String get carDetailNotFound => 'Vehicle not found';

  @override
  String get carDetailNotFoundBody => 'This vehicle could not be loaded.';

  @override
  String get carDetailIdentitySection => 'Vehicle Identity';

  @override
  String get carDetailVinPrefix => 'VIN: ';

  @override
  String get carDetailDocumentsSection => 'Documents';

  @override
  String get carDetailAddDocument => 'Add';

  @override
  String get carDetailNoDocuments => 'No documents yet';

  @override
  String get carDetailNoDocumentsBody =>
      'Add registration, insurance, or other documents.';

  @override
  String get carDetailAddDocumentAction => 'Add Document';

  @override
  String get carDetailDriversSection => 'Assigned Drivers';

  @override
  String get carDetailManageDrivers => 'Manage';

  @override
  String get carDetailNoDrivers => 'No drivers assigned';

  @override
  String get carDetailNoDriversBody =>
      'Add family members as drivers for this vehicle.';

  @override
  String get carDetailAssignDriver => 'Assign Driver';

  @override
  String get carDetailLicenseValid => 'Valid';

  @override
  String get carDetailLicenseExpiringSoon => 'Expiring Soon';

  @override
  String get carDetailLicenseExpired => 'Expired';

  @override
  String get carDetailLicenseNone => 'No License';

  @override
  String get carDetailFullAccess => 'Full Access';

  @override
  String get carDetailDriveOnly => 'Drive Only';

  @override
  String get carDetailQuickActions => 'Quick Actions';

  @override
  String get carDetailLogService => 'Log Service';

  @override
  String get carDetailLogFuel => 'Log Fuel';

  @override
  String get carDetailAddDocumentButton => 'Add Document';

  @override
  String get carDetailManageDriversButton => 'Manage Drivers';

  @override
  String get carDetailManageDriversSheet => 'Manage Drivers';

  @override
  String get carDetailCurrentDrivers => 'Current Drivers';

  @override
  String get carDetailAddDriver => 'Add Driver';

  @override
  String get carDetailAllAssigned => 'All family members are already assigned';

  @override
  String get carDetailLicensePrefix => 'License: ';

  @override
  String get carDetailAssign => 'Assign';

  @override
  String get userDetailProfileTitle => 'Profile';

  @override
  String get userDetailMemberTitle => 'Member Detail';

  @override
  String get userDetailNotFound => 'User not found';

  @override
  String get userDetailTakePhoto => 'Take Photo';

  @override
  String get userDetailChooseGallery => 'Choose from Gallery';

  @override
  String userDetailUploadFailed(Object error) {
    return 'Failed to upload: $error';
  }

  @override
  String get userDetailEditLicenseTitle => 'Edit Driving License';

  @override
  String get userDetailLicenseNumber => 'License Number';

  @override
  String get userDetailLicenseNumberHint => 'D1234567';

  @override
  String get userDetailIssuingCountry => 'Issuing Country (ISO)';

  @override
  String get userDetailIssuingCountryHint => 'US';

  @override
  String get userDetailExpiryDate => 'Expiry Date (YYYY-MM-DD)';

  @override
  String get userDetailExpiryDateHint => '2028-12-31';

  @override
  String get userDetailCategories => 'Categories';

  @override
  String get userDetailCategoriesHint => 'B, BE';

  @override
  String get userDetailLeaveFamilyTitle => 'Leave Family?';

  @override
  String get userDetailLeaveFamilyBody =>
      'Are you sure you want to leave this family? You will lose access to shared vehicles.';

  @override
  String get userDetailLeaveFamilyAction => 'Leave';

  @override
  String get userDetailLeftFamily => 'Left family';

  @override
  String get userDetailRemoveMemberTitle => 'Remove Member?';

  @override
  String get userDetailRemoveMemberBody =>
      'Are you sure you want to remove this member from the family? They will lose access to all shared vehicles.';

  @override
  String get userDetailRemoveMemberAction => 'Remove';

  @override
  String get userDetailMemberRemoved => 'Member removed';

  @override
  String get userDetailUploadLicensePhoto => 'Upload License Photo';

  @override
  String get userDetailPrimaryOwner => 'Primary Owner';

  @override
  String get userDetailMemberRole => 'Member';

  @override
  String get userDetailDriverRole => 'Driver';

  @override
  String get userDetailDrivingLicenseSection => 'Driving License';

  @override
  String get userDetailEditLicense => 'Edit';

  @override
  String get userDetailUploadLicense => 'Upload';

  @override
  String get userDetailNoLicense => 'No license uploaded';

  @override
  String get userDetailNoLicenseBody =>
      'Add your driving license to track expiry and share with family.';

  @override
  String get userDetailUploadLicenseAction => 'Upload License';

  @override
  String get userDetailFront => 'Front';

  @override
  String get userDetailBack => 'Back';

  @override
  String get userDetailExpires => 'Expires';

  @override
  String get userDetailNumber => 'Number';

  @override
  String get userDetailCountry => 'Country';

  @override
  String get userDetailLicenseValid => 'License Valid';

  @override
  String get userDetailLicenseExpiringSoon => 'Expiring Soon';

  @override
  String get userDetailLicenseExpired => 'Expired';

  @override
  String get userDetailLicenseNone => 'No License';

  @override
  String get userDetailAccessLevelSection => 'Access Level';

  @override
  String get userDetailPrimaryOwnerDescription => 'Primary Owner';

  @override
  String get userDetailFullControl => 'Full control over family';

  @override
  String get userDetailManageAllVehicles => 'Manage all vehicles';

  @override
  String get userDetailAddRemoveMembers => 'Add/remove members';

  @override
  String get userDetailAssignDriversPerm => 'Assign drivers';

  @override
  String get userDetailTransferOwnership => 'Transfer ownership';

  @override
  String get userDetailMemberDescription => 'Member (Secondary Owner)';

  @override
  String get userDetailFullAccessAssigned => 'Full access to assigned vehicles';

  @override
  String get userDetailLogMaintenanceExpenses => 'Log maintenance & expenses';

  @override
  String get userDetailManageDocumentsPerm => 'Manage documents';

  @override
  String get userDetailAssignDriversToVehicles => 'Assign drivers to vehicles';

  @override
  String get userDetailDriverDescription => 'Driver';

  @override
  String get userDetailViewAssignedVehicles => 'View assigned vehicles';

  @override
  String get userDetailLogFuelCharge => 'Log fuel/charge';

  @override
  String get userDetailViewMaintenanceDue => 'View maintenance due';

  @override
  String get userDetailViewDocumentsPerm => 'View documents';

  @override
  String get userDetailPermissionsSection => 'Permissions';

  @override
  String get userDetailMyVehiclesSection => 'My Vehicles';

  @override
  String get userDetailActionsSection => 'Actions';

  @override
  String get userDetailLeaveFamilyButton => 'Leave Family';

  @override
  String get userDetailAdminActionsSection => 'Admin Actions';

  @override
  String get userDetailChangeRole => 'Change Role';

  @override
  String get userDetailAssignVehicles => 'Assign Vehicles';

  @override
  String get userDetailRemoveFromFamily => 'Remove from Family';

  @override
  String get userDetailChangeRoleSheet => 'Change Role';

  @override
  String userDetailCurrentRole(Object role) {
    return 'Current: $role';
  }

  @override
  String get userDetailNewRole => 'New Role';

  @override
  String get userDetailSaveRole => 'Save';

  @override
  String get userDetailAssignVehiclesSheet => 'Assign Vehicles';

  @override
  String get userDetailNoVehiclesInGarage => 'No vehicles in garage';

  @override
  String get familyRolePrimaryOwner => 'Primary Owner';

  @override
  String get familyRoleMember => 'Member';

  @override
  String get familyRoleDriver => 'Driver';

  @override
  String get drawerQuickAccess => 'Quick Access';

  @override
  String get drawerFeatures => 'Features';

  @override
  String get drawerStats => 'Stats';

  @override
  String get drawerFamilyFleet => 'Family & Fleet';

  @override
  String get drawerSync => 'Sync';

  @override
  String get drawerDocuments => 'Documents';

  @override
  String get drawerParts => 'Parts';

  @override
  String get drawerMaintenancePlan => 'Maintenance Plan';

  @override
  String get drawerInsurance => 'Insurance';

  @override
  String get drawerRefuelStats => 'Refuel Stats';

  @override
  String get drawerMaintenanceStats => 'Maintenance Stats';

  @override
  String get drawerExpenseStats => 'Expense Stats';

  @override
  String get drawerFamily => 'Family';

  @override
  String get drawerFleet => 'Fleet';

  @override
  String get refuelStatsTitle => 'Refuel Stats';

  @override
  String get maintenanceStatsTitle => 'Maintenance Stats';

  @override
  String get expenseStatsTitle => 'Expense Stats';

  @override
  String get fleetTitle => 'Fleet Mode';

  @override
  String get syncStatusTitle => 'Sync Status';

  @override
  String get syncAutoSync => 'Auto Sync';

  @override
  String get syncAutoSyncDescription =>
      'Automatically sync data when connected';

  @override
  String get syncManualSync => 'Sync Now';

  @override
  String get syncPendingItems => 'Pending Items';

  @override
  String get syncPendingItemsDescription =>
      'Changes waiting to be synced to the server';

  @override
  String get syncNoPendingItems => 'All changes synced';

  @override
  String get syncStatusConnected => 'Connected';

  @override
  String get syncStatusOffline => 'Offline';

  @override
  String get syncLastSynced => 'Last synced';

  @override
  String get syncNever => 'Never';

  @override
  String get syncHowItWorks => 'How syncing works';

  @override
  String get syncHowItWorksDescription =>
      'Your data is stored locally first, then synced to the server when connected. Offline changes are queued and sent automatically.';

  @override
  String get syncVehicles => 'Vehicles';

  @override
  String get syncMaintenance => 'Maintenance';

  @override
  String get syncExpenses => 'Expenses';

  @override
  String get syncDocuments => 'Documents';

  @override
  String get syncParts => 'Parts';

  @override
  String get syncFuelLogs => 'Fuel Logs';

  @override
  String get syncOther => 'Other';

  @override
  String get registerSuccessTitle => 'Service Logged!';

  @override
  String get registerSuccessSubtitle =>
      'Your maintenance record has been saved successfully.';

  @override
  String get registerSuccessDetails => 'Logged Details';

  @override
  String get registerSuccessBackHome => 'Back to Home';

  @override
  String get registerErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get notesTitle => 'Notes';

  @override
  String get notesEmptyTitle => 'No notes yet';

  @override
  String get notesEmptyBody =>
      'Capture ideas, checklists, and reminders in one place.';

  @override
  String get notesNewNote => 'New note';

  @override
  String get notesLoadError => 'Could not load notes';

  @override
  String get noteFormAddTitle => 'New note';

  @override
  String get noteFormEditTitle => 'Edit note';

  @override
  String get noteFormTitle => 'Title';

  @override
  String get noteFormTitleHint => 'Note title (optional)';

  @override
  String get noteFormBody => 'Note';

  @override
  String get noteFormBodyHint => 'Start writing…';

  @override
  String get noteUntitled => 'Untitled';

  @override
  String get noteEmptyError => 'Note cannot be empty';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String get noteUndo => 'Undo';

  @override
  String get noteDelete => 'Delete';
}
