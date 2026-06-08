import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/whiteboard_canvas.dart';
import 'widgets/toolbar.dart';
import 'widgets/zoom_controls.dart';
import 'widgets/context_menu.dart';
import 'providers/whiteboard_provider.dart';
import 'providers/autosave_provider.dart';
import 'providers/canvas_provider.dart';
import 'providers/storage_provider.dart';
import 'models/board_objects.dart';

final canvasKeyProvider = Provider((ref) => GlobalKey());

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Whiteboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MenuPage(),
    );
  }
}

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(storageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Whiteboards'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildNewBoardCard(context, ref),
              const SizedBox(height: 32),
              const Text(
                'Recent Boards',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: boards.isEmpty
                    ? const Center(child: Text('No saved boards yet.'))
                    : ListView.builder(
                        itemCount: boards.length,
                        itemBuilder: (context, index) {
                          return _buildBoardTile(context, ref, boards[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewBoardCard(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _createNewBoard(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.add_circle_outline, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Create New Whiteboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoardTile(BuildContext context, WidgetRef ref, String title) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.dashboard_outlined),
        title: Text(title),
        onTap: () => _openBoard(context, ref, title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _renameBoard(context, ref, title),
              tooltip: 'Rename',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteBoard(context, ref, title),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewBoard(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Whiteboard'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter board title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (title != null && title.isNotEmpty) {
      final newBoard = Whiteboard(
        title: title,
        objectsByCell: {},
        version: 1,
      );
      ref.read(whiteboardProvider.notifier).setWhiteboard(newBoard);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WhiteboardPage()),
      );
    }
  }

  Future<void> _openBoard(BuildContext context, WidgetRef ref, String title) async {
    final board = await ref.read(storageProvider.notifier).loadBoard(title);
    if (board != null) {
      ref.read(whiteboardProvider.notifier).setWhiteboard(board);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WhiteboardPage()),
      );
    }
  }

  Future<void> _renameBoard(BuildContext context, WidgetRef ref, String title) async {
    final controller = TextEditingController(text: title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Whiteboard'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != title) {
      await ref.read(storageProvider.notifier).renameBoard(title, newTitle);
    }
  }

  Future<void> _deleteBoard(BuildContext context, WidgetRef ref, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Whiteboard'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(storageProvider.notifier).deleteBoard(title);
    }
  }
}

class WhiteboardPage extends ConsumerWidget {
  const WhiteboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasKey = ref.watch(canvasKeyProvider);
    
    // Setup auto-save listener
    ref.listen(whiteboardProvider, (previous, next) {
      if (previous?.whiteboard != next.whiteboard) {
        ref.read(autoSaveProvider.notifier).onBoardChanged(next.whiteboard);
      }
    });

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): const UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): const RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): const RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.delete): const DeleteIntent(),
        const SingleActivator(LogicalKeyboardKey.backspace): const DeleteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): const BringToFrontIntent(),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): const SendToBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (UndoIntent intent) => ref.read(whiteboardProvider.notifier).undo(),
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (RedoIntent intent) => ref.read(whiteboardProvider.notifier).redo(),
          ),
          DeleteIntent: CallbackAction<DeleteIntent>(
            onInvoke: (DeleteIntent intent) => ref.read(whiteboardProvider.notifier).removeSelected(),
          ),
          BringToFrontIntent: CallbackAction<BringToFrontIntent>(
            onInvoke: (BringToFrontIntent intent) => ref.read(whiteboardProvider.notifier).bringToFront(),
          ),
          SendToBackIntent: CallbackAction<SendToBackIntent>(
            onInvoke: (SendToBackIntent intent) => ref.read(whiteboardProvider.notifier).sendToBack(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                RepaintBoundary(
                  key: canvasKey,
                  child: const WhiteboardCanvas(),
                ),
                
                // Back to Menu Button
                Positioned(
                  left: 20,
                  top: 20,
                  child: FloatingActionButton.small(
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back),
                    tooltip: 'Back to Menu',
                  ),
                ),

                // Centered Floating Toolbar (Bottom Center)
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: WhiteboardToolbar(),
                  ),
                ),

                // Zoom Controls & Home Button (Bottom Right)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        tooltip: 'Center View',
                        onPressed: () {
                          const virtualSize = 100000.0;
                          const initialOffset = Offset(virtualSize / 2, virtualSize / 2);
                          ref.read(transformationControllerProvider).value = Matrix4.translationValues(
                            -initialOffset.dx,
                            -initialOffset.dy,
                            0,
                          );
                        },
                        child: const Icon(Icons.home),
                      ),
                      const SizedBox(width: 12),
                      const ZoomControls(),
                    ],
                  ),
                ),

                // Object Context Menu (Top Center)
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: ObjectContextMenu(),
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

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

class BringToFrontIntent extends Intent {
  const BringToFrontIntent();
}

class SendToBackIntent extends Intent {
  const SendToBackIntent();
}
