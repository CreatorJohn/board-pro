import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/board_objects.dart';
import '../providers/whiteboard_provider.dart';
import '../providers/tool_provider.dart';
import 'object_wrapper.dart';
import 'drawing_painter.dart';

class WhiteboardCanvas extends ConsumerStatefulWidget {
  const WhiteboardCanvas({super.key});

  @override
  ConsumerState<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends ConsumerState<WhiteboardCanvas> {
  List<Offset> _currentPoints = [];
  String? _currentDrawingId;

  void _onPanStart(DragStartDetails details, ToolState tool) {
    if (tool.toolType == ToolType.draw) {
      setState(() {
        _currentPoints = [details.localPosition];
        _currentDrawingId = const Uuid().v4();
      });
    } else if (tool.toolType == ToolType.select) {
      ref.read(whiteboardProvider.notifier).selectObject(null);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, ToolState tool) {
    if (tool.toolType == ToolType.draw) {
      setState(() {
        _currentPoints = [..._currentPoints, details.localPosition];
      });
    }
  }

  void _onPanEnd(DragEndDetails details, ToolState tool) {
    if (tool.toolType == ToolType.draw && _currentPoints.isNotEmpty) {
      // Calculate bounding box for the drawing
      double minX = _currentPoints.first.dx;
      double maxX = _currentPoints.first.dx;
      double minY = _currentPoints.first.dy;
      double maxY = _currentPoints.first.dy;

      for (var p in _currentPoints) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }

      // Normalize points relative to top-left
      final normalizedPoints = _currentPoints
          .map((p) => Offset(p.dx - minX, p.dy - minY))
          .toList();

      final drawing = DrawingObject(
        id: _currentDrawingId!,
        x: minX,
        y: minY,
        width: (maxX - minX).clamp(1.0, 5000.0),
        height: (maxY - minY).clamp(1.0, 5000.0),
        zIndex: ref.read(whiteboardProvider).whiteboard.objects.length,
        points: normalizedPoints,
        color: tool.color.toARGB32(),
        strokeWidth: tool.strokeWidth,
      );

      ref.read(whiteboardProvider.notifier).addObject(drawing);

      setState(() {
        _currentPoints = [];
        _currentDrawingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final whiteboardState = ref.watch(whiteboardProvider);
    final toolState = ref.watch(toolProvider);
    final transformationController = ref.watch(transformationControllerProvider);

    return InteractiveViewer(
      transformationController: transformationController,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 5.0,
      child: GestureDetector(
        onPanStart: (details) => _onPanStart(details, toolState),
        onPanUpdate: (details) => _onPanUpdate(details, toolState),
        onPanEnd: (details) => _onPanEnd(details, toolState),
        child: Container(
          color: Colors.white,
          width: 10000, // Large size for "infinite" feel
          height: 10000,
          child: Stack(
            children: [
              // Render saved objects
              ...whiteboardState.whiteboard.objects.map((obj) {
                return ObjectWrapper(
                  key: ValueKey(obj.id),
                  object: obj,
                  child: _buildObjectContent(obj),
                );
              }),
              // Render current drawing
              if (_currentPoints.isNotEmpty)
                CustomPaint(
                  painter: _TempDrawingPainter(
                    _currentPoints,
                    toolState.color,
                    toolState.strokeWidth,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObjectContent(BoardObject obj) {
    if (obj is DrawingObject) {
      return CustomPaint(
        size: Size(obj.width, obj.height),
        painter: DrawingPainter(obj),
      );
    } else if (obj is TextObject) {
      return Center(
        child: Text(
          obj.text,
          style: TextStyle(
            color: Color(obj.color),
            fontSize: obj.fontSize,
          ),
        ),
      );
    } else if (obj is ImageObject) {
      return Image.file(
        File(obj.imagePath),
        width: obj.width,
        height: obj.height,
        fit: BoxFit.fill,
      );
    }
    return const SizedBox.shrink();
  }
}

class _TempDrawingPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  _TempDrawingPainter(this.points, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
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

  @override
  bool shouldRepaint(covariant _TempDrawingPainter oldDelegate) => true;
}
