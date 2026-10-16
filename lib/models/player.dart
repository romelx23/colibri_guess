class Player {
  const Player({
    required this.id,
    required this.deviceId,
    required this.displayName,
    required this.avatarSeed,
    required this.avatarId,
    required this.isGuest,
    required this.xp,
    required this.points,
    required this.examBest,
    required this.streak,
    required this.bestStreak,
    required this.sessions,
    this.email,
  });

  final String id;
  final String deviceId;
  final String displayName;
  final int avatarSeed;

  /// Id del icono de perfil elegido (catálogo [AvatarCatalog]).
  final String avatarId;
  final bool isGuest;
  final String? email;
  final int xp;
  final int points;

  /// Mejor puntaje de examen: la métrica del ranking global.
  final int examBest;
  final int streak;
  final int bestStreak;
  final int sessions;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        deviceId: json['deviceId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Jugador',
        avatarSeed: (json['avatarSeed'] as num?)?.toInt() ?? 0,
        avatarId: json['avatarId'] as String? ?? 'chick',
        isGuest: json['isGuest'] as bool? ?? true,
        email: json['email'] as String?,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        points: (json['points'] as num?)?.toInt() ?? 0,
        examBest: (json['examBest'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      );

  /// Copia solo con la identidad cambiada (para guardar offline sin red).
  Player withIdentity({String? displayName, String? avatarId}) => Player(
        id: id,
        deviceId: deviceId,
        displayName: displayName ?? this.displayName,
        avatarSeed: avatarSeed,
        avatarId: avatarId ?? this.avatarId,
        isGuest: isGuest,
        email: email,
        xp: xp,
        points: points,
        examBest: examBest,
        streak: streak,
        bestStreak: bestStreak,
        sessions: sessions,
      );

  /// Copia con el mejor puntaje de examen confirmado por el servidor.
  Player withExamBest(int value) => Player(
        id: id,
        deviceId: deviceId,
        displayName: displayName,
        avatarSeed: avatarSeed,
        avatarId: avatarId,
        isGuest: isGuest,
        email: email,
        xp: xp,
        points: points,
        examBest: value,
        streak: streak,
        bestStreak: bestStreak,
        sessions: sessions,
      );
}
