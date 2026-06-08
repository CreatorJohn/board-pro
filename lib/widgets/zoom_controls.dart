import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/canvas_provider.dart';

class ZoomControls extends ConsumerWidget {
  const ZoomControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(transformationControllerProvider);
    
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final scale = controller.value.getMaxScaleOnAxis();
        final percent = (scale * 100).toInt();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: () => _zoom(ref, controller, 0.8),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _zoom(ref, controller, 1.25),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _zoom(WidgetRef ref, TransformationController controller, double factor) {
    final matrix = controller.value.clone();
    final currentScale = matrix.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.1, 5.0);
    final actualFactor = newScale / currentScale;

    matrix.scaleByDouble(actualFactor, actualFactor, 1.0, 1.0);
    controller.value = matrix;
  }
}
