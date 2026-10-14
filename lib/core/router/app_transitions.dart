import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tokens de motion de Colibrí. Unificar duraciones y curvas aquí evita que
/// cada pantalla invente su propia sensación de velocidad.
const kMotionFast = Duration(milliseconds: 180);
const kMotionBase = Duration(milliseconds: 280);
const kMotionSlow = Duration(milliseconds: 420);

const kMotionCurve = Curves.easeOutCubic;
const kMotionReverseCurve = Curves.easeInCubic;

/// Transición estándar de las rutas raíz (/quiz, /results, /duel):
/// fade + micro-slide vertical + escala sutil. En pop se invierte y es más
/// rápida, para que "volver atrás" se sienta inmediato.
CustomTransitionPage<T> fadeSlideRoute<T>({
  required LocalKey key,
  required Widget child,
  Duration duration = kMotionBase,
  Offset begin = const Offset(0, 0.05),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: kMotionFast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: kMotionCurve,
        reverseCurve: kMotionReverseCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
