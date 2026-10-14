import '../models/progress_state.dart';
import '../models/question.dart';
import '../models/quiz_config.dart';
import 'srs.dart';

class Rank {
  const Rank(this.name, this.minXp, this.emoji);

  final String name;
  final int minXp;
  final String emoji;

  static const List<Rank> all = [
    Rank('Novato', 0, '🐣'),
    Rank('Estudiante', 300, '📚'),
    Rank('Aprendiz', 900, '🦉'),
    Rank('Erudito', 2000, '🧠'),
    Rank('Maestro', 4000, '👑'),
  ];

  static Rank of(int xp) {
    Rank current = all.first;
    for (final rank in all) {
      if (xp >= rank.minXp) current = rank;
    }
    return current;
  }

  static Rank? next(int xp) {
    for (final rank in all) {
      if (xp < rank.minXp) return rank;
    }
    return null;
  }

  static double progressOf(int xp) {
    final current = of(xp);
    final nextRank = next(xp);
    if (nextRank == null) return 1;
    final span = nextRank.minXp - current.minXp;
    if (span <= 0) return 1;
    return ((xp - current.minXp) / span).clamp(0, 1).toDouble();
  }
}

class XpCalculator {
  XpCalculator._();

  static int forAnswer({
    required bool correct,
    required Question question,
    required QuizMode mode,
    Duration timeSpent = Duration.zero,
  }) {
    if (!correct) return 0;

    var xp = 10;
    xp += switch (question.difficulty) {
      QuestionDifficulty.basico => 0,
      QuestionDifficulty.intermedio => 3,
      QuestionDifficulty.dificil => 6,
    };

    if (mode == QuizMode.timed) {
      if (timeSpent.inSeconds < 10) {
        xp += 5;
      } else if (timeSpent.inSeconds < 20) {
        xp += 2;
      }
    }
    return xp;
  }
}

class DayStamp {
  DayStamp._();

  static String of(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String yesterdayOf(DateTime date) => of(
        DateTime(date.year, date.month, date.day).subtract(
          const Duration(days: 1),
        ),
      );
}

ProgressState applySessionToProgress({
  required ProgressState state,
  required SessionResult result,
  required int xpGained,
  required DateTime now,
}) {
  final today = DayStamp.of(now);
  var streak = state.streak;
  if (state.dailyDate != today) {
    streak = state.dailyDate == DayStamp.yesterdayOf(now)
        ? state.streak + 1
        : 1;
  }

  final dailyXp =
      state.dailyDate == today ? state.dailyXp + xpGained : xpGained;
  final newXp = state.xp + xpGained;

  final stats = Map<String, CategoryStats>.from(state.stats);
  final srs = Map<String, SrsEntry>.from(state.srs);

  for (var i = 0; i < result.questions.length; i++) {
    final answer = result.answers[i];
    if (answer == null) continue;
    final question = result.questions[i];
    final isCorrect = answer == question.correctIndex;

    final key = question.category.name;
    final base = stats[key] ?? const CategoryStats();
    stats[key] = base.add(isCorrect: isCorrect);

    srs[question.id] = SrsScheduler.schedule(
      current: srs[question.id],
      correct: isCorrect,
      now: now,
    );
  }

  return state.copyWith(
    xp: newXp,
    streak: streak,
    bestStreak: streak > state.bestStreak ? streak : state.bestStreak,
    dailyXp: dailyXp,
    dailyDate: today,
    sessions: state.sessions + 1,
    stats: stats,
    srs: srs,
  );
}
