/// Bump when the tour content changes materially so every account is offered
/// the new version once, even if a previous version was completed.
const int kTourVersion = 1;

enum TourStatus {
  /// This account has not seen the current tour version.
  notSeen,

  /// The user declined or left the tour before finishing.
  dismissed,

  /// The user reached the final step.
  completed,
}

class TourProgress {
  const TourProgress({required this.version, required this.status});

  const TourProgress.notSeen()
    : version = kTourVersion,
      status = TourStatus.notSeen;

  final int version;
  final TourStatus status;

  /// Only a version the account has never acted on is offered automatically.
  bool get shouldOffer => status == TourStatus.notSeen;

  TourProgress copyWith({int? version, TourStatus? status}) => TourProgress(
    version: version ?? this.version,
    status: status ?? this.status,
  );

  @override
  bool operator ==(Object other) =>
      other is TourProgress &&
      other.version == version &&
      other.status == status;

  @override
  int get hashCode => Object.hash(version, status);
}
