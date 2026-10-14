import '../models/progress_state.dart';

class SrsScheduler {
  SrsScheduler._();

  static SrsEntry schedule({
    SrsEntry? current,
    required bool correct,
    required DateTime now,
  }) {
    final reviews = (current?.reviews ?? 0) + 1;
    final ease = current?.ease ?? 2.5;

    if (!correct) {
      return SrsEntry(
        due: now,
        intervalDays: 0,
        ease: double.parse((ease - 0.2).clamp(1.3, 2.8).toStringAsFixed(2)),
        reviews: reviews,
      );
    }

    final previousInterval = current?.intervalDays ?? 0;
    final newEase = double.parse((ease + 0.05).clamp(1.3, 2.8).toStringAsFixed(2));
    final int interval;
    if (previousInterval <= 0) {
      interval = 1;
    } else if (previousInterval == 1) {
      interval = 3;
    } else {
      interval = (previousInterval * newEase).round().clamp(1, 120);
    }

    return SrsEntry(
      due: now.add(Duration(days: interval)),
      intervalDays: interval,
      ease: newEase,
      reviews: reviews,
    );
  }
}
