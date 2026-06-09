import 'package:flutter/material.dart';
import '../models/board_objects.dart';

class DrawingPainter extends CustomPainter {
  final DrawingObject drawing;

  DrawingPainter(this.drawing);

  @override
  void paint(Canvas canvas, Size size) {
    if (drawing.points.isEmpty) return;

    final paint = Paint()
      ..color = Color(drawing.color)
      ..strokeWidth = drawing.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Points are already normalized relative to (0,0) in _finishDrawing
    path.moveTo(drawing.points.first.dx, drawing.points.first.dy);

    for (int i = 1; i < drawing.points.length; i++) {
      path.lineTo(drawing.points[i].dx, drawing.points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.drawing != drawing;
  }
}
