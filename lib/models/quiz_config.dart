import '../models/question.dart';

enum QuizMode { normal, timed, exam }

extension QuizModeX on QuizMode {
  String get label => switch (this) {
        QuizMode.normal => 'Modo normal',
        QuizMode.timed => 'Modo cronometrado',
        QuizMode.exam => 'Examen de admisión',
      };

  String get description => switch (this) {
        QuizMode.normal =>
          'Retroalimentación inmediata: por qué acertaste y por qué no es cada otra opción.',
        QuizMode.timed =>
          'Contra reloj, sin pistas. Las explicaciones llegan al final del examen.',
        QuizMode.exam =>
          'Hoja de respuestas con bolillas, sin pistas. Corte de aprobación al terminar.',
      };
}

class QuizConfig {
  const QuizConfig({
    this.category,
    this.difficulty,
    this.source,
    this.count = 10,
    this.mode = QuizMode.normal,
    this.timeLimitSeconds,
    this.reviewOnly = false,
    this.title,
    this.cutoffPercent = 70,
  });

  final QuestionCategory? category;
  final QuestionDifficulty? difficulty;
  final QuestionSource? source;
  final int count;
  final QuizMode mode;
  final int? timeLimitSeconds;
  final bool reviewOnly;
  final String? title;
  final int cutoffPercent;

  Duration? get timeLimit =>
      timeLimitSeconds == null ? null : Duration(seconds: timeLimitSeconds!);

  QuizConfig copyWith({
    QuestionCategory? category,
    QuestionDifficulty? difficulty,
    QuestionSource? source,
    int? count,
    QuizMode? mode,
    int? timeLimitSeconds,
    bool? reviewOnly,
    String? title,
    int? cutoffPercent,
  }) {
    return QuizConfig(
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      source: source ?? this.source,
      count: count ?? this.count,
      mode: mode ?? this.mode,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      reviewOnly: reviewOnly ?? this.reviewOnly,
      title: title ?? this.title,
      cutoffPercent: cutoffPercent ?? this.cutoffPercent,
    );
  }
}

class SessionResult {
  const SessionResult({
    required this.questions,
    required this.answers,
    required this.answerTimes,
    required this.startedAt,
    required this.finishedAt,
    required this.mode,
  });

  final List<Question> questions;
  final List<int?> answers;
  final List<Duration> answerTimes;
  final DateTime startedAt;
  final DateTime finishedAt;
  final QuizMode mode;

  int get total => questions.length;

  int get correct {
    var n = 0;
    for (var i = 0; i < questions.length; i++) {
      if (answers[i] == questions[i].correctIndex) n++;
    }
    return n;
  }

  int get wrong {
    var n = 0;
    for (var i = 0; i < questions.length; i++) {
      if (answers[i] != null && answers[i] != questions[i].correctIndex) n++;
    }
    return n;
  }

  int get unanswered {
    var n = 0;
    for (final a in answers) {
      if (a == null) n++;
    }
    return n;
  }

  double get accuracy => total == 0 ? 0 : correct / total;

  Duration get elapsed => finishedAt.difference(startedAt);

  List<int> get wrongIndexes {
    final list = <int>[];
    for (var i = 0; i < questions.length; i++) {
      if (answers[i] != questions[i].correctIndex) list.add(i);
    }
    return list;
  }
}
