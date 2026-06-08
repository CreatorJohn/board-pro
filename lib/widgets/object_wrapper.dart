import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_objects.dart';
import '../providers/whiteboard_provider.dart';
import '../providers/tool_provider.dart';

class ObjectWrapper extends ConsumerWidget {
  final BoardObject object;
  final Widget child;

  const ObjectWrapper({
    super.key,
    required this.object,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whiteboardState = ref.watch(whiteboardProvider);
    final isSelected = whiteboardState.selectedObjectId == object.id;
    final toolState = ref.watch(toolProvider);

    return Positioned(
      left: object.x,
      top: object.y,
      width: object.width,
      height: object.height,
      child: GestureDetector(
        onTap: () {
          if (toolState.toolType == ToolType.select) {
            ref.read(whiteboardProvider.notifier).selectObject(object.id);
          }
        },
        onPanUpdate: (details) {
          if (isSelected && toolState.toolType == ToolType.select) {
            ref.read(whiteboardProvider.notifier).updateObject(
                  object.copyWith(
                    x: object.x + details.delta.dx,
                    y: object.y + details.delta.dy,
                  ),
                );
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
              if (isSelected) _buildDeleteButton(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResizeHandles(BuildContext context, WidgetRef ref) {
    const handleSize = 10.0;
    return [
      // Bottom Right
      Positioned(
        right: -handleSize / 2,
        bottom: -handleSize / 2,
        child: GestureDetector(
          onPanUpdate: (details) {
            ref.read(whiteboardProvider.notifier).updateObject(
                  object.copyWith(
                    width: (object.width + details.delta.dx).clamp(20.0, 2000.0),
                    height: (object.height + details.delta.dy).clamp(20.0, 2000.0),
                  ),
                );
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ];
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
