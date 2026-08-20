enum MileageUnit {
  mi,
  km;

  String get label => this == MileageUnit.mi ? 'mi' : 'km';

  String get fullLabel => this == MileageUnit.mi ? 'Miles' : 'Kilometers';

  /// Canonical storage is miles. 1 mi = 1.609344 km.
  static const kmPerMile = 1.609344;

  double toDisplay(double storedMiles) {
    return this == MileageUnit.km ? storedMiles * kmPerMile : storedMiles;
  }

  double toStorage(double displayed) {
    return this == MileageUnit.km ? displayed / kmPerMile : displayed;
  }

  static MileageUnit parse(String value) {
    return value == 'km' ? MileageUnit.km : MileageUnit.mi;
  }
}
