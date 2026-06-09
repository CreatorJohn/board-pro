import 'package:flutter/material.dart';
import '../models/board_objects.dart';

class CellPainter extends CustomPainter {
  final List<BoardObject> objects;

  CellPainter(this.objects);

  @override
  void paint(Canvas canvas, Size size) {
    for (final obj in objects) {
      canvas.save();
      canvas.translate(obj.x, obj.y);
      if (obj.rotation != 0) {
        canvas.translate(obj.width / 2, obj.height / 2);
        canvas.rotate(obj.rotation);
        canvas.translate(-obj.width / 2, -obj.height / 2);
      }
      
      _drawObject(canvas, obj);
      canvas.restore();
    }
  }

  void _drawObject(Canvas canvas, BoardObject obj) {
    if (obj is DrawingObject) {
      if (obj.points.isEmpty) return;
      final paint = Paint()
        ..color = Color(obj.color)
        ..strokeWidth = obj.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(obj.points.first.dx, obj.points.first.dy);
      for (int i = 1; i < obj.points.length; i++) {
        path.lineTo(obj.points[i].dx, obj.points[i].dy);
      }
      canvas.drawPath(path, paint);
    } else if (obj is LineObject) {
      final paint = Paint()
        ..color = Color(obj.color)
        ..strokeWidth = obj.strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(obj.start, obj.end, paint);
      
      if (obj.hasArrow) {
        final angle = (obj.end - obj.start).direction;
        const arrowSize = 15.0;
        canvas.save();
        canvas.translate(obj.end.dx, obj.end.dy);
        canvas.rotate(angle);
        final arrowPath = Path()
          ..moveTo(0, 0)
          ..lineTo(-arrowSize, -arrowSize / 2)
          ..lineTo(-arrowSize, arrowSize / 2)
          ..close();
        canvas.drawPath(arrowPath, Paint()..color = Color(obj.color));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CellPainter oldDelegate) => oldDelegate.objects != objects;
}
