import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/board_objects.dart';
import '../providers/whiteboard_provider.dart';
import '../providers/tool_provider.dart';
import '../providers/canvas_provider.dart';
import 'global_board_painter.dart';

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

  static const double cellSize = 1000.0;
  static const double panThreshold = 5.0;

  @override
  void initState() {
    super.initState();
  }

  Offset _getBoardPos(Offset screenPos) {
    final matrix = ref.read(transformationControllerProvider).value;
    final inv = Matrix4.inverted(matrix);
    return MatrixUtils.transformPoint(inv, screenPos);
  }

  String _getCellKey(Offset globalPos) {
    final cx = (globalPos.dx / cellSize).floor();
    final cy = (globalPos.dy / cellSize).floor();
    return "$cx $cy";
  }

  void _onPointerDown(PointerDownEvent event, ToolState tool) {
    final screenPos = event.localPosition;
    final boardPos = _getBoardPos(screenPos);
    
    setState(() {
      _globalCursorPos = boardPos;
      if (event.kind == PointerDeviceKind.stylus) {
        _isStylusActive = true;
      }
    });

    final isStylus = event.kind == PointerDeviceKind.stylus;
    final isTouchOrMouse = event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.mouse;

    if (tool.toolType == ToolType.select) {
      // Check if we hit an object to select it
      final hitObjId = _hitTest(boardPos);
      if (hitObjId != null) {
        final multi = HardwareKeyboard.instance.isShiftPressed;
        ref.read(whiteboardProvider.notifier).selectObject(hitObjId, multi: multi);
      } else {
        setState(() {
          _isSelecting = true;
          _selectionStart = boardPos;
          _selectionEnd = boardPos;
        });
        ref.read(whiteboardProvider.notifier).selectObject(null);
      }
    } else if (tool.toolType == ToolType.draw) {
      if (isStylus || (isTouchOrMouse && !_isStylusActive)) {
        setState(() {
          _isDrawing = true;
          _isActionInProgress = true;
          _currentPoints = [boardPos];
        });
      } else if (isTouchOrMouse && _isStylusActive) {
        _panStartPos = event.position;
        _isManualPanning = false;
        _isActionInProgress = true;
      }
    } else if (tool.toolType == ToolType.line) {
      setState(() {
        _isLineDrawing = true;
        _lineStart = boardPos;
        _lineEnd = boardPos;
      });
    } else if (tool.toolType == ToolType.objectEraser || tool.toolType == ToolType.pointEraser) {
      if (isStylus || (isTouchOrMouse && !_isStylusActive)) {
        setState(() => _isActionInProgress = true);
        _handleEraser(boardPos, tool);
      } else if (isTouchOrMouse && _isStylusActive) {
        _panStartPos = event.position;
        _isManualPanning = false;
        _isActionInProgress = true;
      }
    }
  }

  String? _hitTest(Offset globalPos) {
    final cells = ref.read(whiteboardProvider).whiteboard.cells;
    final List<({Offset origin, BoardObject obj})> allObjects = [];

    for (final entry in cells.entries) {
      final coords = entry.key.split(' ');
      if (coords.length != 2) continue;
      final cx = int.tryParse(coords[0]);
      final cy = int.tryParse(coords[1]);
      if (cx == null || cy == null) continue;
      final cellOrigin = Offset(cx * cellSize, cy * cellSize);
      
      for (final obj in entry.value) {
        allObjects.add((origin: cellOrigin, obj: obj));
      }
    }

    // Sort by createdAt DESC (front to back)
    allObjects.sort((a, b) => b.obj.createdAt.compareTo(a.obj.createdAt));
    
    for (final item in allObjects) {
      final obj = item.obj;
      final cellOrigin = item.origin;
      final rect = Rect.fromLTWH(cellOrigin.dx + obj.x, cellOrigin.dy + obj.y, obj.width, obj.height);
      if (rect.contains(globalPos)) {
        return obj.id;
      }
    }
    return null;
  }

  void _onPointerMove(PointerMoveEvent event, ToolState tool, TransformationController controller) {
    final screenPos = event.localPosition;
    final boardPos = _getBoardPos(screenPos);
    
    setState(() {
      _globalCursorPos = boardPos;
    });
    
    if (_isDrawing) {
      setState(() {
        _currentPoints = [..._currentPoints, boardPos];
      });
    } else if (_isLineDrawing) {
      setState(() => _lineEnd = boardPos);
    } else if (_isSelecting) {
      setState(() => _selectionEnd = boardPos);
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
        _handleEraser(boardPos, tool);
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

    // Prepare bakeable objects once per build, pre-sorted
    final List<({Offset origin, BoardObject obj})> allSortedObjects = [];
    final cells = whiteboardState.whiteboard.cells;

    for (int cx = minCx; cx <= maxCx; cx++) {
      for (int cy = minCy; cy <= maxCy; cy++) {
        final key = "$cx $cy";
        final cellObjects = cells[key];
        if (cellObjects == null) continue;
        
        final cellOrigin = Offset(cx * cellSize, cy * cellSize);
        for (final obj in cellObjects) {
          allSortedObjects.add((origin: cellOrigin, obj: obj));
        }
      }
    }
    allSortedObjects.sort((a, b) => a.obj.createdAt.compareTo(b.obj.createdAt));

    return Stack(
      children: [
        // 1. Static Layer (Everything is drawn via CustomPainter now)
        Positioned.fill(
          child: CustomPaint(
            painter: GlobalBoardPainter(
              sortedObjects: allSortedObjects,
              matrix: matrix,
            ),
          ),
        ),

        // 2. Selection Overlays (Simple border boxes for moving objects)
        ...allSortedObjects.where((item) => selectedIds.contains(item.obj.id)).map((item) {
          final obj = item.obj;
          final origin = item.origin;
          final scale = matrix.getMaxScaleOnAxis();
          final screenTopLeft = MatrixUtils.transformPoint(matrix, Offset(origin.dx + obj.x, origin.dy + obj.y));
          
          return Positioned(
            left: screenTopLeft.dx,
            top: screenTopLeft.dy,
            width: obj.width * scale,
            height: obj.height * scale,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                // Scale the drag delta down so dragging is consistent at high zoom
                final scaledDelta = details.delta / scale;
                ref.read(whiteboardProvider.notifier).moveSelected(scaledDelta);
              },
              onPanEnd: (_) => ref.read(whiteboardProvider.notifier).endAction(),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
              ),
            ),
          );
        }),

        // 3. Temporary Painters (While drawing)
        if (_currentPoints.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _GlobalDrawingPainter(_currentPoints, toolState.color, toolState.strokeWidth, matrix),
            ),
          ),
        if (_isLineDrawing && _lineStart != null && _lineEnd != null)
          Positioned.fill(
            child: CustomPaint(
              painter: _TempLinePainter(_lineStart!, _lineEnd!, toolState.color, toolState.strokeWidth, matrix),
            ),
          ),
        if (_isSelecting && _selectionStart != null && _selectionEnd != null)
          Builder(
            builder: (context) {
              final screenStart = MatrixUtils.transformPoint(matrix, _selectionStart!);
              final screenEnd = MatrixUtils.transformPoint(matrix, _selectionEnd!);
              return Positioned.fromRect(
                rect: Rect.fromPoints(screenStart, screenEnd),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.blue),
                  ),
                ),
              );
            }
          ),
        if (isEraser && _globalCursorPos != null)
          Builder(
            builder: (context) {
              final screenPos = MatrixUtils.transformPoint(matrix, _globalCursorPos!);
              final scaledSize = toolState.eraserSize * matrix.getMaxScaleOnAxis();
              return Positioned(
                left: screenPos.dx - scaledSize,
                top: screenPos.dy - scaledSize,
                child: IgnorePointer(
                  child: Container(
                    width: scaledSize * 2,
                    height: scaledSize * 2,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      color: Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }
          ),

        // 4. Interaction Layer (Invisible, handles panning and zooming physics)
        Positioned.fill(
          child: Listener(
            onPointerDown: (event) => _onPointerDown(event, toolState),
            onPointerMove: (event) => _onPointerMove(event, toolState, transformationController),
            onPointerUp: (event) => _onPointerUp(event, toolState),
            onPointerCancel: (event) => _onPointerCancel(event, toolState),
            child: InteractiveViewer(
              transformationController: transformationController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.1,
              maxScale: 5.0,
              panEnabled: canPan,
              scaleEnabled: true,
              onInteractionUpdate: (_) => setState(() {}),
              child: const SizedBox(width: 1000000, height: 1000000), // Pure geometry for hit area
            ),
          ),
        ),
      ],
    );
  }
}

class _GlobalDrawingPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final Matrix4 matrix;
  _GlobalDrawingPainter(this.points, this.color, this.strokeWidth, this.matrix);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    canvas.save();
    canvas.transform(matrix.storage);
    
    final paint = Paint()..color = color..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
    
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _GlobalDrawingPainter oldDelegate) => true;
}

class _TempLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;
  final Matrix4 matrix;
  _TempLinePainter(this.start, this.end, this.color, this.strokeWidth, this.matrix);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(matrix.storage);

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
    
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _TempLinePainter oldDelegate) => true;
}
