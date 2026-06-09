import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_objects.dart';
import 'package:uuid/uuid.dart';

class WhiteboardState {
  final Whiteboard whiteboard;
  final Set<String> selectedObjectIds;
  final List<Whiteboard> undoHistory;
  final List<Whiteboard> redoHistory;
  final bool hasBeenSaved;

  WhiteboardState({
    required this.whiteboard,
    this.selectedObjectIds = const {},
    this.undoHistory = const [],
    this.redoHistory = const [],
    this.hasBeenSaved = false,
  });

  WhiteboardState copyWith({
    Whiteboard? whiteboard,
    Set<String>? selectedObjectIds,
    bool clearSelection = false,
    List<Whiteboard>? undoHistory,
    List<Whiteboard>? redoHistory,
    bool? hasBeenSaved,
  }) =>
      WhiteboardState(
        whiteboard: whiteboard ?? this.whiteboard,
        selectedObjectIds: clearSelection ? const {} : (selectedObjectIds ?? this.selectedObjectIds),
        undoHistory: undoHistory ?? this.undoHistory,
        redoHistory: redoHistory ?? this.redoHistory,
        hasBeenSaved: hasBeenSaved ?? this.hasBeenSaved,
      );
}

class WhiteboardNotifier extends Notifier<WhiteboardState> {
  static const double cellSize = 1000.0;

  @override
  WhiteboardState build() {
    return WhiteboardState(
      whiteboard: Whiteboard(
        id: const Uuid().v4(),
        title: 'Untitled Board',
        cells: {},
      ),
    );
  }

  void _saveToHistory() {
    state = state.copyWith(
      undoHistory: [...state.undoHistory, state.whiteboard],
      redoHistory: [],
    );
  }

  void undo() {
    if (state.undoHistory.isEmpty) return;
    final currentBoard = state.whiteboard;
    final lastBoard = state.undoHistory.last;
    final newUndoHistory = List<Whiteboard>.from(state.undoHistory)..removeLast();
    state = state.copyWith(
      whiteboard: lastBoard,
      undoHistory: newUndoHistory,
      redoHistory: [...state.redoHistory, currentBoard],
      clearSelection: true,
    );
  }

  void redo() {
    if (state.redoHistory.isEmpty) return;
    final currentBoard = state.whiteboard;
    final nextBoard = state.redoHistory.last;
    final newRedoHistory = List<Whiteboard>.from(state.redoHistory)..removeLast();
    state = state.copyWith(
      whiteboard: nextBoard,
      undoHistory: [...state.undoHistory, currentBoard],
      redoHistory: newRedoHistory,
      clearSelection: true,
    );
  }

  String _getCellKey(double globalX, double globalY) {
    final cx = (globalX / cellSize).floor();
    final cy = (globalY / cellSize).floor();
    return "$cx $cy";
  }

  void addObject(String cellKey, BoardObject object) {
    _saveToHistory();
    final currentCells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    
    // Calculate global position to ensure correct cell
    final coords = cellKey.split(' ');
    final originX = int.parse(coords[0]) * cellSize;
    final originY = int.parse(coords[1]) * cellSize;
    final globalX = originX + object.x;
    final globalY = originY + object.y;
    
    final correctKey = _getCellKey(globalX, globalY);
    final correctOriginX = (globalX / cellSize).floor() * cellSize;
    final correctOriginY = (globalY / cellSize).floor() * cellSize;
    
    final normalizedObj = object.copyWith(
      x: globalX - correctOriginX,
      y: globalY - correctOriginY,
    );

    final cellObjects = List<BoardObject>.from(currentCells[correctKey] ?? []);
    cellObjects.add(normalizedObj);
    currentCells[correctKey] = cellObjects;
    state = state.copyWith(whiteboard: state.whiteboard.copyWith(cells: currentCells));
  }

