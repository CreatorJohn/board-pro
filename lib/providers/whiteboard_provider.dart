import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_objects.dart';
import 'package:uuid/uuid.dart';

class WhiteboardState {
  final Whiteboard whiteboard;
  final String? selectedObjectId;

  WhiteboardState({
    required this.whiteboard,
    this.selectedObjectId,
  });

  WhiteboardState copyWith({
    Whiteboard? whiteboard,
    String? selectedObjectId,
    bool deselect = false,
  }) =>
      WhiteboardState(
        whiteboard: whiteboard ?? this.whiteboard,
        selectedObjectId: deselect ? null : (selectedObjectId ?? this.selectedObjectId),
      );
}

class WhiteboardNotifier extends Notifier<WhiteboardState> {
  @override
  WhiteboardState build() {
    return WhiteboardState(
      whiteboard: Whiteboard(
        id: const Uuid().v4(),
        title: 'Untitled Board',
        objects: [],
      ),
    );
  }

  void addObject(BoardObject object) {
    state = state.copyWith(
      whiteboard: state.whiteboard.copyWith(
        objects: [...state.whiteboard.objects, object],
      ),
    );
  }

  void updateObject(BoardObject object) {
    state = state.copyWith(
      whiteboard: state.whiteboard.copyWith(
        objects: state.whiteboard.objects
            .map((o) => o.id == object.id ? object : o)
            .toList(),
      ),
    );
  }

  void removeObject(String id) {
    state = state.copyWith(
      whiteboard: state.whiteboard.copyWith(
        objects: state.whiteboard.objects.where((o) => o.id != id).toList(),
      ),
      selectedObjectId: state.selectedObjectId == id ? null : state.selectedObjectId,
    );
  }

  void selectObject(String? id) {
    state = state.copyWith(selectedObjectId: id, deselect: id == null);
  }

  void setWhiteboard(Whiteboard board) {
    state = WhiteboardState(whiteboard: board);
  }

  void clearBoard() {
    state = WhiteboardState(
      whiteboard: Whiteboard(
        id: const Uuid().v4(),
        title: 'Untitled Board',
        objects: [],
      ),
    );
  }
}

final whiteboardProvider =
    NotifierProvider<WhiteboardNotifier, WhiteboardState>(WhiteboardNotifier.new);
