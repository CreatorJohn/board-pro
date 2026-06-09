import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/board_objects.dart';

class GlobalBoardPainter extends CustomPainter {
  final List<({Offset origin, BoardObject obj})> sortedObjects;

  GlobalBoardPainter({
    required this.sortedObjects,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in sortedObjects) {
      final obj = item.obj;
      final cellOrigin = item.origin;

      canvas.save();
      canvas.translate(cellOrigin.dx + obj.x, cellOrigin.dy + obj.y);
      
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
    } else if (obj is ShapeObject) {
      final paint = Paint()
        ..color = Color(obj.color)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      if (obj.shapeType == ShapeType.rectangle) {
        canvas.drawRect(Rect.fromLTWH(0, 0, obj.width, obj.height), paint);
      } else if (obj.shapeType == ShapeType.circle) {
        canvas.drawOval(Rect.fromLTWH(0, 0, obj.width, obj.height), paint);
      } else if (obj.shapeType == ShapeType.stickyNote) {
        final bgPaint = Paint()..color = Color(obj.color)..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(0, 0, obj.width, obj.height), bgPaint);
        
        if (obj.text != null && obj.text!.isNotEmpty) {
           _drawText(canvas, obj.text!, Colors.black, 16, obj.width, obj.height);
        }
      }
    } else if (obj is TextObject) {
      _drawText(canvas, obj.text, Color(obj.color), obj.fontSize, obj.width, obj.height);
    } else if (obj is ImageObject) {
      // For images, since CustomPainter is synchronous, drawing native images requires pre-loading.
      // As a fallback for 100% canvas rendering without complex async caching, we draw a placeholder box.
      final bgPaint = Paint()..color = Colors.grey.shade300..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, obj.width, obj.height), bgPaint);
      final borderPaint = Paint()..color = Colors.grey..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawRect(Rect.fromLTWH(0, 0, obj.width, obj.height), borderPaint);
      
      String label = kIsWeb ? 'Image (Not supported on Web)' : 'Image: ${obj.imagePath.split('/').last}';
      _drawText(canvas, label, Colors.black54, 12, obj.width, obj.height);
    }
  }

  void _drawText(Canvas canvas, String text, Color color, double fontSize, double width, double height) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.normal),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(minWidth: 0, maxWidth: width);
    // Center text vertically
    final offset = Offset(
      (width - textPainter.width) / 2,
      (height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant GlobalBoardPainter oldDelegate) {
    return oldDelegate.sortedObjects != sortedObjects;
  }
}
