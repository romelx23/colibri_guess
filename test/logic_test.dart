import 'package:colibri_quiz/logic/srs.dart';
import 'package:colibri_quiz/logic/xp.dart';
import 'package:colibri_quiz/models/progress_state.dart';
import 'package:colibri_quiz/models/question.dart';
import 'package:colibri_quiz/models/quiz_config.dart';
import 'package:flutter_test/flutter_test.dart';

Question sampleQuestion({
  String id = 'lit-001',
  QuestionDifficulty difficulty = QuestionDifficulty.basico,
  QuestionCategory category = QuestionCategory.literatura,
}) {
  return Question(
    id: id,
    category: category,
    topic: 'Tema',
    source: QuestionSource.unmsm,
    difficulty: difficulty,
    statement: '¿Pregunta?',
    options: const ['A', 'B', 'C', 'D'],
    correctIndex: 1,
    explanation: 'Porque sí.',
    optionAnalysis: const ['no 1', 'sí', 'no 2', 'no 3'],
  );
}

SessionResult sampleResult({
  List<int?> answers = const [1, 0, null],
  QuizMode mode = QuizMode.normal,
}) {
  final questions = [
    sampleQuestion(id: 'a'),
    sampleQuestion(id: 'b'),
    sampleQuestion(id: 'c'),
  ];
  return SessionResult(
    questions: questions,
    answers: answers,
    answerTimes: const [Duration.zero, Duration.zero, Duration.zero],
    startedAt: DateTime(2026, 10, 7, 10),
    finishedAt: DateTime(2026, 10, 7, 10, 5),
    mode: mode,
  );
}

