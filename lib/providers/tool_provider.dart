import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToolType { move, select, draw, line, objectEraser, pointEraser, text, image, pdf }

class ToolState {
  final ToolType toolType;
  final Color color;
  final double strokeWidth;
  final double eraserSize;

  ToolState({
    required this.toolType,
    required this.color,
    required this.strokeWidth,
    required this.eraserSize,
  });

  ToolState copyWith({
    ToolType? toolType,
    Color? color,
    double? strokeWidth,
    double? eraserSize,
  }) =>
      ToolState(
        toolType: toolType ?? this.toolType,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        eraserSize: eraserSize ?? this.eraserSize,
      );
}

class ToolNotifier extends Notifier<ToolState> {
  @override
  ToolState build() {
    return ToolState(
      toolType: ToolType.move,
      color: Colors.black,
      strokeWidth: 2.0,
      eraserSize: 5.0,
    );
  }

  void setTool(ToolType type) => state = state.copyWith(toolType: type);
  void setColor(Color color) => state = state.copyWith(color: color);
  void setStrokeWidth(double width) => state = state.copyWith(strokeWidth: width);
  void setEraserSize(double size) => state = state.copyWith(eraserSize: size);
}

final toolProvider = NotifierProvider<ToolNotifier, ToolState>(ToolNotifier.new);
