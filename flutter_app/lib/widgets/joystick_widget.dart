import 'dart:math' as math;
import 'package:flutter/material.dart';

class JoystickWidget extends StatefulWidget {
  final void Function(double dx, double dy) onMove;

  const JoystickWidget({super.key, required this.onMove});

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  double _knobX = 0;
  double _knobY = 0;
  bool _isDragging = false;
  static const double _radius = 80;

  void _handleMove(double dx, double dy) {
    final distance = math.sqrt(dx * dx + dy * dy);
    double clampedX = dx;
    double clampedY = dy;
    if (distance > _radius) {
      clampedX = dx / distance * _radius;
      clampedY = dy / distance * _radius;
    }
    setState(() {
      _knobX = clampedX;
      _knobY = clampedY;
    });
    final normX = (clampedX / _radius).clamp(-1.0, 1.0);
    final normY = (clampedY / _radius).clamp(-1.0, 1.0);
    widget.onMove(normX, normY);
  }

  void _reset() {
    setState(() {
      _knobX = 0;
      _knobY = 0;
      _isDragging = false;
    });
    widget.onMove(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanUpdate: (details) {
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final local = box.globalToLocal(details.globalPosition);
                      final center = box.size.width / 2;
                      _handleMove(local.dx - center, local.dy - center);
            },
            onPanEnd: (_) => _reset(),
            onPanCancel: _reset,
            child: CustomPaint(
              size: const Size(200, 200),
              painter: _JoystickPainter(
                knobDx: _knobX,
                knobDy: _knobY,
                isDragging: _isDragging,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final double knobDx;
  final double knobDy;
  final bool isDragging;

  _JoystickPainter({
    required this.knobDx,
    required this.knobDy,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    final bgPaint = Paint()
      ..color = const Color(0xFF1A1F35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 4, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    final crossPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crossPaint);

    final knobPos = Offset(center.dx + knobDx, center.dy + knobDy);
    final knobPaint = Paint()
      ..color = isDragging ? Colors.cyan : Colors.cyan.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobPos, 18, knobPaint);

    final knobBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(knobPos, 18, knobBorder);
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.knobDx != knobDx || old.knobDy != knobDy || old.isDragging != isDragging;
}
