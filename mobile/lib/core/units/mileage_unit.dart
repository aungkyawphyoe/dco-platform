enum MileageUnit {
  km;

  String get label => 'km';

  String get fullLabel => 'Kilometers';

  /// Canonical storage is miles. 1 mi = 1.609344 km.
  static const kmPerMile = 1.609344;

  double toDisplay(double storedMiles) {
    return storedMiles * kmPerMile;
  }

  double toStorage(double displayed) {
    return displayed / kmPerMile;
  }

  static MileageUnit parse(String value) => MileageUnit.km;
}
