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
    
    // Original bounding box from points
    double minX = drawing.points.first.dx;
    double maxX = drawing.points.first.dx;
    double minY = drawing.points.first.dy;
    double maxY = drawing.points.first.dy;

    for (var p in drawing.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final origW = maxX - minX;
    final origH = maxY - minY;
    
    // Scale factor to fit the current widget size
    final scaleX = origW > 0 ? size.width / origW : 1.0;
    final scaleY = origH > 0 ? size.height / origH : 1.0;

    path.moveTo(
      (drawing.points.first.dx - minX) * scaleX,
      (drawing.points.first.dy - minY) * scaleY,
    );

    for (int i = 1; i < drawing.points.length; i++) {
      path.lineTo(
        (drawing.points[i].dx - minX) * scaleX,
        (drawing.points[i].dy - minY) * scaleY,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.drawing != drawing;
  }
}
