/// Iconos de perfil con tiers desbloqueables por rango de XP.
///
/// Debe mantenerse en sincronía con `colibri-backend/src/config/avatars.js`
/// (el servidor valida el desbloqueo con la misma tabla).
enum AvatarTier { common, epic, legendary }

extension AvatarTierX on AvatarTier {
  String get label => switch (this) {
        AvatarTier.common => 'Común',
        AvatarTier.epic => 'Épico',
        AvatarTier.legendary => 'Legendario',
      };
}

class Avatar {
  const Avatar({
    required this.id,
    required this.emoji,
    required this.tier,
    required this.minXp,
  });

  final String id;
  final String emoji;
  final AvatarTier tier;

  /// XP total mínimo para desbloquearlo.
  final int minXp;
}

class AvatarCatalog {
  AvatarCatalog._();

  static const String defaultId = 'chick';

  static const List<Avatar> all = [
    // Comunes: disponibles desde el inicio
    Avatar(id: 'chick', emoji: '🐣', tier: AvatarTier.common, minXp: 0),
    Avatar(id: 'owl', emoji: '🦉', tier: AvatarTier.common, minXp: 0),
    Avatar(id: 'brain', emoji: '🧠', tier: AvatarTier.common, minXp: 0),
    Avatar(id: 'books', emoji: '📚', tier: AvatarTier.common, minXp: 0),
    Avatar(id: 'butterfly', emoji: '🦋', tier: AvatarTier.common, minXp: 0),
    Avatar(id: 'parrot', emoji: '🦜', tier: AvatarTier.common, minXp: 0),
    Avatar(id: 'hibiscus', emoji: '🌺', tier: AvatarTier.common, minXp: 0),
    Avatar(id: 'star', emoji: '⭐', tier: AvatarTier.common, minXp: 0),
    // Épicos: rango Estudiante (300 XP)
    Avatar(id: 'fox', emoji: '🦊', tier: AvatarTier.epic, minXp: 300),
    Avatar(id: 'eagle', emoji: '🦅', tier: AvatarTier.epic, minXp: 300),
    Avatar(id: 'wolf', emoji: '🐺', tier: AvatarTier.epic, minXp: 300),
    Avatar(id: 'dolphin', emoji: '🐬', tier: AvatarTier.epic, minXp: 300),
    Avatar(id: 'dragon', emoji: '🐲', tier: AvatarTier.epic, minXp: 300),
    Avatar(id: 'phoenix', emoji: '🔥', tier: AvatarTier.epic, minXp: 300),
    // Legendarios: Erudito (2000 XP) y Maestro (4000 XP)
    Avatar(id: 'crown', emoji: '👑', tier: AvatarTier.legendary, minXp: 2000),
    Avatar(id: 'trophy', emoji: '🏆', tier: AvatarTier.legendary, minXp: 2000),
    Avatar(id: 'unicorn', emoji: '🦄', tier: AvatarTier.legendary, minXp: 2000),
    Avatar(id: 'comet', emoji: '☄️', tier: AvatarTier.legendary, minXp: 4000),
    Avatar(id: 'diamond', emoji: '💎', tier: AvatarTier.legendary, minXp: 4000),
  ];

  static Avatar byIdOrFallback(String? id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return all.first; // defaultId 'chick'
  }

  static String emojiFor(String? id) => byIdOrFallback(id).emoji;

  static bool isUnlocked(Avatar avatar, int xp) => xp >= avatar.minXp;

  static List<Avatar> ofTier(AvatarTier tier) =>
      all.where((a) => a.tier == tier).toList(growable: false);
}
