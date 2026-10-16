import 'package:flutter_test/flutter_test.dart';

import 'package:ingresa_ya/models/avatar.dart';

void main() {
  test('los ids del catálogo coinciden con los del backend', () {
    // Espejo de colibri-backend/src/config/avatars.js: si cambia allá,
    // este test obliga a sincronizar el catálogo de la app.
    const backendIds = [
      'chick', 'owl', 'brain', 'books', 'butterfly', 'parrot',
      'hibiscus', 'star', 'fox', 'eagle', 'wolf', 'dolphin', 'dragon',
      'phoenix', 'crown', 'trophy', 'unicorn', 'comet', 'diamond',
    ];
    expect(
      AvatarCatalog.all.map((a) => a.id).toList(),
      backendIds,
      reason: 'el catálogo Dart y el del servidor deben ser idénticos',
    );
  });

  test('desbloqueos por rango de XP', () {
    final chick = AvatarCatalog.byIdOrFallback('chick');
    final fox = AvatarCatalog.byIdOrFallback('fox');
    final crown = AvatarCatalog.byIdOrFallback('crown');
    final comet = AvatarCatalog.byIdOrFallback('comet');

    expect(AvatarCatalog.isUnlocked(chick, 0), isTrue);
    expect(AvatarCatalog.isUnlocked(fox, 0), isFalse);
    expect(AvatarCatalog.isUnlocked(fox, 299), isFalse);
    expect(AvatarCatalog.isUnlocked(fox, 300), isTrue);
    expect(AvatarCatalog.isUnlocked(crown, 1999), isFalse);
    expect(AvatarCatalog.isUnlocked(crown, 2000), isTrue);
    expect(AvatarCatalog.isUnlocked(comet, 4000), isTrue);
  });

  test('ids desconocidos caen al icono por defecto', () {
    expect(AvatarCatalog.byIdOrFallback(null).id, AvatarCatalog.defaultId);
    expect(AvatarCatalog.byIdOrFallback('no-existe').id, AvatarCatalog.defaultId);
    expect(AvatarCatalog.emojiFor('no-existe'), '🐣');
    expect(AvatarCatalog.emojiFor('crown'), '👑');
  });

  test('los tiers agrupan todo el catálogo sin huecos', () {
    final total = AvatarTier.values
        .map((t) => AvatarCatalog.ofTier(t).length)
        .fold(0, (sum, n) => sum + n);
    expect(total, AvatarCatalog.all.length);
    // cada tier tiene al menos un icono
    for (final tier in AvatarTier.values) {
      expect(AvatarCatalog.ofTier(tier), isNotEmpty, reason: tier.label);
    }
  });
}
