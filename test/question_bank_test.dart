import 'dart:convert';
import 'dart:io';

import 'package:colibri_quiz/models/question.dart';
import 'package:flutter_test/flutter_test.dart';

List<Question> loadCategory(QuestionCategory category) {
  final file = File('assets/questions/${category.name}.json');
  final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return decoded
      .map((e) => Question.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  const originales = {
    QuestionCategory.literatura,
    QuestionCategory.geografia,
    QuestionCategory.historia,
    QuestionCategory.matematicas,
  };
  final byCategory = {
    for (final category in QuestionCategory.values)
      category: loadCategory(category),
  };
  final all = [
    for (final list in byCategory.values) ...list,
  ];

  group('Banco de preguntas', () {
    test('tiene preguntas suficientes', () {
      expect(all.length, greaterThanOrEqualTo(100));
      for (final category in QuestionCategory.values) {
        final minimo = originales.contains(category) ? 15 : 10;
        expect(byCategory[category]!.length, greaterThanOrEqualTo(minimo),
            reason: 'Faltan preguntas en ${category.label}');
      }
    });

    test('los ids son únicos', () {
      final ids = all.map((q) => q.id).toSet();
      expect(ids.length, all.length);
    });

    test('cada pregunta está bien formada', () {
      for (final q in all) {
        expect(q.options.length, inInclusiveRange(4, 5),
            reason: 'Pregunta ${q.id}');
        expect(q.optionAnalysis.length, q.options.length,
            reason: 'Pregunta ${q.id}');
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1),
            reason: q.id);
        expect(q.statement.trim(), isNotEmpty, reason: q.id);
        expect(q.explanation.trim(), isNotEmpty, reason: q.id);
        expect(q.topic.trim(), isNotEmpty, reason: q.id);
        for (final option in q.options) {
          expect(option.trim(), isNotEmpty, reason: q.id);
        }
        expect(q.options.toSet().length, q.options.length,
            reason: 'Opciones duplicadas en ${q.id}');
        for (final analysis in q.optionAnalysis) {
          expect(analysis.trim(), isNotEmpty, reason: 'Análisis en ${q.id}');
        }
      }
    });

    test('las preguntas con texto de apoyo están bien separadas', () {
      for (final q in all) {
        if (!q.hasSupport) continue;
        expect(q.questionText.trim(), isNotEmpty, reason: q.id);
        expect(q.supportText.trim(), isNotEmpty, reason: q.id);
        expect(q.statement, contains('\n\n'), reason: q.id);
      }
    });

    test('cubre las siete categorías y las cinco fuentes', () {
      for (final category in QuestionCategory.values) {
        expect(byCategory[category], isNotEmpty,
            reason: 'Sin preguntas en ${category.label}');
      }

      final sources = all.map((q) => q.source).toSet();
      for (final source in QuestionSource.values) {
        expect(sources, contains(source),
            reason: 'Sin preguntas de ${source.label}');
      }
    });

    test('incluye los tres niveles de dificultad', () {
      final levels = all.map((q) => q.difficulty).toSet();
      expect(levels, containsAll(QuestionDifficulty.values));
    });
  });
}
