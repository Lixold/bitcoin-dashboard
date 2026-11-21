import '../../../l10n/generated/app_localizations.dart';

/// The unit a countdown part or an "about" phrase is counted in.
enum CountdownUnit {
  days,
  hours,
  minutes;

  /// The unit's label under its number in the countdown, by count.
  String label(AppL10n l10n, int count) => switch (this) {
    CountdownUnit.days => l10n.difficultyUnitDays(count),
    CountdownUnit.hours => l10n.difficultyUnitHours(count),
    CountdownUnit.minutes => l10n.difficultyUnitMinutes(count),
  };

  /// "5 days", worded to sit after "in about" in the sentence. German
  /// needs the dative here ("in etwa 5 Tagen"), which is why this is its
  /// own key and not the countdown label with a number in front.
  String phrase(AppL10n l10n, int count) => switch (this) {
    CountdownUnit.days => l10n.difficultyAboutDays(count),
    CountdownUnit.hours => l10n.difficultyAboutHours(count),
    CountdownUnit.minutes => l10n.difficultyAboutMinutes(count),
  };
}

/// One number of the countdown with the unit it counts.
typedef CountdownPart = ({int value, CountdownUnit unit});

/// The countdown as the figure shows it: the two largest units that
/// matter, each truncated.
///
/// Days and hours from one day out, hours and minutes below a day, minutes
/// alone below an hour. Truncated rather than rounded so that the parts
/// never add up to more than is left: "5 d 9 h" with 5 d 9 h 50 min to go
/// is true, "5 d 10 h" would not be.
///
/// Seconds never appear. The estimate is replaced every five minutes and
/// moves with every block; a second hand would claim a precision the
/// reading does not have.
List<CountdownPart> countdownParts(Duration remaining) {
  final r = remaining.isNegative ? Duration.zero : remaining;
  if (r.inDays >= 1) {
    return [
      (value: r.inDays, unit: CountdownUnit.days),
      (value: r.inHours.remainder(24), unit: CountdownUnit.hours),
    ];
  }
  if (r.inHours >= 1) {
    return [
      (value: r.inHours, unit: CountdownUnit.hours),
      (value: r.inMinutes.remainder(60), unit: CountdownUnit.minutes),
    ];
  }
  return [(value: r.inMinutes, unit: CountdownUnit.minutes)];
}

/// The remaining time as the sentence names it: the largest whole unit,
/// rounded to the nearest count, never below one.
///
/// "About" is the hedge, so this rounds where the countdown truncates:
/// 5 d 14 h reads "about 6 days". The unit is chosen on the same
/// boundaries as [countdownParts], so the sentence and the figure always
/// count in the same unit. At least one, because "in about 0 minutes"
/// says nothing a reader could act on while the adjustment is still to
/// come.
CountdownPart aboutRemaining(Duration remaining) {
  final r = remaining.isNegative ? Duration.zero : remaining;
  int nearest(int micros, Duration unit) {
    final count = (micros / unit.inMicroseconds).round();
    return count < 1 ? 1 : count;
  }

  if (r.inDays >= 1) {
    return (
      value: nearest(r.inMicroseconds, const Duration(days: 1)),
      unit: CountdownUnit.days,
    );
  }
  if (r.inHours >= 1) {
    return (
      value: nearest(r.inMicroseconds, const Duration(hours: 1)),
      unit: CountdownUnit.hours,
    );
  }
  return (
    value: nearest(r.inMicroseconds, const Duration(minutes: 1)),
    unit: CountdownUnit.minutes,
  );
}