  void updateObject(String cellKey, BoardObject object) {
    final currentCells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    
    // 1. Find and remove the old version
    String? oldKey;
    for (final entry in currentCells.entries) {
      if (entry.value.any((o) => o.id == object.id)) {
        oldKey = entry.key;
        break;
      }
    }
    if (oldKey != null) {
      currentCells[oldKey] = currentCells[oldKey]!.where((o) => o.id != object.id).toList();
      if (currentCells[oldKey]!.isEmpty) currentCells.remove(oldKey);
    }

    // 2. Re-calculate correct cell for the new version
    final coords = cellKey.split(' ');
    final originX = int.parse(coords[0]) * cellSize;
    final originY = int.parse(coords[1]) * cellSize;
    final globalX = originX + object.x;
    final globalY = originY + object.y;
    
    final correctKey = _getCellKey(globalX, globalY);
    final correctOriginX = (globalX / cellSize).floor() * cellSize;
    final correctOriginY = (globalY / cellSize).floor() * cellSize;
    
    final normalizedObj = object.copyWith(
      x: globalX - correctOriginX,
      y: globalY - correctOriginY,
    );

    final cellObjects = List<BoardObject>.from(currentCells[correctKey] ?? []);
    cellObjects.add(normalizedObj);
    currentCells[correctKey] = cellObjects;
    
    state = state.copyWith(whiteboard: state.whiteboard.copyWith(cells: currentCells));
  }

  void removeObject(String id) {
    _saveToHistory();
    final currentCells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    String? foundCellKey;
    for (final entry in currentCells.entries) {
      if (entry.value.any((o) => o.id == id)) {
        foundCellKey = entry.key;
        break;
      }
    }
    if (foundCellKey != null) {
      currentCells[foundCellKey] = currentCells[foundCellKey]!.where((o) => o.id != id).toList();
      if (currentCells[foundCellKey]!.isEmpty) currentCells.remove(foundCellKey);
      state = state.copyWith(
        whiteboard: state.whiteboard.copyWith(cells: currentCells),
        selectedObjectIds: state.selectedObjectIds.where((sid) => sid != id).toSet(),
      );
    }
  }

  void removeSelected() {
    if (state.selectedObjectIds.isEmpty) return;
    _saveToHistory();
    final currentCells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    final idsToRemove = state.selectedObjectIds;

    for (final key in currentCells.keys.toList()) {
      currentCells[key] = currentCells[key]!.where((o) => !idsToRemove.contains(o.id)).toList();
      if (currentCells[key]!.isEmpty) currentCells.remove(key);
    }

    state = state.copyWith(
      whiteboard: state.whiteboard.copyWith(cells: currentCells),
      clearSelection: true,
    );
  }

  void bringToFront() {
    if (state.selectedObjectIds.isEmpty) return;
    _saveToHistory();
    final currentCells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    
    for (final key in currentCells.keys) {
      final objects = List<BoardObject>.from(currentCells[key]!);
      final selected = objects.where((o) => state.selectedObjectIds.contains(o.id)).toList();
      objects.removeWhere((o) => state.selectedObjectIds.contains(o.id));
      objects.addAll(selected);
      currentCells[key] = objects;
    }
    state = state.copyWith(whiteboard: state.whiteboard.copyWith(cells: currentCells));
  }

  void sendToBack() {
    if (state.selectedObjectIds.isEmpty) return;
    _saveToHistory();
    final currentCells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    
    for (final key in currentCells.keys) {
      final objects = List<BoardObject>.from(currentCells[key]!);
      final selected = objects.where((o) => state.selectedObjectIds.contains(o.id)).toList();
      objects.removeWhere((o) => state.selectedObjectIds.contains(o.id));
      objects.insertAll(0, selected);
      currentCells[key] = objects;
    }
    state = state.copyWith(whiteboard: state.whiteboard.copyWith(cells: currentCells));
  }

