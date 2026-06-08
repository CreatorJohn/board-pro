import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/tool_provider.dart';
import '../providers/whiteboard_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/canvas_provider.dart';
import '../models/board_objects.dart';

class WhiteboardToolbar extends ConsumerWidget {
  const WhiteboardToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolState = ref.watch(toolProvider);
    final whiteboard = ref.watch(whiteboardProvider).whiteboard;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildToolButton(context, ref, ToolType.select, Icons.near_me, 'Select'),
            _buildToolButton(context, ref, ToolType.draw, Icons.edit, 'Draw'),
            _buildToolButton(context, ref, ToolType.text, Icons.text_fields, 'Text'),
            _buildToolButton(context, ref, ToolType.image, Icons.image, 'Image'),
            _buildToolButton(context, ref, ToolType.pdf, Icons.picture_as_pdf, 'PDF'),
            const VerticalDivider(),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                ref.read(transformationControllerProvider).value = Matrix4.identity();
              },
              tooltip: 'Home',
            ),
            const VerticalDivider(),
            _buildColorPicker(ref, toolState.color),
            _buildStrokeWidthPicker(ref, toolState.strokeWidth),
            const VerticalDivider(),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _showSaveDialog(context, ref, whiteboard),
              tooltip: 'Save Board',
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () => _showLoadDialog(context, ref),
              tooltip: 'Load Board',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => ref.read(whiteboardProvider.notifier).clearBoard(),
              tooltip: 'Clear Board',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(BuildContext context, WidgetRef ref, ToolType type, IconData icon, String tooltip) {
    final currentType = ref.watch(toolProvider).toolType;
    final isSelected = currentType == type;

    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.blue : Colors.black),
      onPressed: () async {
        ref.read(toolProvider.notifier).setTool(type);
        if (type == ToolType.text) {
          _addText(context, ref);
        } else if (type == ToolType.image) {
          _pickImage(ref);
        } else if (type == ToolType.pdf) {
          _pickPdf(ref);
        }
      },
      tooltip: tooltip,
    );
  }

  Widget _buildColorPicker(WidgetRef ref, Color currentColor) {
    final colors = [Colors.black, Colors.red, Colors.green, Colors.blue, Colors.yellow];
    return Row(
      children: colors.map((color) {
        return GestureDetector(
          onTap: () => ref.read(toolProvider.notifier).setColor(color),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: currentColor == color ? Colors.white : Colors.transparent,
                width: 2,
              ),
              boxShadow: const [BoxShadow(blurRadius: 2)],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStrokeWidthPicker(WidgetRef ref, double currentWidth) {
    return PopupMenuButton<double>(
      icon: const Icon(Icons.line_weight),
      onSelected: (width) => ref.read(toolProvider.notifier).setStrokeWidth(width),
      itemBuilder: (context) => [2.0, 5.0, 10.0, 20.0].map((width) {
        return PopupMenuItem(
          value: width,
          child: Text('${width.toInt()}px'),
        );
      }).toList(),
    );
  }

  Future<void> _addText(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Type something...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (text != null && text.isNotEmpty) {
      final textObj = TextObject(
        id: const Uuid().v4(),
        x: 100,
        y: 100,
        width: 200,
        height: 50,
        zIndex: ref.read(whiteboardProvider).whiteboard.objects.length,
        text: text,
        color: ref.read(toolProvider).color.toARGB32(),
        fontSize: 20,
      );
      ref.read(whiteboardProvider.notifier).addObject(textObj);
    }
  }

  Future<void> _pickImage(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final imageObj = ImageObject(
        id: const Uuid().v4(),
        x: 50,
        y: 50,
        width: 300,
        height: 300,
        zIndex: ref.read(whiteboardProvider).whiteboard.objects.length,
        imagePath: path,
      );
      ref.read(whiteboardProvider.notifier).addObject(imageObj);
    }
  }

  Future<void> _pickPdf(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final document = await PdfDocument.openFile(path);
      final tempDir = await getTemporaryDirectory();

      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        
        if (pageImage != null) {
          final imageFile = File('${tempDir.path}/pdf_page_${const Uuid().v4()}.png');
          await imageFile.writeAsBytes(pageImage.bytes);

          final imageObj = ImageObject(
            id: const Uuid().v4(),
            x: 50.0 + (i * 20),
            y: 50.0 + (i * 20),
            width: page.width,
            height: page.height,
            zIndex: ref.read(whiteboardProvider).whiteboard.objects.length,
            imagePath: imageFile.path,
          );
          ref.read(whiteboardProvider.notifier).addObject(imageObj);
        }
        await page.close();
      }
      await document.close();
    }
  }

  void _showSaveDialog(BuildContext context, WidgetRef ref, Whiteboard board) {
    final controller = TextEditingController(text: board.title);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Board'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Board Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newBoard = board.copyWith(title: controller.text);
              ref.read(whiteboardProvider.notifier).setWhiteboard(newBoard);
              await ref.read(storageProvider.notifier).saveBoard(newBoard);
              if (context.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLoadDialog(BuildContext context, WidgetRef ref) {
    ref.read(storageProvider.notifier).refreshBoards();
    showDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          final boards = ref.watch(storageProvider);
          return AlertDialog(
            title: const Text('Load Board'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: boards.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(boards[index]),
                    onTap: () async {
                      final board = await ref.read(storageProvider.notifier).loadBoard(boards[index]);
                      if (board != null) {
                        ref.read(whiteboardProvider.notifier).setWhiteboard(board);
                      }
                      if (context.mounted) Navigator.pop(dialogContext);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => ref.read(storageProvider.notifier).deleteBoard(boards[index]),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