void main() {
  group('Conteo de resultados', () {
    test('cuenta correctas, erradas y en blanco', () {
      final result = sampleResult();
      expect(result.total, 3);
      expect(result.correct, 1);
      expect(result.wrong, 1);
      expect(result.unanswered, 1);
      expect(result.accuracy, closeTo(1 / 3, 0.001));
      expect(result.wrongIndexes, [1, 2]);
    });
  });

  group('XP y rangos', () {
    test('una básica normal vale 10 XP', () {
      expect(
        XpCalculator.forAnswer(
          correct: true,
          question: sampleQuestion(),
          mode: QuizMode.normal,
        ),
        10,
      );
    });

    test('dificil da bono y fallar da 0', () {
      expect(
        XpCalculator.forAnswer(
          correct: true,
          question: sampleQuestion(difficulty: QuestionDifficulty.dificil),
          mode: QuizMode.normal,
        ),
        16,
      );
      expect(
        XpCalculator.forAnswer(
          correct: false,
          question: sampleQuestion(),
          mode: QuizMode.normal,
        ),
        0,
      );
    });

    test('cronometrado premia la rapidez', () {
      final fast = XpCalculator.forAnswer(
        correct: true,
        question: sampleQuestion(),
        mode: QuizMode.timed,
        timeSpent: const Duration(seconds: 6),
      );
      final slow = XpCalculator.forAnswer(
        correct: true,
        question: sampleQuestion(),
        mode: QuizMode.timed,
        timeSpent: const Duration(seconds: 30),
      );
      expect(fast, 15);
      expect(slow, 10);
    });

    test('rangos por XP', () {
      expect(Rank.of(0).name, 'Novato');
      expect(Rank.of(299).name, 'Novato');
      expect(Rank.of(300).name, 'Estudiante');
      expect(Rank.of(4000).name, 'Maestro');
      expect(Rank.next(4000), isNull);
      expect(Rank.progressOf(150), closeTo(0.5, 0.01));
    });
  });

  group('Repaso espaciado', () {
    final now = DateTime(2026, 10, 7, 9);

    test('el primer acierto programa mañana', () {
      final entry = SrsScheduler.schedule(current: null, correct: true, now: now);
      expect(entry.intervalDays, 1);
      expect(entry.due.day, now.add(const Duration(days: 1)).day);
      expect(entry.reviews, 1);
    });

    test('fallar reprograma para hoy mismo y baja el ease', () {
      final first = SrsScheduler.schedule(current: null, correct: true, now: now);
      final failed = SrsScheduler.schedule(current: first, correct: false, now: now);
      expect(failed.intervalDays, 0);
      expect(failed.due.isAfter(now), isFalse);
      expect(failed.ease, lessThan(first.ease));
    });

    test('aciertos consecutivos alargan el intervalo', () {
      var entry = SrsScheduler.schedule(current: null, correct: true, now: now);
      entry = SrsScheduler.schedule(current: entry, correct: true, now: now);
      expect(entry.intervalDays, 3);
      entry = SrsScheduler.schedule(current: entry, correct: true, now: now);
      expect(entry.intervalDays, greaterThan(3));
    });
  });

  group('Progreso y racha', () {
    final day1 = DateTime(2026, 10, 5, 20);
    final day2 = DateTime(2026, 10, 6, 9);
    final day4 = DateTime(2026, 10, 8, 9);

    test('la primera sesión inicia la racha', () {
      final next = applySessionToProgress(
        state: const ProgressState(),
        result: sampleResult(),
        xpGained: 10,
        now: day1,
      );
      expect(next.streak, 1);
      expect(next.xp, 10);
      expect(next.dailyXp, 10);
      expect(next.sessions, 1);
      expect(next.stats['literatura']!.answered, 2);
      expect(next.stats['literatura']!.correct, 1);
      expect(next.srs.length, 2);
    });

    test('el mismo día acumula XP sin romper la racha', () {
      final first = applySessionToProgress(
        state: const ProgressState(),
        result: sampleResult(),
        xpGained: 10,
        now: day1,
      );
      final second = applySessionToProgress(
        state: first,
        result: sampleResult(),
        xpGained: 15,
        now: day1.add(const Duration(hours: 2)),
      );
      expect(second.streak, 1);
      expect(second.dailyXp, 25);
      expect(second.xp, 25);
    });

    test('al día siguiente la racha sube; tras un hueco se reinicia', () {
      final first = applySessionToProgress(
        state: const ProgressState(),
        result: sampleResult(),
        xpGained: 10,
        now: day1,
      );
      final nextDay = applySessionToProgress(
        state: first,
        result: sampleResult(),
        xpGained: 10,
        now: day2,
      );
      expect(nextDay.streak, 2);
      expect(nextDay.bestStreak, 2);
      expect(nextDay.dailyXp, 10);

      final gap = applySessionToProgress(
        state: nextDay,
        result: sampleResult(),
        xpGained: 10,
        now: day4,
      );
      expect(gap.streak, 1);
      expect(gap.bestStreak, 2);
    });

    test('las preguntas en blanco no se califican', () {
      final next = applySessionToProgress(
        state: const ProgressState(),
        result: sampleResult(),
        xpGained: 10,
        now: day1,
      );
      expect(next.srs.containsKey('c'), isFalse);
      expect(next.stats['literatura']!.answered, 2);
    });
  });

  group('Persistencia', () {
    test('el progreso sobrevive a ida y vuelta JSON', () {
      final now = DateTime(2026, 10, 7, 10);
      final state = applySessionToProgress(
        state: const ProgressState(),
        result: sampleResult(),
        xpGained: 25,
        now: now,
      );
      final restored = ProgressState.fromJson(state.toJson());
      expect(restored.xp, state.xp);
      expect(restored.streak, state.streak);
      expect(restored.dailyDate, state.dailyDate);
      expect(restored.stats['literatura']!.correct,
          state.stats['literatura']!.correct);
      expect(restored.srs['a']!.intervalDays, state.srs['a']!.intervalDays);
      expect(restored.srs['a']!.due, state.srs['a']!.due);
    });
  });
}
