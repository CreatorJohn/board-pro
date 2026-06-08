import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/whiteboard_provider.dart';

class ObjectContextMenu extends ConsumerWidget {
  const ObjectContextMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whiteboardState = ref.watch(whiteboardProvider);
    if (whiteboardState.selectedObjectIds.isEmpty) return const SizedBox.shrink();

    final colors = [Colors.black, Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.purple];

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...colors.map((color) {
              return GestureDetector(
                onTap: () => ref.read(whiteboardProvider.notifier).updateSelectedColor(color.toARGB32()),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
              );
            }),
            const VerticalDivider(),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => ref.read(whiteboardProvider.notifier).removeSelected(),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
