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

/// Participante de la sala (hasta 8). En juego solo se conoce el avance de
/// cada quien; los aciertos definitivos llegan con el resultado.
class DuelPlayer {
  const DuelPlayer({
    required this.playerId,
    required this.displayName,
    this.avatarSeed = 0,
    this.ready = false,
    this.connected = true,
    this.answered = 0,
    this.correct = 0,
    this.position,
    this.isMe = false,
  });

  final String playerId;
  final String displayName;
  final int avatarSeed;
  final bool ready;
  final bool connected;
  final int answered;
  final int correct;
  final int? position;
  final bool isMe;

  factory DuelPlayer.fromJson(Map<String, dynamic> json, {bool isMe = false}) =>
      DuelPlayer(
        playerId: json['playerId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        avatarSeed: (json['avatarSeed'] as num?)?.toInt() ?? 0,
        ready: json['ready'] == true,
        connected: json['connected'] != false,
        answered: (json['answered'] as num?)?.toInt() ?? 0,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        position: (json['position'] as num?)?.toInt(),
        isMe: isMe,
      );

  DuelPlayer copyWith({
    String? displayName,
    int? avatarSeed,
    bool? ready,
    bool? connected,
    int? answered,
    int? correct,
    int? position,
    bool? isMe,
  }) {
    return DuelPlayer(
      playerId: playerId,
      displayName: displayName ?? this.displayName,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      ready: ready ?? this.ready,
      connected: connected ?? this.connected,
      answered: answered ?? this.answered,
      correct: correct ?? this.correct,
      position: position ?? this.position,
      isMe: isMe ?? this.isMe,
    );
  }
}

class DuelState {
  const DuelState({
    this.phase = DuelPhase.lobby,
    this.code,
    this.isHost = false,
    this.error,
    this.questions = const [],
    this.current = 0,
    this.iWon = false,
    this.draw = false,
    this.meAnswered = false,
    this.players = const [],
    this.maxPlayers = 8,
  });

  final DuelPhase phase;
  final String? code;
  final bool isHost;
  final String? error;
  final List<DuelQuestion> questions;
  final int current;
  final bool iWon;
  final bool draw;

  /// ¿Ya envié la respuesta de la pregunta actual?
  final bool meAnswered;

  final List<DuelPlayer> players;
  final int maxPlayers;

  DuelPlayer? get me {
    for (final p in players) {
      if (p.isMe) return p;
    }
    return null;
  }

  DuelPlayer? get rival {
    for (final p in players) {
      if (!p.isMe && p.connected) return p;
    }
    return null;
  }

  int get myAnswered => me?.answered ?? 0;
  int get correct => me?.correct ?? 0;
  int get questionCount => questions.length;

  double get myProgress =>
      questions.isEmpty ? 0 : myAnswered / questions.length;

  bool get allAnswered =>
      questions.isNotEmpty &&
      players.isNotEmpty &&
      players.every((p) => p.answered >= questions.length);

  /// Terminé yo y ya no falta nadie.
  bool get finished => phase == DuelPhase.result || allAnswered;

  /// Terminé pero quedan jugadores por acabar.
  bool get waitingForOpponent =>
      questions.isNotEmpty && myAnswered >= questions.length && !finished;

  int get finishedCount => players
      .where((p) => questions.isNotEmpty && p.answered >= questions.length)
      .length;

  int get readyCount => players.where((p) => p.ready).length;

  /// Participantes ordenados por puesto (solo tras el resultado).
  List<DuelPlayer> get ranked {
    final list = List<DuelPlayer>.from(players);
    list.sort((a, b) => (a.position ?? 99) - (b.position ?? 99));
    return list;
  }

