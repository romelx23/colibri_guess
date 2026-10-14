import 'dart:math';

import 'package:flutter/material.dart';

enum ColibriMood { idle, happy, sad, thinking, celebrating }

class ColibriMascot extends StatefulWidget {
  const ColibriMascot({
    super.key,
    this.size = 140,
    this.mood = ColibriMood.idle,
  });

  final double size;
  final ColibriMood mood;

  @override
  State<ColibriMascot> createState() => _ColibriMascotState();
}

class _ColibriMascotState extends State<ColibriMascot>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  /// Interpola los parámetros de vuelo cuando cambia el mood, para que el
  /// colibrí no "salte" de una personalidad a otra.
  late final AnimationController _moodController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  ColibriMood _prevMood = ColibriMood.idle;

  /// Ángulos acumulados (envueltos a 2π) en vez de `t * ciclos`: cambiar el
  /// ritmo de aleteo ya no reinicia el ala en una posición arbitraria.
  double _phase = 0;
  double _flapPhase = 0;
  double _lastT = 0;

  @override
  void initState() {
    super.initState();
    _prevMood = widget.mood;
    _lastT = _controller.value;
  }

  @override
  void didUpdateWidget(ColibriMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _prevMood = oldWidget.mood;
      _moodController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _moodController.dispose();
    super.dispose();
  }

  void _advance(_MoodParams params) {
    final t = _controller.value;
    var dt = t - _lastT;
    if (dt < 0) dt += 1;
    _lastT = t;
    const tau = 2 * pi;
    _phase = (_phase + dt * tau) % tau;
    _flapPhase = (_flapPhase + dt * tau * params.cycles) % tau;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _moodController]),
      builder: (context, _) {
        final blend = Curves.easeInOutCubic.transform(_moodController.value);
        final params = _MoodParams.lerp(
          _MoodParams.of(_prevMood),
          _MoodParams.of(widget.mood),
          blend,
        );
        _advance(params);
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _ColibriPainter(
            phase: _phase,
            flapPhase: _flapPhase,
            params: params,
            moodFrom: _prevMood,
            moodTo: widget.mood,
            blend: blend,
          ),
        );
      },
    );
  }
}

/// Parámetros de vuelo por mood. Se interpolan entre el mood anterior y el
/// nuevo durante la transición.
class _MoodParams {
  const _MoodParams({
    required this.cycles,
    required this.flapMin,
    required this.flapMax,
    required this.bobAmp,
    required this.tiltBase,
    required this.tiltAmp,
    required this.tiltRate,
  });

  final double cycles;
  final double flapMin;
  final double flapMax;
  final double bobAmp;
  final double tiltBase;
  final double tiltAmp;
  final double tiltRate;

  static _MoodParams of(ColibriMood mood) => switch (mood) {
        ColibriMood.idle => const _MoodParams(
            cycles: 3,
            flapMin: -0.45,
            flapMax: 0.85,
            bobAmp: 2.2,
            tiltBase: 0,
            tiltAmp: 0.02,
            tiltRate: 1,
          ),
        ColibriMood.happy => const _MoodParams(
            cycles: 6,
            flapMin: -0.6,
            flapMax: 1.0,
            bobAmp: 4.5,
            tiltBase: -0.04,
            tiltAmp: 0.06,
            tiltRate: 2,
          ),
        ColibriMood.sad => const _MoodParams(
            cycles: 1.2,
            flapMin: -0.2,
            flapMax: 0.5,
            bobAmp: 1.2,
            tiltBase: 0.16,
            tiltAmp: 0,
            tiltRate: 1,
          ),
        ColibriMood.thinking => const _MoodParams(
            cycles: 1.8,
            flapMin: -0.35,
            flapMax: 0.7,
            bobAmp: 2.2,
            tiltBase: -0.1,
            tiltAmp: 0.015,
            tiltRate: 1,
          ),
        ColibriMood.celebrating => const _MoodParams(
            cycles: 7,
            flapMin: -0.65,
            flapMax: 1.05,
            bobAmp: 6,
            tiltBase: -0.06,
            tiltAmp: 0.08,
            tiltRate: 3,
          ),
      };

  static _MoodParams lerp(_MoodParams a, _MoodParams b, double t) =>
      _MoodParams(
        cycles: a.cycles + (b.cycles - a.cycles) * t,
        flapMin: a.flapMin + (b.flapMin - a.flapMin) * t,
        flapMax: a.flapMax + (b.flapMax - a.flapMax) * t,
        bobAmp: a.bobAmp + (b.bobAmp - a.bobAmp) * t,
        tiltBase: a.tiltBase + (b.tiltBase - a.tiltBase) * t,
        tiltAmp: a.tiltAmp + (b.tiltAmp - a.tiltAmp) * t,
        tiltRate: a.tiltRate + (b.tiltRate - a.tiltRate) * t,
      );
}

