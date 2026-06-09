import 'dart:ui';
import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final double cellSize;
  final Rect viewport;

  GridPainter({required this.cellSize, required this.viewport});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final List<Offset> points = [];

    // Calculate the start and end points based on the viewport
    final double startX = (viewport.left / cellSize).floor() * cellSize;
    final double endX = (viewport.right / cellSize).ceil() * cellSize;
    final double startY = (viewport.top / cellSize).floor() * cellSize;
    final double endY = (viewport.bottom / cellSize).ceil() * cellSize;

    for (double x = startX; x <= endX; x += cellSize) {
      for (double y = startY; y <= endY; y += cellSize) {
        points.add(Offset(x, y));
      }
    }

    if (points.isNotEmpty) {
      canvas.drawPoints(PointMode.points, points, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize || oldDelegate.viewport != viewport;
  }
}
