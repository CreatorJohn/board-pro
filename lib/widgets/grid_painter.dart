import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final double cellSize;
  final Rect viewport;

  GridPainter({required this.cellSize, required this.viewport});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    // Calculate the start and end points based on the viewport
    final double startX = (viewport.left / cellSize).floor() * cellSize;
    final double endX = (viewport.right / cellSize).ceil() * cellSize;
    final double startY = (viewport.top / cellSize).floor() * cellSize;
    final double endY = (viewport.bottom / cellSize).ceil() * cellSize;

    // Only draw dots within the visible area
    for (double x = startX; x <= endX; x += cellSize) {
      for (double y = startY; y <= endY; y += cellSize) {
        canvas.drawCircle(Offset(x, y), 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize || oldDelegate.viewport != viewport;
  }
}
