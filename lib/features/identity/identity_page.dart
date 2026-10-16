import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/surface_card.dart';
import '../../logic/xp.dart';
import '../../models/avatar.dart';
import '../../models/player.dart';

/// Paso final del onboarding (o edición desde el perfil): nickname único
/// filtrado + selección de icono con tiers desbloqueables por rango de XP.
class IdentityPage extends ConsumerStatefulWidget {
  const IdentityPage({super.key, this.editing = false});

  /// true = se abrió desde el perfil (sin "Ahora no", vuelve al perfil).
  final bool editing;

  @override
  ConsumerState<IdentityPage> createState() => _IdentityPageState();
}

class _IdentityPageState extends ConsumerState<IdentityPage> {
  static final _allowedChars = RegExp(
    r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 ]',
  );
  static final _validName = RegExp(
    r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 ]+$',
  );

  final _nameCtrl = TextEditingController();
  String? _selectedAvatarId;
  String? _localError;
  String? _serverError;
  String? _suggestion;
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _seedFromPlayer(Player player) {
    if (_seeded) return;
    _seeded = true;
    _nameCtrl.text = player.displayName;
    _selectedAvatarId = player.avatarId;
  }

  String? _validateLocal(String name) {
    if (name.length < 2 || name.length > 24) {
      return 'Escribe un nombre de 2 a 24 caracteres';
    }
    if (!_validName.hasMatch(name)) {
      return 'Usa solo letras, números y espacios';
    }
    return null;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final avatarId = _selectedAvatarId ?? AvatarCatalog.defaultId;

    final localError = _validateLocal(name);
    if (localError != null) {
      setState(() {
        _localError = localError;
        _serverError = null;
        _suggestion = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _localError = null;
      _serverError = null;
      _suggestion = null;
    });

    final result = await ref
        .read(sessionProvider.notifier)
        .updateIdentity(displayName: name, avatarId: avatarId);

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result.status) {
      case IdentityStatus.success:
        _finish();
      case IdentityStatus.offline:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexión: tu identidad se guardará al reconectar.'),
          ),
        );
        _finish();
      case IdentityStatus.rejected:
        setState(() {
          _serverError = result.error ?? 'No se pudo guardar';
          _suggestion = result.suggestion;
        });
    }
  }

  void _finish() {
    if (widget.editing) {
      context.go('/profile');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final player = session.valueOrNull?.player;

    if (player != null) _seedFromPlayer(player);

    final xp = player?.xp ?? 0;
    final rank = Rank.of(xp);
    final selected = AvatarCatalog.byIdOrFallback(
      _selectedAvatarId ?? player?.avatarId,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: widget.editing
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: _saving ? null : _finish,
                          child: const Text('Ahora no'),
                        ),
                ),
                Text(
                  widget.editing ? 'Edita tu perfil' : 'Crea tu identidad',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.editing
                      ? 'Tu nickname e icono en Colibrí.'
                      : 'Elige cómo te verán en el ranking y los duelos.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 18),
                Center(
                  child: _AvatarPreview(
                    avatar: selected,
                    unlocked: AvatarCatalog.isUnlocked(selected, xp),
                    rankName: rank.name,
                    xp: xp,
                  )
                      .animate(key: ValueKey(selected.id))
                      .fadeIn(duration: 260.ms)
                      .scale(begin: const Offset(.92, .92)),
                ),
                const SizedBox(height: 20),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Nickname',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Text(
                            '${_nameCtrl.text.length}/24',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameCtrl,
                        enabled: !_saving,
                        maxLength: 24,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(_allowedChars),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Tu nickname',
                          errorText: _localError ?? _serverError,
                          suffixIcon: _suggestion == null
                              ? null
                              : IconButton(
                                  tooltip: 'Usar este nombre',
                                  icon: const Icon(Icons.auto_fix_high_rounded),
                                  onPressed: () => setState(() {
                                    _nameCtrl.text = _suggestion!;
                                    _suggestion = null;
                                    _serverError = null;
                                    _localError = null;
                                  }),
                                ),
                        ),
                        onChanged: (_) {
                          if (_localError != null || _serverError != null) {
                            setState(() {
                              _localError = null;
                              _serverError = null;
                              _suggestion = null;
                            });
                          }
                        },
                      ),
                      if (_suggestion != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'El nombre está en uso. ¿Te sirve '
                                '$_suggestion?',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.inkSoft),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _nameCtrl.text = _suggestion!;
                                _suggestion = null;
                                _serverError = null;
                              }),
                              child: const Text('Usar'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                for (final tier in AvatarTier.values) ...[
                  _TierSection(
                    tier: tier,
                    xp: xp,
                    selectedId: selected.id,
                    onSelect: (avatar) =>
                        setState(() => _selectedAvatarId = avatar.id),
                  ),
                  const SizedBox(height: 18),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.editing ? 'Guardar cambios' : 'Empezar',
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Tu nombre se revisa automáticamente: no se permiten '
                    'ofensas ni publicidad.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.inkFaint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({
    required this.avatar,
    required this.unlocked,
    required this.rankName,
    required this.xp,
  });

  final Avatar avatar;
  final bool unlocked;
  final String rankName;
  final int xp;

  Color get _ring => switch (avatar.tier) {
        AvatarTier.common => AppColors.primarySoft,
        AvatarTier.epic => const Color(0xFF8B5CF6),
        AvatarTier.legendary => const Color(0xFFFFC53D),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _ring, width: 3),
            boxShadow: [
              BoxShadow(
                color: _ring.withValues(alpha: unlocked ? .45 : .18),
                blurRadius: avatar.tier == AvatarTier.legendary ? 22 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Opacity(
            opacity: unlocked ? 1 : .45,
            child: Text(avatar.emoji, style: const TextStyle(fontSize: 42)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$rankName · $xp XP',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _TierSection extends StatelessWidget {
  const _TierSection({
    required this.tier,
    required this.xp,
    required this.selectedId,
    required this.onSelect,
  });

  final AvatarTier tier;
  final int xp;
  final String selectedId;
  final ValueChanged<Avatar> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatars = AvatarCatalog.ofTier(tier);
    final hint = switch (tier) {
      AvatarTier.common => 'Disponibles desde el inicio',
      AvatarTier.epic => 'Se desbloquean con 300 XP',
      AvatarTier.legendary => 'Se desbloquean con 2000+ XP',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              tier.label,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.inkFaint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final avatar in avatars)
              _AvatarTile(
                avatar: avatar,
                unlocked: AvatarCatalog.isUnlocked(avatar, xp),
                selected: avatar.id == selectedId,
                onTap: () {
                  if (AvatarCatalog.isUnlocked(avatar, xp)) {
                    onSelect(avatar);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Te faltan ${avatar.minXp - xp} XP para desbloquearlo.',
                        ),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.avatar,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final Avatar avatar;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final legendary = avatar.tier == AvatarTier.legendary && unlocked;
    final glow = legendary || (avatar.tier == AvatarTier.epic && unlocked);

    return Tooltip(
      message: unlocked
          ? avatar.tier.label
          : 'Se desbloquea con ${avatar.minXp} XP',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: unlocked
                ? (selected ? AppColors.primarySoft : Colors.white)
                : AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : legendary
                      ? const Color(0xFFFFC53D)
                      : AppColors.divider,
              width: selected ? 2.2 : 1.2,
            ),
            boxShadow: selected || glow
                ? [
                    BoxShadow(
                      color: (selected
                              ? AppColors.primary
                              : const Color(0xFFFFC53D))
                          .withValues(alpha: legendary ? .5 : .35),
                      blurRadius: legendary ? 14 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Opacity(
                  opacity: unlocked ? 1 : .4,
                  child: Text(
                    avatar.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              if (!unlocked)
                const Positioned(
                  right: 5,
                  bottom: 4,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: AppColors.inkFaint,
                  ),
                ),
              if (selected)
                const Positioned(
                  right: 4,
                  top: 4,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
