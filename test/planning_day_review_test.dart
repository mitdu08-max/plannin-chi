import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/services/planning_day_review.dart';

void main() {
  group('PlanningDayReview', () {
    test('les cases non lues ne sont pas supposées être du repos', () {
      final review = PlanningDayReview(
        totalDays: 4,
        detected: {1: 'N', 2: 'RH', 4: 'CA'},
      );
      expect(review.days, {1: 'N', 2: 'R', 3: '?', 4: 'CA'});
      expect(review.isComplete, isFalse);
      expect(review.workingDays, [1]);
      expect(review.vacations, {4: 'CA'});
    });

    test('permet de corriger les nuits et les congés', () {
      final review = PlanningDayReview(totalDays: 3, detected: {1: 'N'});
      review.markUnresolvedAsOther();
      review.setDay(1, 'R');
      review.setDay(2, 'N');
      review.setDay(3, 'CET');
      expect(review.isComplete, isTrue);
      expect(review.workingDays, [2]);
      expect(review.vacations, {3: 'CET'});
    });

    test('ne devine pas la signification des codes CS et FC', () {
      final review = PlanningDayReview(
        totalDays: 2,
        detected: {1: 'CS', 2: 'FC'},
      );
      expect(review.days, {1: '?', 2: '?'});
      expect(review.isComplete, isFalse);
    });

    test('rejette un jour ou code invalide', () {
      final review = PlanningDayReview(totalDays: 2);
      expect(() => review.setDay(3, 'N'), throwsArgumentError);
      expect(() => review.setDay(1, 'BAD'), throwsArgumentError);
    });
  });
}
