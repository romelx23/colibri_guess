import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/session_provider.dart';

enum DuelPhase { lobby, waiting, playing, result, error }

class DuelQuestion {
  const DuelQuestion({
    required this.index,
    required this.enunciado,
    required this.options,
    this.categoria = '',
    this.referencia = '',
  });

  final int index;
  final String enunciado;
  final List<String> options;
  final String categoria;
  final String referencia;

  factory DuelQuestion.fromJson(Map<String, dynamic> json) => DuelQuestion(
        index: (json['index'] as num?)?.toInt() ?? 0,
        enunciado: json['enunciado'] as String? ?? '',
        options: (json['opciones'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        categoria: json['categoria'] as String? ?? '',
        referencia: json['referencia'] as String? ?? '',
      );
}

class DuelState {
  const DuelState({
    this.phase = DuelPhase.lobby,
    this.code,
    this.isHost = false,
    this.error,
    this.questions = const [],
    this.current = 0,
    this.myAnswered = 0,
    this.opponentAnswered = 0,
    this.correct = 0,
    this.opponentCorrect = 0,
    this.finished = false,
    this.iWon = false,
    this.draw = false,
    this.opponentName = '',
    this.meAnswered = false,
    this.waitingForOpponent = false,
  });

  final DuelPhase phase;
  final String? code;
  final bool isHost;
  final String? error;
  final List<DuelQuestion> questions;
  final int current;
  final int myAnswered;
  final int opponentAnswered;
  final int correct;
  final int opponentCorrect;
  final bool finished;
  final bool iWon;
  final bool draw;
  final String opponentName;
  final bool meAnswered;
  final bool waitingForOpponent;

  double get myProgress =>
      questions.isEmpty ? 0 : myAnswered / questions.length;

  double get opponentProgress =>
      questions.isEmpty ? 0 : opponentAnswered / questions.length;

  DuelState copyWith({
    DuelPhase? phase,
    String? code,
    bool? isHost,
    String? error,
    List<DuelQuestion>? questions,
    int? current,
    int? myAnswered,
    int? opponentAnswered,
    int? correct,
    int? opponentCorrect,
    bool? finished,
    bool? iWon,
    bool? draw,
    String? opponentName,
    bool? meAnswered,
    bool? waitingForOpponent,
    bool clearError = false,
  }) {
    return DuelState(
      phase: phase ?? this.phase,
      code: code ?? this.code,
      isHost: isHost ?? this.isHost,
      error: clearError ? null : (error ?? this.error),
      questions: questions ?? this.questions,
      current: current ?? this.current,
      myAnswered: myAnswered ?? this.myAnswered,
      opponentAnswered: opponentAnswered ?? this.opponentAnswered,
      correct: correct ?? this.correct,
      opponentCorrect: opponentCorrect ?? this.opponentCorrect,
      finished: finished ?? this.finished,
      iWon: iWon ?? this.iWon,
      draw: draw ?? this.draw,
      opponentName: opponentName ?? this.opponentName,
      meAnswered: meAnswered ?? this.meAnswered,
      waitingForOpponent: waitingForOpponent ?? this.waitingForOpponent,
    );
  }
}

final duelProvider = AsyncNotifierProvider<DuelNotifier, DuelState>(
  DuelNotifier.new,
);

class DuelNotifier extends AsyncNotifier<DuelState> {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final Stopwatch _questionClock = Stopwatch();
  bool _handshakeDone = false;
  Map<String, dynamic>? _pending;

  @override
  Future<DuelState> build() async {
    ref.onDispose(_teardown);
    return const DuelState();
  }

  DuelState get _s => state.valueOrNull ?? const DuelState();

  void _emit(DuelState next) => state = AsyncData(next);

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _questionClock.stop();
  }

  void _connect() {
    final token = ref.read(sessionStoreProvider).valueOrNull?.token;
    if (token == null) {
      _emit(_s.copyWith(
        phase: DuelPhase.error,
        error: 'No hay sesión todavía. Reintenta en unos segundos.',
      ));
      return;
    }

    final wsBase = AppConfig.apiBaseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    final channel = WebSocketChannel.connect(Uri.parse('$wsBase/ws?token=$token'));
    _channel = channel;
    _handshakeDone = false;
    _pending = null;

    _sub = channel.stream.listen(
      (raw) {
        final msg = _decode(raw);
        if (msg != null) _handle(msg);
      },
      onError: (_) {
        if (_s.phase == DuelPhase.waiting || _s.phase == DuelPhase.playing) {
          _emit(_s.copyWith(
            phase: DuelPhase.error,
            error: 'Se perdió la conexión con el duelo.',
          ));
        }
      },
      onDone: () {
        if (_s.phase == DuelPhase.waiting || _s.phase == DuelPhase.playing) {
          _emit(_s.copyWith(
            phase: DuelPhase.error,
            error: 'El duelo se interrumpió.',
          ));
        }
      },
      cancelOnError: true,
    );
  }

  Map<String, dynamic>? _decode(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // mensaje no parseable: se ignora
    }
    return null;
  }

