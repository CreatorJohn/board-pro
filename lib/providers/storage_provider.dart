import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/board_objects.dart';

class StorageNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return [];
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/whiteboards';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<void> refreshBoards() async {
    final path = await _localPath;
    final dir = Directory(path);
    final files = dir.listSync();
    state = files
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.path.split('/').last.replaceAll('.json', ''))
        .toList();
  }

  Future<void> saveBoard(Whiteboard board) async {
    final path = await _localPath;
    final file = File('$path/${board.title}.json');
    await file.writeAsString(jsonEncode(board.toJson()));
    await refreshBoards();
  }

  Future<Whiteboard?> loadBoard(String title) async {
    final path = await _localPath;
    final file = File('$path/$title.json');
    if (await file.exists()) {
      final content = await file.readAsString();
      return Whiteboard.fromJson(jsonDecode(content));
    }
    return null;
  }

  Future<void> deleteBoard(String title) async {
    final path = await _localPath;
    final file = File('$path/$title.json');
    if (await file.exists()) {
      await file.delete();
    }
    await refreshBoards();
  }
}

final storageProvider =
    NotifierProvider<StorageNotifier, List<String>>(StorageNotifier.new);
