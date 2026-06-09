import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/whiteboard_models.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minimal Whiteboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      home: const MenuPage(),
    );
  }
}

// --- Providers ---

class WhiteboardState {
  final Whiteboard whiteboard;
  final Set<String> selectedObjectIds;
  final bool hasBeenSaved;
  final List<Whiteboard> undoStack;
  final List<Whiteboard> redoStack;

  WhiteboardState({
    required this.whiteboard,
    this.selectedObjectIds = const {},
    this.hasBeenSaved = false,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  WhiteboardState copyWith({
    Whiteboard? whiteboard,
    Set<String>? selectedObjectIds,
    bool? hasBeenSaved,
    List<Whiteboard>? undoStack,
    List<Whiteboard>? redoStack,
  }) {
    return WhiteboardState(
      whiteboard: whiteboard ?? this.whiteboard,
      selectedObjectIds: selectedObjectIds ?? this.selectedObjectIds,
      hasBeenSaved: hasBeenSaved ?? this.hasBeenSaved,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}

class WhiteboardNotifier extends Notifier<WhiteboardState> {
  @override
  WhiteboardState build() => WhiteboardState(whiteboard: Whiteboard(id: const Uuid().v4(), title: 'Untitled Board', cells: {}));
  
  void _saveMemento() {
    state = state.copyWith(
      undoStack: [...state.undoStack, state.whiteboard],
      redoStack: [],
    );
  }

  void undo() {
    if (state.undoStack.isEmpty) return;
    final current = state.whiteboard;
    final previous = state.undoStack.last;
    state = state.copyWith(
      whiteboard: previous,
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: [...state.redoStack, current],
      selectedObjectIds: {},
    );
  }

  void redo() {
    if (state.redoStack.isEmpty) return;
    final current = state.whiteboard;
    final next = state.redoStack.last;
    state = state.copyWith(
      whiteboard: next,
      undoStack: [...state.undoStack, current],
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
      selectedObjectIds: {},
    );
  }

  void setWhiteboard(Whiteboard board, {bool isSaved = true}) {
    state = WhiteboardState(whiteboard: board, hasBeenSaved: isSaved);
  }

  void selectObject(String? id, {bool multi = false}) {
    if (id == null) { state = state.copyWith(selectedObjectIds: {}); return; }
    final newSet = Set<String>.from(state.selectedObjectIds);
    if (multi) { if (newSet.contains(id)) newSet.remove(id); else newSet.add(id); }
    else { newSet.clear(); newSet.add(id); }
    state = state.copyWith(selectedObjectIds: newSet);
  }

  void addObject(String cellKey, BoardObject obj) {
    _saveMemento();
    final cells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    cells[cellKey] = [...(cells[cellKey] ?? []), obj];
    state = state.copyWith(whiteboard: state.whiteboard.copyWith(cells: cells));
  }

  void removeObject(String id) {
    _saveMemento();
    final cells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    bool changed = false;
    for (final key in cells.keys.toList()) {
      final originalCount = cells[key]!.length;
      cells[key] = cells[key]!.where((o) => o.id != id).toList();
      if (cells[key]!.length != originalCount) changed = true;
      if (cells[key]!.isEmpty) cells.remove(key);
    }
    if (changed) {
      state = state.copyWith(
        whiteboard: state.whiteboard.copyWith(cells: cells),
        selectedObjectIds: state.selectedObjectIds.where((sid) => sid != id).toSet(),
      );
    }
  }

  void removeSelected() {
    if (state.selectedObjectIds.isEmpty) return;
    _saveMemento();
    final cells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    final idsToRemove = state.selectedObjectIds;

    for (final key in cells.keys.toList()) {
      cells[key] = cells[key]!.where((o) => !idsToRemove.contains(o.id)).toList();
      if (cells[key]!.isEmpty) cells.remove(key);
    }

    state = state.copyWith(
      whiteboard: state.whiteboard.copyWith(cells: cells),
      selectedObjectIds: {},
    );
  }

  void markAsSaved() => state = state.copyWith(hasBeenSaved: true);
}
final whiteboardProvider = NotifierProvider<WhiteboardNotifier, WhiteboardState>(WhiteboardNotifier.new);

enum ToolType { pen, eraser, text, select }
class ToolState {
  final ToolType type;
  final Color color;
  final double strokeWidth;
  ToolState({this.type = ToolType.pen, this.color = Colors.black, this.strokeWidth = 2.0});
  ToolState copyWith({ToolType? type, Color? color, double? strokeWidth}) => ToolState(type: type ?? this.type, color: color ?? this.color, strokeWidth: strokeWidth ?? this.strokeWidth);
}
class ToolNotifier extends Notifier<ToolState> {
  @override
  ToolState build() => ToolState();
  void setType(ToolType t) => state = state.copyWith(type: t);
  void setColor(Color c) => state = state.copyWith(color: c);
  void setStrokeWidth(double w) => state = state.copyWith(strokeWidth: w);
}
final toolProvider = NotifierProvider<ToolNotifier, ToolState>(ToolNotifier.new);

class StorageNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('boards') ?? [];
  }
  Future<void> saveBoard(Whiteboard board) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('board_${board.title}', jsonEncode(board.toJson()));
    final titles = (await SharedPreferences.getInstance()).getStringList('boards') ?? [];
    if (!titles.contains(board.title)) {
      titles.add(board.title);
      await (await SharedPreferences.getInstance()).setStringList('boards', titles);
      ref.invalidateSelf();
    }
  }
  Future<Whiteboard?> loadBoard(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('board_$title');
    if (data == null) return null;
    return Whiteboard.fromJson(jsonDecode(data));
  }
  Future<void> deleteBoard(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('board_$title');
    final titles = (await SharedPreferences.getInstance()).getStringList('boards') ?? [];
    titles.remove(title);
    await (await SharedPreferences.getInstance()).setStringList('boards', titles);
    ref.invalidateSelf();
  }
}
final storageProvider = AsyncNotifierProvider<StorageNotifier, List<String>>(StorageNotifier.new);

// --- Intents for Shortcuts ---
class UndoIntent extends Intent { const UndoIntent(); }
class RedoIntent extends Intent { const RedoIntent(); }

// --- UI Components ---

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(storageProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Whiteboards'), centerTitle: true),
      body: boards.when(
        data: (list) => Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(whiteboardProvider.notifier).setWhiteboard(Whiteboard(id: const Uuid().v4(), title: 'Untitled Board', cells: {}), isSaved: false);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const WhiteboardPage()));
                  },
                  icon: const Icon(Icons.add), label: const Text('New Board'),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: list.isEmpty ? const Center(child: Text('No boards yet')) : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (c, i) => ListTile(
                      title: Text(list[i]),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => ref.read(storageProvider.notifier).deleteBoard(list[i])),
                      onTap: () async {
                        final b = await ref.read(storageProvider.notifier).loadBoard(list[i]);
                        if (b != null) {
                          ref.read(whiteboardProvider.notifier).setWhiteboard(b);
                          Navigator.push(context, MaterialPageRoute(builder: (c) => const WhiteboardPage()));
                        }
                      },
                    ),
                  ),
                ),
                const Text('v0.2.1', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text(e.toString())),
      ),
    );
  }
}