  void _handle(Map<String, dynamic> msg) {
    switch (msg['type'] as String?) {
      case 'hello':
        // El servidor ya cargó al jugador: ahora sí se puede jugar.
        _handshakeDone = true;
        final pending = _pending;
        _pending = null;
        if (pending != null) _send(pending);

      case 'created':
        _emit(_s.copyWith(
          phase: DuelPhase.waiting,
          code: msg['code'] as String?,
          isHost: true,
          clearError: true,
        ));

      case 'room':
        final room = msg['room'] as Map<String, dynamic>?;
        final players = (room?['players'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final me = _myPlayerId;
        final rival = players.where((p) => p['playerId'] != me);
        final rivalName = rival.isEmpty
            ? ''
            : (rival.first['displayName'] as String? ?? '');
        _emit(_s.copyWith(opponentName: rivalName));

      case 'start':
        final questions = (msg['questions'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DuelQuestion.fromJson)
            .toList();
        _questionClock
          ..reset()
          ..start();
        _emit(_s.copyWith(
          phase: DuelPhase.playing,
          questions: questions,
          current: 0,
          myAnswered: 0,
          opponentAnswered: 0,
          correct: 0,
          opponentCorrect: 0,
          meAnswered: false,
          finished: false,
          clearError: true,
        ));

      case 'answerAck':
        final correct = msg['correct'] == true;
        final nextIndex = _s.current + 1;
        final iDone = nextIndex >= _s.questions.length;
        _questionClock
          ..reset()
          ..start();
        _emit(_s.copyWith(
          myAnswered: _s.myAnswered + 1,
          correct: _s.correct + (correct ? 1 : 0),
          current: iDone ? _s.current : nextIndex,
          meAnswered: false,
          waitingForOpponent: iDone,
          finished: iDone && _s.opponentAnswered >= _s.questions.length,
        ));

      case 'opponentAnswer':
        final next = _s.opponentAnswered + 1;
        final rivalDone = next >= _s.questions.length;
        _emit(_s.copyWith(
          opponentAnswered: next,
          waitingForOpponent: rivalDone && _s.myAnswered >= _s.questions.length,
          finished: rivalDone && _s.myAnswered >= _s.questions.length,
        ));

      case 'result':
        final result = msg['result'] as Map<String, dynamic>?;
        final winnerId = result?['winnerId'] as String?;
        final players = (result?['players'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final me = players.where((p) => p['playerId'] == _myPlayerId);
        final rival = players.where((p) => p['playerId'] != _myPlayerId);
        final myCorrect =
            me.isEmpty ? 0 : ((me.first['correct'] as num?)?.toInt() ?? 0);
        final rivalCorrect =
            rival.isEmpty ? 0 : ((rival.first['correct'] as num?)?.toInt() ?? 0);
        final rivalName = rival.isEmpty
            ? _s.opponentName
            : (rival.first['displayName'] as String? ?? _s.opponentName);

        _emit(_s.copyWith(
          phase: DuelPhase.result,
          finished: true,
          correct: myCorrect,
          opponentCorrect: rivalCorrect,
          opponentName: rivalName,
          iWon: winnerId != null && winnerId == _myPlayerId,
          draw: winnerId == null,
        ));

      case 'opponentLeft':
        _emit(_s.copyWith(
          phase: DuelPhase.error,
          error:
              '${_s.opponentName.isEmpty ? 'Tu rival' : _s.opponentName} abandonó el duelo.',
        ));

      case 'error':
        _emit(_s.copyWith(
          error: msg['message'] as String? ?? 'Error',
          clearError: false,
        ));
    }
  }

  String? get _myPlayerId =>
      ref.read(sessionStoreProvider).valueOrNull?.cachedPlayer?.id;

  void _send(Map<String, dynamic> msg) {
    if (_channel == null) return;
    if (!_handshakeDone) {
      _pending = msg;
      return;
    }
    _channel!.sink.add(jsonEncode(msg));
  }

  Future<void> createRoom() async {
    _teardown();
    _emit(const DuelState(phase: DuelPhase.waiting, isHost: true));
    _connect();
    _send({'type': 'create'});
  }

  Future<void> joinRoom(String code) async {
    _teardown();
    _emit(DuelState(phase: DuelPhase.waiting, code: code));
    _connect();
    _send({'type': 'join', 'code': code});
  }

  void ready() => _send({'type': 'ready'});

  void answer(int option) {
    final s = _s;
    if (s.phase != DuelPhase.playing || s.meAnswered) return;
    _send({
      'type': 'answer',
      'index': s.current,
      'option': option,
      'elapsedMs': _questionClock.elapsedMilliseconds,
    });
    _emit(s.copyWith(meAnswered: true));
  }

  void leave() {
    _send({'type': 'leave'});
    _teardown();
    _emit(const DuelState());
  }

  void backToLobby() {
    _teardown();
    _emit(const DuelState());
  }
}
