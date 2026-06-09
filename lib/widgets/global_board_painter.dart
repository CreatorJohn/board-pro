import 'package:flutter/material.dart';
import '../models/board_objects.dart';

class GlobalBoardPainter extends CustomPainter {
  final Map<String, List<BoardObject>> cells;
  final Set<String> selectedIds;
  final double cellSize;

  GlobalBoardPainter({
    required this.cells,
    required this.selectedIds,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Gather all objects from all cells to ensure stable global sorting
    final List<({Offset origin, BoardObject obj})> allObjects = [];
    
    for (final entry in cells.entries) {
      final coords = entry.key.split(' ');
      if (coords.length != 2) continue;
      final cx = int.tryParse(coords[0]);
      final cy = int.tryParse(coords[1]);
      if (cx == null || cy == null) continue;
      
      final cellOrigin = Offset(cx * cellSize, cy * cellSize);
      for (final obj in entry.value) {
        if (selectedIds.contains(obj.id)) continue;
        if (!(obj is DrawingObject || obj is LineObject)) continue;
        allObjects.add((origin: cellOrigin, obj: obj));
      }
    }

    // Sort by createdAt (back to front)
    allObjects.sort((a, b) => a.obj.createdAt.compareTo(b.obj.createdAt));

    for (final item in allObjects) {
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
    }
  }

  @override
  bool shouldRepaint(covariant GlobalBoardPainter oldDelegate) {
    return oldDelegate.cells != cells || oldDelegate.selectedIds != selectedIds;
  }
}
