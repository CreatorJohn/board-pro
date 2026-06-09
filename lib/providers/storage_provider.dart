import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board_objects.dart';

class StorageNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    refreshBoards();
    return [];
  }

  Future<void> refreshBoards() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('board_')).toList();
    state = keys.map((k) => k.replaceFirst('board_', '')).toList();
  }

  Future<void> saveBoard(Whiteboard board) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('board_${board.title}', jsonEncode(board.toJson()));
    await refreshBoards();
  }

  Future<Whiteboard?> loadBoard(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString('board_$title');
    if (content != null) {
      return Whiteboard.fromJson(jsonDecode(content));
    }
    return null;
  }

  Future<void> deleteBoard(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('board_$title');
    await refreshBoards();
  }

  Future<void> renameBoard(String oldTitle, String newTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString('board_$oldTitle');
    if (content != null) {
      final boardMap = jsonDecode(content) as Map<String, dynamic>;
      boardMap['title'] = newTitle;
      
      await prefs.setString('board_$newTitle', jsonEncode(boardMap));
      await prefs.remove('board_$oldTitle');
    }
    await refreshBoards();
  }
}

final storageProvider =
    NotifierProvider<StorageNotifier, List<String>>(StorageNotifier.new);
