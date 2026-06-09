import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/tool_provider.dart';
import '../providers/whiteboard_provider.dart';
import '../providers/storage_provider.dart';
import '../models/board_objects.dart';
import '../main.dart';

enum ToolbarCategory { none, draw, insert, file, eraser }

class ActiveCategoryNotifier extends Notifier<ToolbarCategory> {
  @override
  ToolbarCategory build() => ToolbarCategory.none;
  void set(ToolbarCategory category) => state = (state == category) ? ToolbarCategory.none : category;
}

final activeCategoryProvider = NotifierProvider<ActiveCategoryNotifier, ToolbarCategory>(ActiveCategoryNotifier.new);

class WhiteboardToolbar extends ConsumerWidget {
  const WhiteboardToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCategory = ref.watch(activeCategoryProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Category Sub-panels
        if (activeCategory == ToolbarCategory.draw) const DrawSubPanel(),
        if (activeCategory == ToolbarCategory.insert) const InsertSubPanel(),
        if (activeCategory == ToolbarCategory.file) const FileSubPanel(),
        if (activeCategory == ToolbarCategory.eraser) const EraserSubPanel(),
        const SizedBox(height: 12),
        
        // Main Horizontal Bar
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToolButton(ref, ToolType.select, Icons.near_me, 'Select'),
                _buildToolButton(ref, ToolType.move, Icons.open_with, 'Move'),
                const SizedBox(
                  height: 30,
                  child: VerticalDivider(width: 20),
                ),
                _buildCategoryButton(ref, ToolbarCategory.draw, Icons.edit, 'Draw Tools'),
                _buildCategoryButton(ref, ToolbarCategory.insert, Icons.add_box_outlined, 'Insert'),
                _buildCategoryButton(ref, ToolbarCategory.eraser, Icons.auto_fix_normal, 'Eraser'),
                const SizedBox(
                  height: 30,
                  child: VerticalDivider(width: 20),
                ),
                _buildCategoryButton(ref, ToolbarCategory.file, Icons.folder_open, 'File'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolButton(WidgetRef ref, ToolType type, IconData icon, String tooltip) {
    final currentType = ref.watch(toolProvider).toolType;
    final isSelected = currentType == type;

    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.blue : Colors.black),
      onPressed: () {
        ref.read(toolProvider.notifier).setTool(type);
        ref.read(activeCategoryProvider.notifier).set(ToolbarCategory.none);
      },
      tooltip: tooltip,
    );
  }

  Widget _buildCategoryButton(WidgetRef ref, ToolbarCategory category, IconData icon, String tooltip) {
    final activeCategory = ref.watch(activeCategoryProvider);
    final isSelected = activeCategory == category;

    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.blue : Colors.black54),
      onPressed: () {
        ref.read(activeCategoryProvider.notifier).set(category);
      },
      tooltip: tooltip,
    );
  }
}

class DrawSubPanel extends ConsumerWidget {
  const DrawSubPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolState = ref.watch(toolProvider);
    return _SubPanelWrapper(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToolItem(ref, ToolType.draw, Icons.gesture, 'Freehand'),
              _buildToolItem(ref, ToolType.line, Icons.trending_flat, 'Arrow'),
              _buildShapeMenu(context, ref),
            ],
          ),
          const Divider(),
          const Text('Stroke Width', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Slider(
            value: toolState.strokeWidth,
            min: 1.0,
            max: 20.0,
            onChanged: (v) => ref.read(toolProvider.notifier).setStrokeWidth(v),
          ),
          const Text('Color', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          _ColorPicker(onSelected: (c) => ref.read(toolProvider.notifier).setColor(c), selected: toolState.color),
        ],
      ),
    );
  }

  Widget _buildToolItem(WidgetRef ref, ToolType type, IconData icon, String label) {
    final isSelected = ref.watch(toolProvider).toolType == type;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.blue : Colors.black),
      onPressed: () => ref.read(toolProvider.notifier).setTool(type),
      tooltip: label,
    );
  }

  Widget _buildShapeMenu(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<ShapeType>(
      icon: const Icon(Icons.category_outlined),
      tooltip: 'Shapes',
      onSelected: (type) => _addShape(context, ref, type),
      itemBuilder: (context) => [
        const PopupMenuItem(value: ShapeType.rectangle, child: Row(children: [Icon(Icons.rectangle_outlined), SizedBox(width: 8), Text('Rectangle')])),
        const PopupMenuItem(value: ShapeType.circle, child: Row(children: [Icon(Icons.circle_outlined), SizedBox(width: 8), Text('Circle')])),
        const PopupMenuItem(value: ShapeType.stickyNote, child: Row(children: [Icon(Icons.note), SizedBox(width: 8), Text('Sticky Note')])),
      ],
    );
  }

  Future<void> _addShape(BuildContext context, WidgetRef ref, ShapeType type) async {
    String? initialText;
    if (type == ShapeType.stickyNote) {
       final controller = TextEditingController();
       initialText = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sticky Note Text'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
          ],
        ),
      );
      if (initialText == null) return;
    }

    final shapeObj = ShapeObject(
      id: const Uuid().v4(),
      x: 100, y: 100, width: 150, height: 150, zIndex: 0,
      shapeType: type,
      color: type == ShapeType.stickyNote ? Colors.yellow[200]!.toARGB32() : Colors.blue.toARGB32(),
      text: initialText,
    );
    ref.read(whiteboardProvider.notifier).addObject("0 0", shapeObj);
  }
}

