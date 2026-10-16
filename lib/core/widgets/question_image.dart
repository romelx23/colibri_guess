import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Figura de una pregunta (fórmula, gráfico, opción con imagen).
///
/// Se usa en examen, práctica, resultados y feedback. Si el asset no existe
/// (p. ej. pregunta con imagen pero sin el archivo empaquetado), no pinta nada
/// en vez de lanzar un error en runtime.
class QuestionImage extends StatelessWidget {
  const QuestionImage({
    super.key,
    required this.asset,
    this.height = 180,
  });

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: height),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Image.asset(
        asset,
        height: height - 20,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}
