import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/board_objects.dart';
import '../providers/whiteboard_provider.dart';
import '../providers/tool_provider.dart';
import '../providers/canvas_provider.dart';
import 'object_wrapper.dart';
import 'drawing_painter.dart';
import 'grid_painter.dart';
import 'cell_painter.dart';

class WhiteboardCanvas extends ConsumerStatefulWidget {
  const WhiteboardCanvas({super.key});

  @override
  ConsumerState<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends ConsumerState<WhiteboardCanvas> {
  List<Offset> _currentPoints = [];
  bool _isDrawing = false;
  bool _isLineDrawing = false;
  bool _isStylusActive = false;
  bool _isActionInProgress = false;
  bool _isManualPanning = false;
  bool _isSelecting = false;
  Offset? _globalCursorPos; 
  Offset _panStartPos = Offset.zero;
  Offset? _selectionStart;
  Offset? _selectionEnd;
  Offset? _lineStart;
  Offset? _lineEnd;

  // Reduced virtual size to avoid GTK surface limits (100k -> 5k)
  static const double virtualSize = 5000;
  static const Offset initialOffset = Offset(virtualSize / 2, virtualSize / 2);
  static const double cellSize = 1000.0;
  static const double panThreshold = 5.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transformationControllerProvider).value = Matrix4.translationValues(
        -initialOffset.dx,
        -initialOffset.dy,
        0,
      );
    });
  }

  Offset _toGlobal(Offset local, Matrix4 transform) {
    final inv = Matrix4.inverted(transform);
    return MatrixUtils.transformPoint(inv, local);
  }

  String _getCellKey(Offset globalPos) {
    final cx = (globalPos.dx / cellSize).floor();
    final cy = (globalPos.dy / cellSize).floor();
    return "$cx $cy";
  }

  void _onPointerDown(PointerDownEvent event, ToolState tool) {
    final globalPos = event.localPosition;
    setState(() {
      _globalCursorPos = globalPos;
      if (event.kind == PointerDeviceKind.stylus) {
        _isStylusActive = true;
      }
    });

    final isStylus = event.kind == PointerDeviceKind.stylus;
    final isTouchOrMouse = event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.mouse;

    if (tool.toolType == ToolType.select) {
      // Check if we hit an object to select it
      final hitObjId = _hitTest(globalPos);
      if (hitObjId != null) {
        final multi = HardwareKeyboard.instance.isShiftPressed;
        ref.read(whiteboardProvider.notifier).selectObject(hitObjId, multi: multi);
      } else {
        setState(() {
          _isSelecting = true;
          _selectionStart = globalPos;
          _selectionEnd = globalPos;
        });
        ref.read(whiteboardProvider.notifier).selectObject(null);
      }
    } else if (tool.toolType == ToolType.draw) {
      if (isStylus || (isTouchOrMouse && !_isStylusActive)) {
        setState(() {
          _isDrawing = true;
          _isActionInProgress = true;
          _currentPoints = [globalPos];
        });
      } else if (isTouchOrMouse && _isStylusActive) {
        _panStartPos = event.position;
        _isManualPanning = false;
        _isActionInProgress = true;
      }
    } else if (tool.toolType == ToolType.line) {
      setState(() {
        _isLineDrawing = true;
        _lineStart = globalPos;
        _lineEnd = globalPos;
      });
    } else if (tool.toolType == ToolType.objectEraser || tool.toolType == ToolType.pointEraser) {
      if (isStylus || (isTouchOrMouse && !_isStylusActive)) {
        setState(() => _isActionInProgress = true);
        _handleEraser(globalPos, tool);
      } else if (isTouchOrMouse && _isStylusActive) {
        _panStartPos = event.position;
        _isManualPanning = false;
        _isActionInProgress = true;
      }
    }
  }

  String? _hitTest(Offset globalPos) {
    final cells = ref.read(whiteboardProvider).whiteboard.cells;
    // Iterate cells in reverse to find top-most object
    final cellKeys = cells.keys.toList()..sort((a, b) => b.compareTo(a));
    
    for (final key in cellKeys) {
      final coords = key.split(' ');
      final cellOrigin = Offset(int.parse(coords[0]) * cellSize, int.parse(coords[1]) * cellSize);
      final objects = cells[key]!;
      
      // Iterate objects in reverse (front to back)
      for (final obj in objects.reversed) {
        final rect = Rect.fromLTWH(cellOrigin.dx + obj.x, cellOrigin.dy + obj.y, obj.width, obj.height);
        if (rect.contains(globalPos)) {
          return obj.id;
        }
      }
    }
    return null;
  }

  void _onPointerMove(PointerMoveEvent event, ToolState tool, TransformationController controller) {
    final globalPos = event.localPosition;
    setState(() {
      _globalCursorPos = globalPos;
    });
    
    if (_isDrawing) {
      setState(() {
        _currentPoints = [..._currentPoints, globalPos];
      });
    } else if (_isLineDrawing) {
      setState(() => _lineEnd = globalPos);
    } else if (_isSelecting) {
      setState(() => _selectionEnd = globalPos);
    } else if (_isActionInProgress && !_isDrawing) {
      final isEraser = tool.toolType == ToolType.objectEraser || tool.toolType == ToolType.pointEraser;
      final isTouchOrMouse = event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.mouse;

      if (isTouchOrMouse && _isStylusActive) {
        if (!_isManualPanning) {
          if ((event.position - _panStartPos).distance > panThreshold) {
            setState(() => _isManualPanning = true);
          }
        }
        if (_isManualPanning) {
          final matrix = controller.value.clone();
          final translation = matrix.getTranslation();
          matrix.setTranslationRaw(
            translation.x + event.delta.dx,
            translation.y + event.delta.dy,
            0,
          );
          controller.value = matrix;
          setState(() {}); 
        }
      } else if (isEraser) {
        _handleEraser(globalPos, tool);
      }
    }
  }

  void _onPointerUp(PointerUpEvent event, ToolState tool) {
    if (_isSelecting) {
      _finishSelection();
    } else if (_isLineDrawing) {
      _finishLine(tool);
    }
    setState(() {
      _isActionInProgress = false;
      _isManualPanning = false;
      _isSelecting = false;
      _isLineDrawing = false;
      _globalCursorPos = null;
      _selectionStart = null;
      _selectionEnd = null;
      _lineStart = null;
      _lineEnd = null;
    });
    if (_isDrawing) {
      _finishDrawing(tool);
    }
  }

  void _onPointerCancel(PointerCancelEvent event, ToolState tool) {
    setState(() {
      _isActionInProgress = false;
      _isManualPanning = false;
      _isSelecting = false;
      _isLineDrawing = false;
      _globalCursorPos = null;
      _selectionStart = null;
      _selectionEnd = null;
      _lineStart = null;
      _lineEnd = null;
    });
    if (_isDrawing) {
      _finishDrawing(tool);
    }
  }

  void _finishSelection() {
    if (_selectionStart == null || _selectionEnd == null) return;
    final rect = Rect.fromPoints(_selectionStart!, _selectionEnd!);
    if (rect.width < 2 && rect.height < 2) return;

    final selectedIds = <String>{};

    final cells = ref.read(whiteboardProvider).whiteboard.cells;
    for (final cellEntry in cells.entries) {
      final coords = cellEntry.key.split(' ');
      final cellOrigin = Offset(int.parse(coords[0]) * cellSize, int.parse(coords[1]) * cellSize);

      for (final obj in cellEntry.value) {
        final objRect = Rect.fromLTWH(cellOrigin.dx + obj.x, cellOrigin.dy + obj.y, obj.width, obj.height);
        if (rect.overlaps(objRect)) {
          selectedIds.add(obj.id);
        }
      }
    }
    ref.read(whiteboardProvider.notifier).selectObjects(selectedIds);
  }

  void _finishLine(ToolState tool) {
    if (_lineStart == null || _lineEnd == null) return;
    if ((_lineEnd! - _lineStart!).distance < 5) return;

    final cellKey = _getCellKey(_lineStart!);
    final coords = cellKey.split(' ');
    final cellOrigin = Offset(int.parse(coords[0]) * cellSize, int.parse(coords[1]) * cellSize);

    final line = LineObject(
      id: const Uuid().v4(),
      x: _lineStart!.dx - cellOrigin.dx,
      y: _lineStart!.dy - cellOrigin.dy,
      width: (_lineEnd!.dx - _lineStart!.dx).abs().clamp(1.0, 50000.0),
      height: (_lineEnd!.dy - _lineStart!.dy).abs().clamp(1.0, 50000.0),
      zIndex: 0,
      start: Offset.zero,
      end: _lineEnd! - _lineStart!,
      color: tool.color.toARGB32(),
      strokeWidth: tool.strokeWidth,
      hasArrow: true,
    );
    ref.read(whiteboardProvider.notifier).addObject(cellKey, line);
  }

  void _handleEraser(Offset globalPos, ToolState tool) {
    final cells = ref.read(whiteboardProvider).whiteboard.cells;
    for (final cellEntry in cells.entries) {
      final cellKey = cellEntry.key;
      final coords = cellKey.split(' ');
      final cellGlobalOrigin = Offset(int.parse(coords[0]) * cellSize, int.parse(coords[1]) * cellSize);
      final drawings = cellEntry.value.whereType<DrawingObject>().toList();

      for (final drawing in drawings) {
        final drawingGlobalPos = cellGlobalOrigin + Offset(drawing.x, drawing.y);
        final drawingLocalEraserPos = globalPos - drawingGlobalPos;
        
        if (tool.toolType == ToolType.objectEraser) {
          for (int i = 0; i < drawing.points.length - 1; i++) {
            if (_isPointNearSegment(drawingLocalEraserPos, drawing.points[i], drawing.points[i+1], tool.eraserSize)) {
              ref.read(whiteboardProvider.notifier).removeObject(drawing.id);
              break;
            }
          }
        } else if (tool.toolType == ToolType.pointEraser) {
          final segments = <List<Offset>>[];
          List<Offset> currentSegment = [];
          bool changed = false;
          for (final p in drawing.points) {
            if ((p - drawingLocalEraserPos).distance <= tool.eraserSize) {
              changed = true;
              if (currentSegment.isNotEmpty) {
                segments.add(currentSegment);
                currentSegment = [];
              }
            } else {
              currentSegment.add(p);
            }
          }
          if (currentSegment.isNotEmpty) segments.add(currentSegment);
          if (changed) {
            ref.read(whiteboardProvider.notifier).removeObject(drawing.id);
            for (final segment in segments) {
              if (segment.length < 2) continue;
              double minX = segment.map((p) => p.dx).reduce(min);
              double minY = segment.map((p) => p.dy).reduce(min);
              final normalizedPoints = segment.map((p) => Offset(p.dx - minX, p.dy - minY)).toList();
              final newDrawing = DrawingObject(
                id: const Uuid().v4(),
                x: drawing.x + minX,
                y: drawing.y + minY,
                width: drawing.width,
                height: drawing.height,
                zIndex: drawing.zIndex,
                points: normalizedPoints,
                color: drawing.color,
                strokeWidth: drawing.strokeWidth,
                rotation: drawing.rotation,
              );
              ref.read(whiteboardProvider.notifier).addObject(cellKey, newDrawing);
            }
          }
        }
      }
    }
  }

  bool _isPointNearSegment(Offset p, Offset a, Offset b, double threshold) {
    final double l2 = (a - b).distanceSquared;
    if (l2 == 0.0) return (p - a).distance < threshold;
    double t = ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
    t = t.clamp(0.0, 1.0);
    final Offset projection = Offset(a.dx + t * (b.dx - a.dx), a.dy + t * (b.dy - a.dy));
    return (p - projection).distance < threshold;
  }

  void _finishDrawing(ToolState tool) {
    if (_currentPoints.length < 2) {
      setState(() {
        _currentPoints = [];
        _isDrawing = false;
      });
      return;
    }

    // Use the starting point to determine the "home" cell
    final startPoint = _currentPoints.first;
    final cellKey = _getCellKey(startPoint);
    final coords = cellKey.split(' ');
    final cellGlobalOrigin = Offset(int.parse(coords[0]) * cellSize, int.parse(coords[1]) * cellSize);

    // Calculate bounding box of the entire stroke
    double minX = _currentPoints.map((p) => p.dx).reduce(min);
    double maxX = _currentPoints.map((p) => p.dx).reduce(max);
    double minY = _currentPoints.map((p) => p.dy).reduce(min);
    double maxY = _currentPoints.map((p) => p.dy).reduce(max);

    // Add padding to account for stroke width and caps
    final padding = tool.strokeWidth * 1.5;
    
    // Normalize points relative to the inflated bounding box
    final normalizedPoints = _currentPoints.map((p) => Offset(p.dx - minX + padding, p.dy - minY + padding)).toList();

    final drawing = DrawingObject(
      id: const Uuid().v4(),
      // Position relative to the cell origin, adjusted for padding
      x: (minX - cellGlobalOrigin.dx) - padding,
      y: (minY - cellGlobalOrigin.dy) - padding,
      width: (maxX - minX + (padding * 2)).clamp(1.0, 50000.0),
      height: (maxY - minY + (padding * 2)).clamp(1.0, 50000.0),
      zIndex: 0,
      points: normalizedPoints,
      color: tool.color.toARGB32(),
      strokeWidth: tool.strokeWidth,
    );

    ref.read(whiteboardProvider.notifier).addObject(cellKey, drawing);

    setState(() {
      _currentPoints = [];
      _isDrawing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final whiteboardState = ref.watch(whiteboardProvider);
    final toolState = ref.watch(toolProvider);
    final transformationController = ref.watch(transformationControllerProvider);
    final screenSize = MediaQuery.sizeOf(context);
    final selectedIds = whiteboardState.selectedObjectIds;

    final isEraser = toolState.toolType == ToolType.objectEraser || toolState.toolType == ToolType.pointEraser;
    final canPan = !_isActionInProgress && (toolState.toolType == ToolType.move || 
                   toolState.toolType == ToolType.draw ||
                   isEraser) && !_isDrawing && !_isLineDrawing;

    final matrix = transformationController.value;
    final topLeft = _toGlobal(Offset.zero, matrix);
    final bottomRight = _toGlobal(Offset(screenSize.width, screenSize.height), matrix);
    final viewport = Rect.fromPoints(topLeft, bottomRight).inflate(100);

    final minCx = (viewport.left / cellSize).floor();
    final maxCx = (viewport.right / cellSize).floor();
    final minCy = (viewport.top / cellSize).floor();
    final maxCy = (viewport.bottom / cellSize).floor();

    return InteractiveViewer(
      transformationController: transformationController,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 5.0,
      panEnabled: canPan,
      scaleEnabled: true,
      onInteractionUpdate: (_) => setState(() {}),
      child: Listener(
        onPointerDown: (event) => _onPointerDown(event, toolState),
        onPointerMove: (event) => _onPointerMove(event, toolState, transformationController),
        onPointerUp: (event) => _onPointerUp(event, toolState),
        onPointerCancel: (event) => _onPointerCancel(event, toolState),
        child: Container(
          color: Colors.white,
          width: virtualSize,
          height: virtualSize,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(cellSize: 50.0, viewport: viewport),
                ),
              ),
              ...whiteboardState.whiteboard.cells.entries.where((entry) {
                final coords = entry.key.split(' ');
                final cx = int.parse(coords[0]);
                final cy = int.parse(coords[1]);
                return cx >= minCx && cx <= maxCx && cy >= minCy && cy <= maxCy;
              }).expand((cellEntry) {
                final cellKey = cellEntry.key;
                final coords = cellKey.split(' ');
                final cellGlobalOrigin = Offset(int.parse(coords[0]) * cellSize, int.parse(coords[1]) * cellSize);
                
                final allObjects = cellEntry.value;
                final bakedObjects = allObjects.where((o) => !selectedIds.contains(o.id)).toList();
                final activeObjects = allObjects.where((o) => selectedIds.contains(o.id)).toList();

                return [
                  // The "Baked" layer for this cell
                  if (bakedObjects.isNotEmpty)
                    Positioned(
                      left: cellGlobalOrigin.dx,
                      top: cellGlobalOrigin.dy,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: const Size(cellSize, cellSize),
                          painter: CellPainter(bakedObjects),
                        ),
                      ),
                    ),
                  // The "Active" layer for selected objects
                  ...activeObjects.map((obj) {
                    return ObjectWrapper(
                      key: ValueKey(obj.id),
                      cellKey: cellKey,
                      object: obj.copyWith(x: cellGlobalOrigin.dx + obj.x, y: cellGlobalOrigin.dy + obj.y),
                      child: _buildObjectContent(obj),
                    );
                  }),
                ];
              }),
              if (_currentPoints.isNotEmpty)
                CustomPaint(
                  painter: _GlobalDrawingPainter(_currentPoints, toolState.color, toolState.strokeWidth),
                ),
              if (_isLineDrawing && _lineStart != null && _lineEnd != null)
                CustomPaint(
                  painter: _TempLinePainter(_lineStart!, _lineEnd!, toolState.color, toolState.strokeWidth),
                ),
              if (_isSelecting && _selectionStart != null && _selectionEnd != null)
                Positioned.fromRect(
                  rect: Rect.fromPoints(_selectionStart!, _selectionEnd!),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.blue),
                    ),
                  ),
                ),
              if (isEraser && _globalCursorPos != null)
                Positioned(
                  left: _globalCursorPos!.dx - toolState.eraserSize,
                  top: _globalCursorPos!.dy - toolState.eraserSize,
                  child: IgnorePointer(
                    child: Container(
                      width: toolState.eraserSize * 2,
                      height: toolState.eraserSize * 2,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
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
      return RepaintBoundary(child: CustomPaint(size: Size(obj.width, obj.height), painter: DrawingPainter(obj)));
    } else if (obj is TextObject) {
      return Center(child: Text(obj.text, style: TextStyle(color: Color(obj.color), fontSize: obj.fontSize)));
    } else if (obj is ShapeObject) {
      return _buildShape(obj);
    } else if (obj is LineObject) {
       return CustomPaint(size: Size(obj.width, obj.height), painter: LinePainter(obj));
    } else if (obj is ImageObject) {
      return Image.file(File(obj.imagePath), width: obj.width, height: obj.height, fit: BoxFit.fill);
    }
    return const SizedBox.shrink();
  }

  Widget _buildShape(ShapeObject obj) {
    Widget shape;
    switch (obj.shapeType) {
      case ShapeType.rectangle:
        shape = Container(decoration: BoxDecoration(border: Border.all(color: Color(obj.color), width: 2)));
        break;
      case ShapeType.circle:
        shape = Container(decoration: BoxDecoration(border: Border.all(color: Color(obj.color), width: 2), shape: BoxShape.circle));
        break;
      case ShapeType.stickyNote:
        shape = Container(
          color: Color(obj.color),
          padding: const EdgeInsets.all(8),
          child: Center(child: Text(obj.text ?? '', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        );
        break;
    }
    return shape;
  }
}

class _GlobalDrawingPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  _GlobalDrawingPainter(this.points, this.color, this.strokeWidth);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()..color = color..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant _GlobalDrawingPainter oldDelegate) => true;
}