  void moveSelected(Offset delta) {
    if (state.selectedObjectIds.isEmpty) return;
    final currentCells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    final idsToMove = state.selectedObjectIds;

    // To handle re-homing during moveSelected efficiently, we gather all moving objects
    final movingObjects = <String, List<BoardObject>>{};
    
    for (final key in currentCells.keys.toList()) {
      final objects = currentCells[key]!;
      final toKeep = <BoardObject>[];
      final toMove = <BoardObject>[];
      
      for (final obj in objects) {
        if (idsToMove.contains(obj.id)) {
          toMove.add(obj);
        } else {
          toKeep.add(obj);
        }
      }
      
      if (toMove.isNotEmpty) {
        currentCells[key] = toKeep;
        if (toKeep.isEmpty) currentCells.remove(key);
        movingObjects[key] = toMove;
      }
    }

    // Now re-home them
    for (final entry in movingObjects.entries) {
      final oldKey = entry.key;
      final coords = oldKey.split(' ');
      final originX = int.parse(coords[0]) * cellSize;
      final originY = int.parse(coords[1]) * cellSize;

      for (final obj in entry.value) {
        final globalX = originX + obj.x + delta.dx;
        final globalY = originY + obj.y + delta.dy;
        
        final newKey = _getCellKey(globalX, globalY);
        final newOriginX = (globalX / cellSize).floor() * cellSize;
        final newOriginY = (globalY / cellSize).floor() * cellSize;
        
        final newObj = obj.copyWith(
          x: globalX - newOriginX,
          y: globalY - newOriginY,
        );
        
        currentCells[newKey] = [...(currentCells[newKey] ?? []), newObj];
      }
    }

    state = state.copyWith(
      whiteboard: state.whiteboard.copyWith(cells: currentCells),
    );
  }

  void endAction() {
    _saveToHistory();
  }

  void updateSelectedColor(int color) {
    if (state.selectedObjectIds.isEmpty) return;
    _saveToHistory();
    final currentCells = Map<String, List<BoardObject>>.from(state.whiteboard.cells);
    final ids = state.selectedObjectIds;

    for (final key in currentCells.keys.toList()) {
      currentCells[key] = currentCells[key]!.map((obj) {
        if (ids.contains(obj.id)) {
          if (obj is DrawingObject) return obj.copyWith(color: color);
          if (obj is TextObject) return obj.copyWith(color: color);
          if (obj is ShapeObject) return obj.copyWith(color: color);
          if (obj is LineObject) return obj.copyWith(color: color);
        }
        return obj;
      }).toList();
    }
    state = state.copyWith(whiteboard: state.whiteboard.copyWith(cells: currentCells));
  }

  void selectObject(String? id, {bool multi = false}) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
      return;
    }
    if (multi) {
      final newSelection = Set<String>.from(state.selectedObjectIds);
      if (newSelection.contains(id)) {
        newSelection.remove(id);
      } else {
        newSelection.add(id);
      }
      state = state.copyWith(selectedObjectIds: newSelection);
    } else {
      state = state.copyWith(selectedObjectIds: {id});
    }
  }

  void selectObjects(Set<String> ids) {
    state = state.copyWith(selectedObjectIds: ids);
  }

  void setWhiteboard(Whiteboard board, {bool isSaved = true}) {
    state = state.copyWith(
      whiteboard: board,
      undoHistory: [],
      redoHistory: [],
      clearSelection: true,
      hasBeenSaved: isSaved,
    );
  }

  void markAsSaved() {
    state = state.copyWith(hasBeenSaved: true);
  }

  void clearContents() {
    _saveToHistory();
    state = state.copyWith(
      whiteboard: state.whiteboard.copyWith(cells: {}),
      clearSelection: true,
    );
  }

  void clearBoard() {
    _saveToHistory();
    state = state.copyWith(
      whiteboard: Whiteboard(id: const Uuid().v4(), title: 'Untitled Board', cells: {}),
      clearSelection: true,
      hasBeenSaved: false,
    );
  }
}

final whiteboardProvider = NotifierProvider<WhiteboardNotifier, WhiteboardState>(WhiteboardNotifier.new);
