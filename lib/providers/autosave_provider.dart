import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_provider.dart';
import 'whiteboard_provider.dart';

class AutoSaveNotifier extends Notifier<void> {
  Timer? _timer;

  @override
  void build() {
    ref.onDispose(() => _timer?.cancel());
  }

  void onBoardChanged(dynamic board) {
    // Only auto-save if the board has been manually saved (and thus named)
    final hasBeenSaved = ref.read(whiteboardProvider).hasBeenSaved;
    if (!hasBeenSaved) return;

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      ref.read(storageProvider.notifier).saveBoard(board);
    });
  }
}

final autoSaveProvider = NotifierProvider<AutoSaveNotifier, void>(AutoSaveNotifier.new);
