import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/question.dart';
import '../models/quiz_config.dart';

class QuestionRepository {
  QuestionRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<Question>? _cache;

  Future<List<Question>> loadAll() async {
    if (_cache != null) return _cache!;

    final questions = <Question>[];
    for (final category in QuestionCategory.values) {
      final raw = await _bundle.loadString('assets/questions/${category.name}.json');
      final decoded = jsonDecode(raw) as List<dynamic>;
      questions.addAll(decoded.map(
        (e) => Question.fromJson(e as Map<String, dynamic>),
      ));
    }

    final ids = <String>{};
    for (final q in questions) {
      if (!ids.add(q.id)) {
        throw StateError('Id de pregunta duplicado: ${q.id}');
      }
    }

    _cache = questions;
    return questions;
  }

  Future<List<Question>> byIds(Iterable<String> ids) async {
    final all = await loadAll();
    final wanted = ids.toSet();
    return all.where((q) => wanted.contains(q.id)).toList();
  }

  int countMatching({
    QuestionCategory? category,
    QuestionDifficulty? difficulty,
    QuestionSource? source,
  }) {
    final all = _cache;
    if (all == null) return 0;
    return all.where((q) {
      if (category != null && q.category != category) return false;
      if (difficulty != null && q.difficulty != difficulty) return false;
      if (source != null && q.source != source) return false;
      return true;
    }).length;
  }

  Future<int> countDue(Set<String> dueIds) async {
    final all = await loadAll();
    return all.where((q) => dueIds.contains(q.id)).length;
  }

  Future<List<Question>> pick(QuizConfig config) async {
    final all = await loadAll();

    var pool = all.where((q) {
      if (config.category != null && q.category != config.category) {
        return false;
      }
      if (config.difficulty != null && q.difficulty != config.difficulty) {
        return false;
      }
      if (config.source != null && q.source != config.source) return false;
      return true;
    }).toList();

    final random = Random();
    pool = List.of(pool)..shuffle(random);

    if (pool.length < config.count) {
      throw StateError(
        'Solo hay ${pool.length} preguntas para estos filtros '
        '(se pidieron ${config.count}).',
      );
    }

    return pool.take(config.count).toList();
  }

  Future<List<Question>> pickReview({
    required Set<String> dueIds,
    int count = 10,
  }) async {
    final all = await loadAll();
    final due = all.where((q) => dueIds.contains(q.id)).toList()
      ..shuffle(Random());
    if (due.isEmpty) return const [];
    return due.take(count).toList();
  }
}