class _TempLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;
  _TempLinePainter(this.start, this.end, this.color, this.strokeWidth);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
    // Draw simple arrow head
    final angle = (end - start).direction;
    const arrowSize = 15.0;
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate(angle);
    final arrowPath = Path()..moveTo(0, 0)..lineTo(-arrowSize, -arrowSize / 2)..lineTo(-arrowSize, arrowSize / 2)..close();
    canvas.drawPath(arrowPath, Paint()..color = color);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _TempLinePainter oldDelegate) => true;
}

class LinePainter extends CustomPainter {
  final LineObject line;
  LinePainter(this.line);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color(line.color)..strokeWidth = line.strokeWidth..strokeCap = StrokeCap.round;
    canvas.drawLine(line.start, line.end, paint);
    if (line.hasArrow) {
      final angle = (line.end - line.start).direction;
      const arrowSize = 15.0;
      canvas.save();
      canvas.translate(line.end.dx, line.end.dy);
      canvas.rotate(angle);
      final arrowPath = Path()..moveTo(0, 0)..lineTo(-arrowSize, -arrowSize / 2)..lineTo(-arrowSize, arrowSize / 2)..close();
      canvas.drawPath(arrowPath, Paint()..color = Color(line.color));
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) => oldDelegate.line != line;
}
