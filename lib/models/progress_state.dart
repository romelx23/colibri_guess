class CategoryStats {
  const CategoryStats({this.answered = 0, this.correct = 0});

  final int answered;
  final int correct;

  double get accuracy => answered == 0 ? 0 : correct / answered;

  CategoryStats add({required bool isCorrect}) => CategoryStats(
        answered: answered + 1,
        correct: correct + (isCorrect ? 1 : 0),
      );

  Map<String, dynamic> toJson() => {'answered': answered, 'correct': correct};

  factory CategoryStats.fromJson(Map<String, dynamic> json) => CategoryStats(
        answered: json['answered'] as int? ?? 0,
        correct: json['correct'] as int? ?? 0,
      );
}

class SrsEntry {
  const SrsEntry({
    required this.due,
    required this.intervalDays,
    required this.ease,
    required this.reviews,
  });

  final DateTime due;
  final int intervalDays;
  final double ease;
  final int reviews;

  bool isDue(DateTime now) => !due.isAfter(now);

  Map<String, dynamic> toJson() => {
        'due': due.millisecondsSinceEpoch,
        'interval': intervalDays,
        'ease': ease,
        'reviews': reviews,
      };

  factory SrsEntry.fromJson(Map<String, dynamic> json) => SrsEntry(
        due: DateTime.fromMillisecondsSinceEpoch(json['due'] as int),
        intervalDays: json['interval'] as int? ?? 0,
        ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
        reviews: json['reviews'] as int? ?? 0,
      );
}

class ProgressState {
  const ProgressState({
    this.xp = 0,
    this.points = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.dailyXp = 0,
    this.dailyDate = '',
    this.sessions = 0,
    this.stats = const {},
    this.srs = const {},
  });

  final int xp;
  final int points;
  final int streak;
  final int bestStreak;
  final int dailyXp;
  final String dailyDate;
  final int sessions;
  final Map<String, CategoryStats> stats;
  final Map<String, SrsEntry> srs;

  static const int dailyGoal = 30;

  double get dailyProgress =>
      (dailyXp / dailyGoal).clamp(0, 1).toDouble();

  int get totalAnswered =>
      stats.values.fold(0, (sum, s) => sum + s.answered);

  int get totalCorrect => stats.values.fold(0, (sum, s) => sum + s.correct);

  double get globalAccuracy =>
      totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  int dueReviewCount(DateTime now) =>
      srs.values.where((e) => e.isDue(now)).length;

  ProgressState copyWith({
    int? xp,
    int? points,
    int? streak,
    int? bestStreak,
    int? dailyXp,
    String? dailyDate,
    int? sessions,
    Map<String, CategoryStats>? stats,
    Map<String, SrsEntry>? srs,
  }) {
    return ProgressState(
      xp: xp ?? this.xp,
      points: points ?? this.points,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      dailyXp: dailyXp ?? this.dailyXp,
      dailyDate: dailyDate ?? this.dailyDate,
      sessions: sessions ?? this.sessions,
      stats: stats ?? this.stats,
      srs: srs ?? this.srs,
    );
  }

  factory ProgressState.fromJson(Map<String, dynamic> json) {
    final statsJson =
        Map<String, dynamic>.from(json['stats'] as Map? ?? const {});
    final srsJson =
        Map<String, dynamic>.from(json['srs'] as Map? ?? const {});

    return ProgressState(
      xp: json['xp'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      dailyXp: json['dailyXp'] as int? ?? 0,
      dailyDate: json['dailyDate'] as String? ?? '',
      sessions: json['sessions'] as int? ?? 0,
      stats: {
        for (final entry in statsJson.entries)
          entry.key: CategoryStats.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
      srs: {
        for (final entry in srsJson.entries)
          entry.key: SrsEntry.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'points': points,
        'streak': streak,
        'bestStreak': bestStreak,
        'dailyXp': dailyXp,
        'dailyDate': dailyDate,
        'sessions': sessions,
        'stats': {for (final e in stats.entries) e.key: e.value.toJson()},
        'srs': {for (final e in srs.entries) e.key: e.value.toJson()},
      };
}
