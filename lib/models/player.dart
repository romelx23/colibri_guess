class Player {
  const Player({
    required this.id,
    required this.deviceId,
    required this.displayName,
    required this.avatarSeed,
    required this.isGuest,
    required this.xp,
    required this.points,
    required this.streak,
    required this.bestStreak,
    required this.sessions,
    this.email,
  });

  final String id;
  final String deviceId;
  final String displayName;
  final int avatarSeed;
  final bool isGuest;
  final String? email;
  final int xp;
  final int points;
  final int streak;
  final int bestStreak;
  final int sessions;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        deviceId: json['deviceId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Jugador',
        avatarSeed: (json['avatarSeed'] as num?)?.toInt() ?? 0,
        isGuest: json['isGuest'] as bool? ?? true,
        email: json['email'] as String?,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        points: (json['points'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      );
}
