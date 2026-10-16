import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/progress_store.dart';
import '../../data/question_repository.dart';
import '../../logic/xp.dart';
import '../../models/progress_state.dart';
import '../../models/question.dart';
import '../../models/quiz_config.dart';

final questionRepositoryProvider = Provider<QuestionRepository>(
  (ref) => QuestionRepository(),
);

final questionCountsProvider =
    FutureProvider<Map<QuestionCategory, int>>((ref) async {
  final repo = ref.watch(questionRepositoryProvider);
  final all = await repo.loadAll();
  final counts = {for (final c in QuestionCategory.values) c: 0};
  for (final q in all) {
    counts[q.category] = counts[q.category]! + 1;
  }
  return counts;
});

final progressStoreProvider = FutureProvider<ProgressStore>(
  (ref) => ProgressStore.open(),
);

final progressProvider =
    AsyncNotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);

class ProgressNotifier extends AsyncNotifier<ProgressState> {
  @override
  Future<ProgressState> build() async {
    final store = await ref.watch(progressStoreProvider.future);
    return rollDailyXp(store.load(), DateTime.now());
  }

  Future<ProgressState> applySession({
    required SessionResult result,
    required int xpGained,
    required DateTime now,
  }) async {
    final store = await ref.read(progressStoreProvider.future);
    final current = state.valueOrNull ?? const ProgressState();
    final next = applySessionToProgress(
      state: current,
      result: result,
      xpGained: xpGained,
      now: now,
    );
    state = AsyncData(next);
    await store.save(next);
    return next;
  }

  Future<void> resetAll() async {
    final store = await ref.read(progressStoreProvider.future);
    await store.reset();
    state = const AsyncData(ProgressState());
  }
}