class InsertSubPanel extends ConsumerWidget {
  const InsertSubPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SubPanelWrapper(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(ref, Icons.text_fields, 'Text', () => _addText(context, ref)),
          _buildActionButton(ref, Icons.image, 'Image', () => _pickImage(ref)),
        ],
      ),
    );
  }

  Widget _buildActionButton(WidgetRef ref, IconData icon, String label, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      tooltip: label,
    );
  }

  Future<void> _addText(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Text'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      final textObj = TextObject(
        id: const Uuid().v4(),
        x: 100, y: 100, width: 200, height: 50, zIndex: 0,
        text: text,
        color: ref.read(toolProvider).color.toARGB32(),
        fontSize: 20,
      );
      ref.read(whiteboardProvider.notifier).addObject("0 0", textObj);
    }
  }

  Future<void> _pickImage(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final imageObj = ImageObject(
        id: const Uuid().v4(),
        x: 50, y: 50, width: 300, height: 300, zIndex: 0,
        imagePath: result.files.single.path!,
      );
      ref.read(whiteboardProvider.notifier).addObject("0 0", imageObj);
    }
  }
}

class FileSubPanel extends ConsumerWidget {
  const FileSubPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SubPanelWrapper(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.save), onPressed: () => _showSaveDialog(context, ref), tooltip: 'Save'),
          IconButton(icon: const Icon(Icons.folder_open), onPressed: () => _showLoadDialog(context, ref), tooltip: 'Load'),
          IconButton(icon: const Icon(Icons.download), onPressed: () => _showExportDialog(context, ref), tooltip: 'Export'),
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: () => ref.read(whiteboardProvider.notifier).clearBoard(), tooltip: 'Clear Board'),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: 'board_${DateTime.now().millisecondsSinceEpoch}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a filename and select a format:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Filename',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final fileName = controller.text.trim();
              Navigator.pop(ctx);
              _export(context, ref, isPdf: false, fileName: fileName.isEmpty ? null : fileName);
            },
            child: const Text('PNG Image'),
          ),
          TextButton(
            onPressed: () {
              final fileName = controller.text.trim();
              Navigator.pop(ctx);
              _export(context, ref, isPdf: true, fileName: fileName.isEmpty ? null : fileName);
            },
            child: const Text('PDF Document'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref, {required bool isPdf, String? fileName}) async {
    try {
      final canvasKey = ref.read(canvasKeyProvider);
      final boundary = canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting not fully supported on Web yet.')));
        }
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final finalName = fileName ?? 'board_${DateTime.now().millisecondsSinceEpoch}';
      late File file;

      if (isPdf) {
        final pdf = pw.Document();
        final pdfImage = pw.MemoryImage(pngBytes);
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(pdfImage));
          },
        ));
        file = File('${directory.path}/$finalName.pdf');
        await file.writeAsBytes(await pdf.save());
      } else {
        file = File('${directory.path}/$finalName.png');
        await file.writeAsBytes(pngBytes);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showSaveDialog(BuildContext context, WidgetRef ref) {
    final board = ref.read(whiteboardProvider).whiteboard;
    final controller = TextEditingController(text: board.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Board'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Board Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isEmpty) return;

              final oldTitle = board.title;
              if (newTitle != oldTitle) {
                // If title changed, rename the file (which handles deletion of old one)
                await ref.read(storageProvider.notifier).renameBoard(oldTitle, newTitle);
                final updatedBoard = board.copyWith(title: newTitle);
                ref.read(whiteboardProvider.notifier).setWhiteboard(updatedBoard, isSaved: true);
              } else {
                // Same title, just save
                await ref.read(storageProvider.notifier).saveBoard(board);
                ref.read(whiteboardProvider.notifier).markAsSaved();
              }
              
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Board saved as "$newTitle"')),
                );
              }
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
      builder: (ctx) => Consumer(
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
                      if (board != null) ref.read(whiteboardProvider.notifier).setWhiteboard(board);
                      if (context.mounted) Navigator.pop(ctx);
                    },
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

class EraserSubPanel extends ConsumerWidget {
  const EraserSubPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolState = ref.watch(toolProvider);
    return _SubPanelWrapper(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEraserItem(ref, ToolType.objectEraser, Icons.delete_outline, 'Object'),
              _buildEraserItem(ref, ToolType.pointEraser, Icons.cleaning_services, 'Point'),
            ],
          ),
          const Divider(),
          const Text('Eraser Size', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Slider(
            value: toolState.eraserSize,
            min: 2.0,
            max: 50.0,
            onChanged: (v) => ref.read(toolProvider.notifier).setEraserSize(v),
          ),
        ],
      ),
    );
  }

  Widget _buildEraserItem(WidgetRef ref, ToolType type, IconData icon, String label) {
    final isSelected = ref.watch(toolProvider).toolType == type;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.blue : Colors.black),
      onPressed: () => ref.read(toolProvider.notifier).setTool(type),
      tooltip: label,
    );
  }
}

class _SubPanelWrapper extends StatelessWidget {
  final Widget child;
  const _SubPanelWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: child,
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final Function(Color) onSelected;
  final Color selected;
  const _ColorPicker({required this.onSelected, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.black, Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.purple];
    return Wrap(
      spacing: 8,
      children: colors.map((c) => GestureDetector(
        onTap: () => onSelected(c),
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: c, shape: BoxShape.circle,
            border: Border.all(color: selected == c ? Colors.blue : Colors.grey, width: selected == c ? 2 : 1),
          ),
        ),
      )).toList(),
    );
  }
}