  DuelState copyWith({
    DuelPhase? phase,
    String? code,
    bool? isHost,
    String? error,
    List<DuelQuestion>? questions,
    int? current,
    bool? iWon,
    bool? draw,
    bool? meAnswered,
    List<DuelPlayer>? players,
    int? maxPlayers,
    bool clearError = false,
  }) {
    return DuelState(
      phase: phase ?? this.phase,
      code: code ?? this.code,
      isHost: isHost ?? this.isHost,
      error: clearError ? null : (error ?? this.error),
      questions: questions ?? this.questions,
      current: current ?? this.current,
      iWon: iWon ?? this.iWon,
      draw: draw ?? this.draw,
      meAnswered: meAnswered ?? this.meAnswered,
      players: players ?? this.players,
      maxPlayers: maxPlayers ?? this.maxPlayers,
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
  String? _myId;

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
    _myId = null;
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

    final wsBase = AppConfig.wsBase;
    final channel = WebSocketChannel.connect(Uri.parse('$wsBase/ws?token=$token'));
    _channel = channel;
    _handshakeDone = false;
    _pending = null;
    _myId = null;

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
        _myId = (msg['player'] as Map<String, dynamic>?)?['playerId'] as String?;
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
        final roster = (room?['players'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final previous = {for (final p in _s.players) p.playerId: p};
        final merged = roster.map((json) {
          final id = json['playerId'] as String? ?? '';
          final old = previous[id];
          return DuelPlayer.fromJson(json, isMe: _isMe(id)).copyWith(
            answered: old?.answered ?? 0,
            correct: old?.correct ?? 0,
            position: old?.position,
          );
        }).toList();

        _emit(_s.copyWith(
          players: merged,
          code: room?['code'] as String? ?? _s.code,
          maxPlayers: (room?['maxPlayers'] as num?)?.toInt() ?? _s.maxPlayers,
        ));

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
          meAnswered: false,
          players: _s.players
              .map((p) => p.copyWith(answered: 0, correct: 0, position: null))
              .toList(),
          clearError: true,
        ));

      case 'answerAck':
        final isRight = msg['correct'] == true;
        final nextIndex = _s.current + 1;
        final iDone = nextIndex >= _s.questions.length;
        _questionClock
          ..reset()
          ..start();
        _emit(_s.copyWith(
          players: _updateMe(
            answered: _s.myAnswered + 1,
            correct: _s.correct + (isRight ? 1 : 0),
          ),
          current: iDone ? _s.current : nextIndex,
          meAnswered: false,
        ));

      case 'peerProgress':
        final id = msg['playerId'] as String? ?? '';
        if (id.isEmpty) break;
        _emit(_s.copyWith(
          players: _update(id, (p) => p.copyWith(
                answered: (msg['answered'] as num?)?.toInt() ?? p.answered,
                correct: (msg['correct'] as num?)?.toInt() ?? p.correct,
              )),
        ));

      case 'result':
        final result = msg['result'] as Map<String, dynamic>?;
        final winnerId = result?['winnerId'] as String?;
        final rows = (result?['players'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _emit(_s.copyWith(
          phase: DuelPhase.result,
          players: rows
              .map((json) => DuelPlayer.fromJson(
                    json,
                    isMe: _isMe(json['playerId'] as String? ?? ''),
                  ))
              .toList(),
          iWon: winnerId != null && winnerId == _myPlayerId,
          draw: winnerId == null,
        ));

      case 'playerLeft':
        final id = msg['playerId'] as String? ?? '';
        if (id.isEmpty) break;
        _emit(_s.copyWith(
          players: _s.players.where((p) => p.playerId != id).toList(),
        ));

      case 'excluded':
        _emit(_s.copyWith(
          phase: DuelPhase.error,
          error: msg['message'] as String? ?? 'La partida empezó sin ti.',
          players: const [],
          questions: const [],
        ));

      case 'opponentLeft':
        // Compatibilidad con servidores antiguos.
        _emit(_s.copyWith(
          phase: DuelPhase.error,
          error: 'Un jugador abandonó el duelo.',
        ));

      case 'error':
        _emit(_s.copyWith(
          error: msg['message'] as String? ?? 'Error',
          clearError: false,
        ));
    }
  }

  bool _isMe(String playerId) => playerId.isNotEmpty && playerId == _myPlayerId;

  String? get _myPlayerId =>
      _myId ?? ref.read(sessionStoreProvider).valueOrNull?.cachedPlayer?.id;

  List<DuelPlayer> _update(String playerId, DuelPlayer Function(DuelPlayer) fn) {
    return _s.players
        .map((p) => p.playerId == playerId ? fn(p) : p)
        .toList(growable: false);
  }

  List<DuelPlayer> _updateMe({required int answered, required int correct}) {
    final id = _myPlayerId;
    if (id == null) return _s.players;
    return _update(id, (p) => p.copyWith(answered: answered, correct: correct));
  }

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

  void startNow() => _send({'type': 'startNow'});

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
