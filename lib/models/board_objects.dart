import 'dart:ui';
import 'package:flutter/material.dart';

enum BoardObjectType { stroke, text, shape }

abstract class BoardObject {
  final String id;
  final int color;
  final double strokeWidth;
  final int createdAt;

  BoardObject({
    required this.id,
    required this.color,
    required this.strokeWidth,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  void draw(Canvas canvas);
}

class StrokeObject extends BoardObject {
  final List<Offset> points;

  StrokeObject({
    required super.id,
    required super.color,
    required super.strokeWidth,
    super.createdAt,
    required this.points,
  });

  @override
  void draw(Canvas canvas) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = Color(color)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }
}