class _ColibriPainter extends CustomPainter {
  _ColibriPainter({
    required this.phase,
    required this.flapPhase,
    required this.params,
    required this.moodFrom,
    required this.moodTo,
    required this.blend,
  });

  final double phase;
  final double flapPhase;
  final _MoodParams params;
  final ColibriMood moodFrom;
  final ColibriMood moodTo;
  final double blend;

  static const _back = Color(0xFF1F9E63);
  static const _body = Color(0xFF35C77A);
  static const _belly = Color(0xFFF2FCF7);
  static const _tail = Color(0xFF178754);
  static const _gorget = Color(0xFFE93E9C);
  static const _beak = Color(0xFF2A2A35);
  static const _tear = Color(0xFF5BB8F5);

  /// Peso de cada mood en la mezcla actual (suman 1), para que las expresiones
  /// se fundan igual que los parámetros de vuelo.
  double weight(ColibriMood mood) {
    var w = 0.0;
    if (moodTo == mood) w += blend;
    if (moodFrom == mood) w += 1 - blend;
    return w;
  }

  Offset _pupilShift(ColibriMood mood) => switch (mood) {
        ColibriMood.idle => Offset.zero,
        ColibriMood.happy => const Offset(0.4, -0.4),
        ColibriMood.sad => const Offset(0, 1.1),
        ColibriMood.thinking => const Offset(1.5, -1.4),
        ColibriMood.celebrating => const Offset(0, -0.9),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.translate((size.width - 100 * scale) / 2,
        (size.height - 100 * scale) / 2);
    canvas.scale(scale);

    final wave = (sin(flapPhase) + 1) / 2;
    final flap = params.flapMin + (params.flapMax - params.flapMin) * wave;
    final bob = sin(phase) * params.bobAmp;
    final tilt =
        params.tiltBase + sin(phase * params.tiltRate) * params.tiltAmp;

    canvas.save();
    canvas.translate(50, 54 + bob);
    canvas.rotate(tilt);
    canvas.translate(-50, -54);

    _drawSparkles(canvas);
    _drawConfetti(canvas);
    _drawTail(canvas);
    _drawWing(canvas, flap + 0.28, isBack: true);
    _drawBody(canvas);
    _drawWing(canvas, flap, isBack: false);
    _drawHead(canvas);
    _drawFace(canvas);
    _drawThinkingDots(canvas);

    canvas.restore();
  }

  void _drawSparkles(Canvas canvas) {
    final w = weight(ColibriMood.happy) + weight(ColibriMood.celebrating);
    if (w < .01) return;
    final points = [
      const Offset(16, 22),
      const Offset(86, 14),
      const Offset(8, 60),
      const Offset(88, 74),
    ];
    for (var i = 0; i < points.length; i++) {
      final pulse = (sin(phase * 2 * 2 * pi + i) + 1) / 2;
      final r = 3.0 + pulse * 2.5;
      final paint = Paint()
        ..color = const Color(0xFFFFC94D)
            .withValues(alpha: (w * (.45 + pulse * .55)).clamp(0.0, 1.0));
      final path = Path()
        ..moveTo(points[i].dx, points[i].dy - r)
        ..quadraticBezierTo(points[i].dx, points[i].dy, points[i].dx + r,
            points[i].dy)
        ..quadraticBezierTo(points[i].dx, points[i].dy, points[i].dx,
            points[i].dy + r)
        ..quadraticBezierTo(points[i].dx, points[i].dy, points[i].dx - r,
            points[i].dy)
        ..quadraticBezierTo(points[i].dx, points[i].dy, points[i].dx,
            points[i].dy - r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawConfetti(Canvas canvas) {
    final w = weight(ColibriMood.celebrating);
    if (w < .01) return;
    const colors = [
      Color(0xFFFFC94D),
      Color(0xFFF0699A),
      Color(0xFF5BB8F5),
      Color(0xFF35C77A),
    ];
    for (var i = 0; i < 6; i++) {
      final a = phase * 1.5 + i * (2 * pi / 6);
      final r = 34.0 + sin(phase * 2 + i) * 4;
      final p = Offset(50 + cos(a) * r, 52 + sin(a) * r * .85);
      final alpha = (w * (.45 + .55 * sin(phase * 4 + i))).clamp(0.0, 1.0);
      canvas.drawCircle(
        p,
        2.4,
        Paint()..color = colors[i % colors.length].withValues(alpha: alpha),
      );
    }
  }

  void _drawThinkingDots(Canvas canvas) {
    final w = weight(ColibriMood.thinking);
    if (w < .01) return;
    final paint = Paint();
    for (var i = 0; i < 3; i++) {
      final pulse = (sin(phase * 3 - i * 0.9) + 1) / 2;
      paint.color = _beak.withValues(alpha: (w * (.2 + pulse * .65)).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(84 + i * 5.0, 20 - i * 3.5), 1.9, paint);
    }
  }

  void _drawTail(Canvas canvas) {
    final paint = Paint()..color = _tail;
    final path = Path()
      ..moveTo(34, 58)
      ..lineTo(6, 76)
      ..lineTo(16, 62)
      ..lineTo(2, 58)
      ..lineTo(30, 48)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawBody(Canvas canvas) {
    final body = Paint()..color = _body;
    canvas.save();
    canvas.translate(46, 56);
    canvas.rotate(-0.28);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 44, height: 31),
        body);
    canvas.restore();

    final belly = Paint()..color = _belly;
    canvas.save();
    canvas.translate(50, 61);
    canvas.rotate(-0.2);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 31, height: 19),
        belly);
    canvas.restore();

    _drawLegs(canvas);
  }

