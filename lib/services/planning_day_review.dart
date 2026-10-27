/// État de la vérification manuelle d'une ligne de planning OCR.
/// Une case manquante n'est jamais automatiquement considérée comme du repos.
class PlanningDayReview {
  PlanningDayReview({
    required int totalDays,
    Map<int, String> detected = const {},
  }) : days = {
         for (var day = 1; day <= totalDays; day++)
           day: _editableCode(detected[day]),
       };

  static const unknown = '?';
  static const other = 'R';
  static const choices = <String>['N', other, 'CA', 'CET', 'CFR'];

  /// N = nuit, R = repos/formation/autre, CA/CET/CFR = congés reconnus.
  final Map<int, String> days;

  static String _editableCode(String? code) {
    if (code == null) return unknown;
    final normalized = code.toUpperCase();
    if (choices.contains(normalized)) return normalized;
    if (const {'RH', 'F', 'F_EXT', 'J'}.contains(normalized)) return other;
    // CS, FC et tout code non pris en charge demandent une décision humaine.
    return unknown;
  }

  int get unresolvedCount =>
      days.values.where((value) => value == unknown).length;
  bool get isComplete => unresolvedCount == 0;

  void setDay(int day, String code) {
    if (!days.containsKey(day) || !choices.contains(code)) {
      throw ArgumentError('Jour ou code de planning invalide.');
    }
    days[day] = code;
  }

  void markUnresolvedAsOther() {
    for (final day in days.keys.toList()) {
      if (days[day] == unknown) days[day] = other;
    }
  }

  List<int> get workingDays => days.entries
      .where((entry) => entry.value == 'N')
      .map((entry) => entry.key)
      .toList();

  Map<int, String> get vacations => {
    for (final entry in days.entries)
      if (const {'CA', 'CET', 'CFR'}.contains(entry.value))
        entry.key: entry.value,
  };
}
