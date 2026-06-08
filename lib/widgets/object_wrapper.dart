import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_objects.dart';
import '../providers/whiteboard_provider.dart';
import '../providers/tool_provider.dart';

class ObjectWrapper extends ConsumerWidget {
  final BoardObject object;
  final String cellKey;
  final Widget child;

  const ObjectWrapper({
    super.key,
    required this.object,
    required this.cellKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whiteboardState = ref.watch(whiteboardProvider);
    final isSelected = whiteboardState.selectedObjectIds.contains(object.id);
    final toolState = ref.watch(toolProvider);

    return Positioned(
      left: object.x,
      top: object.y,
      width: object.width,
      height: object.height,
      child: Transform.rotate(
        angle: object.rotation,
        child: GestureDetector(
          onTapDown: (details) {
            if (toolState.toolType == ToolType.select) {
              final multi = HardwareKeyboard.instance.isShiftPressed;
              ref.read(whiteboardProvider.notifier).selectObject(object.id, multi: multi);
            }
          },
          onDoubleTap: () => _editObject(context, ref),
          onPanUpdate: (details) {
            if (isSelected && toolState.toolType == ToolType.select) {
              ref.read(whiteboardProvider.notifier).moveSelected(details.delta);
            }
          },
          onPanEnd: (details) {
            if (isSelected && toolState.toolType == ToolType.select) {
              ref.read(whiteboardProvider.notifier).endAction();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                child,
                if (isSelected) ..._buildResizeHandles(context, ref),
                if (isSelected) _buildRotationHandle(context, ref),
                if (isSelected) _buildDeleteButton(context, ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotationHandle(BuildContext context, WidgetRef ref) {
    const handleSize = 20.0;
    return Positioned(
      top: -30,
      left: (object.width / 2) - (handleSize / 2),
      child: GestureDetector(
        onPanUpdate: (details) {
          // Simple rotation logic for now
          final newRotation = object.rotation + (details.delta.dx * 0.02);
          ref.read(whiteboardProvider.notifier).updateObject(cellKey, object.copyWith(rotation: newRotation));
        },
        onPanEnd: (_) => ref.read(whiteboardProvider.notifier).endAction(),
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          child: const Icon(Icons.rotate_right, size: 14, color: Colors.white),
        ),
      ),
    );
  }

  void _editObject(BuildContext context, WidgetRef ref) async {
    String? currentText;
    if (object is TextObject) {
      currentText = (object as TextObject).text;
    } else if (object is ShapeObject && (object as ShapeObject).shapeType == ShapeType.stickyNote) {
      currentText = (object as ShapeObject).text;
    }

    if (currentText == null) return;

    final controller = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Text'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Update')),
        ],
      ),
    );

    if (newText != null) {
      if (object is TextObject) {
        ref.read(whiteboardProvider.notifier).updateObject(cellKey, (object as TextObject).copyWith(text: newText));
      } else if (object is ShapeObject) {
        ref.read(whiteboardProvider.notifier).updateObject(cellKey, (object as ShapeObject).copyWith(text: newText));
      }
    }
  }

  List<Widget> _buildResizeHandles(BuildContext context, WidgetRef ref) {
    const handleSize = 10.0;
    return [
      // Top Left
      _buildResizeHandle(ref, handleSize, top: -handleSize / 2, left: -handleSize / 2, onResize: (delta) {
        ref.read(whiteboardProvider.notifier).updateObject(cellKey, object.copyWith(
          x: object.x + delta.dx,
          y: object.y + delta.dy,
          width: (object.width - delta.dx).clamp(20.0, 5000.0),
          height: (object.height - delta.dy).clamp(20.0, 5000.0),
        ));
      }),
      // Top Right
      _buildResizeHandle(ref, handleSize, top: -handleSize / 2, right: -handleSize / 2, onResize: (delta) {
        ref.read(whiteboardProvider.notifier).updateObject(cellKey, object.copyWith(
          y: object.y + delta.dy,
          width: (object.width + delta.dx).clamp(20.0, 5000.0),
          height: (object.height - delta.dy).clamp(20.0, 5000.0),
        ));
      }),
      // Bottom Left
      _buildResizeHandle(ref, handleSize, bottom: -handleSize / 2, left: -handleSize / 2, onResize: (delta) {
        ref.read(whiteboardProvider.notifier).updateObject(cellKey, object.copyWith(
          x: object.x + delta.dx,
          width: (object.width - delta.dx).clamp(20.0, 5000.0),
          height: (object.height + delta.dy).clamp(20.0, 5000.0),
        ));
      }),
      // Bottom Right
      _buildResizeHandle(ref, handleSize, bottom: -handleSize / 2, right: -handleSize / 2, onResize: (delta) {
        ref.read(whiteboardProvider.notifier).updateObject(cellKey, object.copyWith(
          width: (object.width + delta.dx).clamp(20.0, 5000.0),
          height: (object.height + delta.dy).clamp(20.0, 5000.0),
        ));
      }),
    ];
  }

  Widget _buildResizeHandle(WidgetRef ref, double size, {double? top, double? left, double? right, double? bottom, required Function(Offset) onResize}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: GestureDetector(
        onPanUpdate: (details) => onResize(details.delta),
        onPanEnd: (_) => ref.read(whiteboardProvider.notifier).endAction(),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context, WidgetRef ref) {
    return Positioned(
      right: -15,
      top: -15,
      child: GestureDetector(
        onTap: () {
          ref.read(whiteboardProvider.notifier).removeObject(object.id);
        },
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}