  void _drawLegs(Canvas canvas) {
    final paint = Paint()
      ..color = _beak
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(46, 70)
      ..lineTo(43, 78)
      ..moveTo(56, 69)
      ..lineTo(55, 78);
    canvas.drawPath(path, paint);
  }

  void _drawWing(Canvas canvas, double angle, {required bool isBack}) {
    canvas.save();
    canvas.translate(44, 46);
    canvas.rotate(angle);

    final paint = Paint()
      ..color = (isBack ? _back : const Color(0xFF2FB574))
          .withValues(alpha: isBack ? .55 : .95);

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-10, -34, -44, -46)
      ..quadraticBezierTo(-34, -20, -6, -1)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawHead(Canvas canvas) {
    final throat = Paint()..color = _gorget;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(63, 48), width: 17, height: 13),
      throat,
    );

    final head = Paint()..color = _body;
    canvas.drawCircle(const Offset(70, 38), 14, head);

    final crown = Paint()..color = _back;
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(70, 38), radius: 14),
      -pi * 0.95,
      pi * 0.75,
      true,
      crown,
    );

    final beak = Path()
      ..moveTo(81, 34)
      ..lineTo(99, 43)
      ..lineTo(81, 42)
      ..close();
    canvas.drawPath(beak, Paint()..color = _beak);

    canvas.drawCircle(const Offset(75, 33), 4.6, Paint()..color = Colors.white);
  }

  /// Ojo, párpado, sonrisa y lágrima: la cara cambia según el mood y se funde
  /// con el mismo `blend` que el vuelo.
  void _drawFace(Canvas canvas) {
    const eye = Offset(75, 33);

    var shift = Offset.zero;
    for (final mood in ColibriMood.values) {
      shift += _pupilShift(mood) * weight(mood);
    }
    final pupil = Offset(76, 33.4) + shift;
    canvas.drawCircle(pupil, 2.6, Paint()..color = _beak);
    canvas.drawCircle(
        pupil + const Offset(1, -1.2), 1, Paint()..color = Colors.white);

    final sadW = weight(ColibriMood.sad);
    if (sadW > .01) {
      // Párpado caído.
      final lid = Paint()
        ..color = _body.withValues(alpha: sadW)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      final lidPath = Path()
        ..moveTo(eye.dx - 4.4, eye.dy - 2)
        ..quadraticBezierTo(eye.dx, eye.dy + 1.6, eye.dx + 4.4, eye.dy - 2);
      canvas.drawPath(lidPath, lid);

      // Lágrima que cae en bucle.
      final fall = phase / (2 * pi);
      final y = eye.dy + 5 + fall * 15;
      final alpha = (sadW * (1 - fall)).clamp(0.0, 1.0);
      final tearPaint = Paint()..color = _tear.withValues(alpha: alpha);
      final tearPath = Path()
        ..moveTo(eye.dx + 3, y - 4.4)
        ..quadraticBezierTo(eye.dx + 5.4, y - 1, eye.dx + 3, y + 2.2)
        ..quadraticBezierTo(eye.dx + 0.6, y - 1, eye.dx + 3, y - 4.4)
        ..close();
      canvas.drawPath(tearPath, tearPaint);
    }

    final thinkW = weight(ColibriMood.thinking);
    if (thinkW > .01) {
      final brow = Paint()
        ..color = _beak.withValues(alpha: thinkW)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(70.5, 26.5), const Offset(79, 25), brow);
    }

    final smileW =
        weight(ColibriMood.happy) + weight(ColibriMood.celebrating);
    if (smileW > .01) {
      final smile = Paint()
        ..color = _beak.withValues(alpha: (smileW * .85).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        const Rect.fromLTRB(79.5, 42.5, 94.5, 51.5),
        0.2,
        pi - 0.4,
        false,
        smile,
      );
    }
  }

  @override
  bool shouldRepaint(_ColibriPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.flapPhase != flapPhase ||
      oldDelegate.blend != blend ||
      oldDelegate.moodFrom != moodFrom ||
      oldDelegate.moodTo != moodTo;
}