class WhiteboardPage extends ConsumerWidget {
  const WhiteboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): const UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): const RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): const RedoIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          UndoIntent: CallbackAction<UndoIntent>(onInvoke: (_) => ref.read(whiteboardProvider.notifier).undo()),
          RedoIntent: CallbackAction<RedoIntent>(onInvoke: (_) => ref.read(whiteboardProvider.notifier).redo()),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                const WhiteboardCanvas(),
                Positioned(top: 20, left: 20, child: FloatingActionButton.small(heroTag: 'back_btn', onPressed: () => Navigator.pop(context), child: const Icon(Icons.arrow_back))),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 30),
                    child: WhiteboardToolbar(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WhiteboardCanvas extends ConsumerStatefulWidget {
  const WhiteboardCanvas({super.key});
  @override
  ConsumerState<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends ConsumerState<WhiteboardCanvas> {
  List<Offset> _currentPoints = [];
  bool _isDrawing = false;
  static const double cellSize = 1000.0;

  @override
  Widget build(BuildContext context) {
    final wb = ref.watch(whiteboardProvider);
    final tool = ref.watch(toolProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (d) {
            if (tool.type == ToolType.pen) {
              setState(() {
                _isDrawing = true;
                _currentPoints = [d.localPosition];
              });
            }
          },
          onPanUpdate: (d) {
            if (_isDrawing) setState(() { _currentPoints.add(d.localPosition); });
          },
          onPanEnd: (d) {
            if (_isDrawing) {
              _finishDrawing();
              setState(() {
                _isDrawing = false;
                _currentPoints = [];
              });
            }
          },
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: Colors.white,
            child: CustomPaint(
              painter: BoardPainter(
                whiteboard: wb.whiteboard,
                currentPoints: _currentPoints,
                isDrawing: _isDrawing,
                toolColor: tool.color,
                toolStrokeWidth: tool.strokeWidth,
                cellSize: cellSize,
              ),
            ),
          ),
        );
      },
    );
  }

  void _finishDrawing() {
    if (_currentPoints.length < 2) return;
    final tool = ref.read(toolProvider);
    final start = _currentPoints.first;
    final cx = (start.dx / cellSize).floor();
    final cy = (start.dy / cellSize).floor();
    final cellKey = "$cx $cy";
    final origin = Offset(cx * cellSize, cy * cellSize);
    
    double minX = _currentPoints.map((p) => p.dx).reduce(min);
    double maxX = _currentPoints.map((p) => p.dx).reduce(max);
    double minY = _currentPoints.map((p) => p.dy).reduce(min);
    double maxY = _currentPoints.map((p) => p.dy).reduce(max);
    final padding = tool.strokeWidth * 1.5;

    final drawing = DrawingObject(
      id: const Uuid().v4(),
      x: minX - origin.dx - padding,
      y: minY - origin.dy - padding,
      width: maxX - minX + padding * 2,
      height: maxY - minY + padding * 2,
      points: _currentPoints.map((p) => Offset(p.dx - minX + padding, p.dy - minY + padding)).toList(),
      color: tool.color.toARGB32(),
      strokeWidth: tool.strokeWidth,
    );
    ref.read(whiteboardProvider.notifier).addObject(cellKey, drawing);
  }
}

