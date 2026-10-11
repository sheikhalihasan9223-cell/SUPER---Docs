import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A paint-only animation, isolated from the interactive app's repaints.
class GalaxyBackground extends StatefulWidget {
  const GalaxyBackground({super.key});
  @override
  State<GalaxyBackground> createState() => _GalaxyBackgroundState();
}

class _GalaxyBackgroundState extends State<GalaxyBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );
  bool resumed = true;
  bool animate = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void updateMotion() {
    if (animate && resumed) {
      if (!motion.isAnimating) motion.repeat();
    } else {
      motion.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    animate =
        !MediaQuery.disableAnimationsOf(context) && TickerMode.valuesOf(context).enabled;
    updateMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    updateMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(painter: _StarPainter(motion), size: Size.infinite),
      ),
    ),
  );
}

class _StarPainter extends CustomPainter {
  final Animation<double> motion;
  _StarPainter(this.motion) : super(repaint: motion);
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(42);
    final paint = Paint();
    // Three depth layers travel one, two, or three screen lengths per loop.
    for (var i = 0; i < 85; i++) {
      final x = random.nextDouble() * size.width;
      final start = random.nextDouble();
      final layer = 1 + i % 3;
      final radius = .5 + random.nextDouble() * 1.2;
      final opacity = .22 + random.nextDouble() * .48;
      final y = ((start + motion.value * layer) % 1) * (size.height + 8) - 4;
      final position = Offset(x, y);
      final color = i % 4 == 0
          ? const Color(0xFFBCA7FF)
          : const Color(0xFFE1F4FF);
      if (i % 9 == 0) {
        paint.color = color.withValues(alpha: opacity * .12);
        canvas.drawCircle(position, radius * 3, paint);
      }
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(position, radius, paint);
      if (i % 17 == 0) {
        paint.strokeWidth = .6;
        canvas.drawLine(
          position - Offset(radius * 2, 0),
          position + Offset(radius * 2, 0),
          paint,
        );
        canvas.drawLine(
          position - Offset(0, radius * 2),
          position + Offset(0, radius * 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.motion != motion;
}

