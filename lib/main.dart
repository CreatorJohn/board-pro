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
  WhiteboardState({required this.whiteboard, this.selectedObjectIds = const {}, this.hasBeenSaved = false});
  WhiteboardState copyWith({Whiteboard? whiteboard, Set<String>? selectedObjectIds, bool? hasBeenSaved}) {
    return WhiteboardState(
      whiteboard: whiteboard ?? this.whiteboard,
      selectedObjectIds: selectedObjectIds ?? this.selectedObjectIds,
      hasBeenSaved: hasBeenSaved ?? this.hasBeenSaved,
    );
  }
}

class WhiteboardNotifier extends Notifier<WhiteboardState> {
  @override
  WhiteboardState build() => WhiteboardState(whiteboard: Whiteboard(id: const Uuid().v4(), title: 'Untitled Board', cells: {}));
  
  void setWhiteboard(Whiteboard board, {bool isSaved = true}) => state = state.copyWith(whiteboard: board, hasBeenSaved: isSaved, selectedObjectIds: {});
  void selectObject(String? id, {bool multi = false}) {
    if (id == null) { state = state.copyWith(selectedObjectIds: {}); return; }
    final newSet = Set<String>.from(state.selectedObjectIds);
    if (multi) { if (newSet.contains(id)) newSet.remove(id); else newSet.add(id); }
    else { newSet.clear(); newSet.add(id); }
    state = state.copyWith(selectedObjectIds: newSet);
  }
  void addObject(String cellKey, BoardObject obj) {
    final cells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    cells[cellKey] = [...(cells[cellKey] ?? []), obj];
    state = state.copyWith(whiteboard: state.whiteboard.copyWith(cells: cells));
  }
  void removeObject(String id) {
    final cells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    for (final key in cells.keys.toList()) {
      cells[key] = cells[key]!.where((o) => o.id != id).toList();
      if (cells[key]!.isEmpty) cells.remove(key);
    }
    state = state.copyWith(whiteboard: state.whiteboard.copyWith(cells: cells), selectedObjectIds: state.selectedObjectIds.where((sid) => sid != id).toSet());
  }
  void removeSelected() {
    for (final id in state.selectedObjectIds) removeObject(id);
    state = state.copyWith(selectedObjectIds: {});
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
    final titles = await build();
    if (!titles.contains(board.title)) {
      titles.add(board.title);
      await prefs.setStringList('boards', titles);
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
    final titles = await build();
    titles.remove(title);
    await prefs.setStringList('boards', titles);
    ref.invalidateSelf();
  }
}
final storageProvider = AsyncNotifierProvider<StorageNotifier, List<String>>(StorageNotifier.new);

final transformationControllerProvider = Provider((ref) => TransformationController());

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
                const Text('v0.2.0', style: TextStyle(color: Colors.grey)),
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
    final controller = ref.watch(transformationControllerProvider);
    return Scaffold(
      body: Stack(
        children: [
          const WhiteboardCanvas(),
          Positioned(top: 20, left: 20, child: FloatingActionButton.small(onPressed: () => Navigator.pop(context), child: const Icon(Icons.arrow_back))),
          const Align(alignment: Alignment.bottomCenter, child: Padding(padding: EdgeInsets.only(bottom: 20), child: WhiteboardToolbar())),
        ],
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
    final controller = ref.watch(transformationControllerProvider);

    return InteractiveViewer(
      transformationController: controller,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1, maxScale: 5.0,
      child: GestureDetector(
        onPanStart: (d) {
          if (tool.type == ToolType.pen) {
            setState(() { _isDrawing = true; _currentPoints = [d.localPosition]; });
          }
        },
        onPanUpdate: (d) {
          if (_isDrawing) setState(() { _currentPoints.add(d.localPosition); });
        },
        onPanEnd: (d) {
          if (_isDrawing) {
            _finishDrawing();
            setState(() { _isDrawing = false; _currentPoints = []; });
          }
        },
        child: Container(
          width: 5000, height: 5000, color: Colors.white,
          child: Stack(
            children: [
              ...wb.whiteboard.cells.entries.expand((e) {
                final coords = e.key.split(' ');
                final origin = Offset(double.parse(coords[0]) * cellSize, double.parse(coords[1]) * cellSize);
                return e.value.map((obj) => Positioned(
                  left: origin.dx + obj.x, top: origin.dy + obj.y,
                  child: _buildObject(obj),
                ));
              }),
              if (_isDrawing) CustomPaint(painter: FreehandPainter(_currentPoints, tool.color, tool.strokeWidth)),
            ],
          ),
        ),
      ),
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
      x: minX - origin.dx - padding, y: minY - origin.dy - padding,
      width: maxX - minX + padding * 2, height: maxY - minY + padding * 2,
      points: _currentPoints.map((p) => Offset(p.dx - minX + padding, p.dy - minY + padding)).toList(),
      color: tool.color.toARGB32(), strokeWidth: tool.strokeWidth,
    );
    ref.read(whiteboardProvider.notifier).addObject(cellKey, drawing);
  }

  Widget _buildObject(BoardObject obj) {
    if (obj is DrawingObject) return CustomPaint(size: Size(obj.width, obj.height), painter: DrawingPainter(obj));
    if (obj is TextObject) return Text(obj.text, style: TextStyle(color: Color(obj.color), fontSize: obj.fontSize));
    return const SizedBox();
  }
}

class WhiteboardToolbar extends ConsumerWidget {
  const WhiteboardToolbar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolProvider);
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toolBtn(ref, ToolType.pen, Icons.edit, tool.type == ToolType.pen),
            _toolBtn(ref, ToolType.eraser, Icons.auto_fix_high, tool.type == ToolType.eraser),
            _toolBtn(ref, ToolType.text, Icons.text_fields, tool.type == ToolType.text),
            _toolBtn(ref, ToolType.select, Icons.near_me, tool.type == ToolType.select),
            const VerticalDivider(),
            IconButton(icon: const Icon(Icons.save), onPressed: () => _save(context, ref)),
          ],
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