class BoardPainter extends CustomPainter {
  final Whiteboard whiteboard;
  final List<Offset> currentPoints;
  final bool isDrawing;
  final Color toolColor;
  final double toolStrokeWidth;
  final double cellSize;

  BoardPainter({
    required this.whiteboard,
    required this.currentPoints,
    required this.isDrawing,
    required this.toolColor,
    required this.toolStrokeWidth,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw all saved objects
    for (final entry in whiteboard.cells.entries) {
      final key = entry.key;
      final coords = key.split(' ');
      final cellOrigin = Offset(
        double.parse(coords[0]) * cellSize,
        double.parse(coords[1]) * cellSize,
      );

      for (final obj in entry.value) {
        canvas.save();
        canvas.translate(cellOrigin.dx + obj.x, cellOrigin.dy + obj.y);
        
        if (obj is DrawingObject) {
          _drawDrawing(canvas, obj);
        } else if (obj is TextObject) {
          _drawText(canvas, obj);
        }
        
        canvas.restore();
      }
    }

    // 2. Draw current active stroke
    if (isDrawing && currentPoints.length >= 2) {
      final paint = Paint()
        ..color = toolColor
        ..strokeWidth = toolStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (var p in currentPoints.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawDrawing(Canvas canvas, DrawingObject obj) {
    if (obj.points.isEmpty) return;
    final paint = Paint()
      ..color = Color(obj.color)
      ..strokeWidth = obj.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(obj.points.first.dx, obj.points.first.dy);
    for (var p in obj.points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, TextObject obj) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: obj.text,
        style: TextStyle(color: Color(obj.color), fontSize: obj.fontSize),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}

class WhiteboardToolbar extends ConsumerWidget {
  const WhiteboardToolbar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolProvider);
    final wb = ref.watch(whiteboardProvider);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toolBtn(ref, ToolType.pen, Icons.edit, tool.type == ToolType.pen),
              _toolBtn(ref, ToolType.eraser, Icons.auto_fix_high, tool.type == ToolType.eraser),
              _toolBtn(ref, ToolType.text, Icons.text_fields, tool.type == ToolType.text),
              _toolBtn(ref, ToolType.select, Icons.near_me, tool.type == ToolType.select),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: VerticalDivider(width: 1, thickness: 1)),
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: wb.undoStack.isEmpty ? null : () => ref.read(whiteboardProvider.notifier).undo(),
                tooltip: 'Undo (Ctrl+Z)',
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: wb.redoStack.isEmpty ? null : () => ref.read(whiteboardProvider.notifier).redo(),
                tooltip: 'Redo (Ctrl+Y)',
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: VerticalDivider(width: 1, thickness: 1)),
              IconButton(icon: const Icon(Icons.save), onPressed: () => _save(context, ref), tooltip: 'Save Board'),
            ],
          ),
        ),
      ),
    );
  }
  Widget _toolBtn(WidgetRef ref, ToolType t, IconData icon, bool active) => IconButton(
    icon: Icon(icon, color: active ? Colors.blue : null),
    onPressed: () => ref.read(toolProvider.notifier).setType(t),
  );
  void _save(BuildContext context, WidgetRef ref) async {
    final wb = ref.read(whiteboardProvider).whiteboard;
    final controller = TextEditingController(text: wb.title);
    final title = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Save Board'),
      content: TextField(controller: controller, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Save'))],
    ));
    if (title != null && title.isNotEmpty) {
      await ref.read(storageProvider.notifier).saveBoard(wb.copyWith(title: title));
      ref.read(whiteboardProvider.notifier).markAsSaved();
    }
  }
}

class FreehandPainter extends CustomPainter {
  final List<Offset> points; final Color color; final double strokeWidth;
  FreehandPainter(this.points, this.color, this.strokeWidth);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()..color = color..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var p in points.skip(1)) path.lineTo(p.dx, p.dy);
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant FreehandPainter old) => true;
}

class DrawingPainter extends CustomPainter {
  final DrawingObject drawing;
  DrawingPainter(this.drawing);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color(drawing.color)..strokeWidth = drawing.strokeWidth..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    final path = Path()..moveTo(drawing.points.first.dx, drawing.points.first.dy);
    for (var p in drawing.points.skip(1)) path.lineTo(p.dx, p.dy);
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant DrawingPainter old) => old.drawing != drawing;
}
