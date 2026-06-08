import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToolType { select, draw, text, image, pdf }

class ToolState {
  final ToolType toolType;
  final Color color;
  final double strokeWidth;

  ToolState({
    required this.toolType,
    required this.color,
    required this.strokeWidth,
  });

  ToolState copyWith({
    ToolType? toolType,
    Color? color,
    double? strokeWidth,
  }) =>
      ToolState(
        toolType: toolType ?? this.toolType,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
      );
}

class ToolNotifier extends Notifier<ToolState> {
  @override
  ToolState build() {
    return ToolState(
      toolType: ToolType.draw,
      color: Colors.black,
      strokeWidth: 5.0,
    );
  }

  void setTool(ToolType type) => state = state.copyWith(toolType: type);
  void setColor(Color color) => state = state.copyWith(color: color);
  void setStrokeWidth(double width) => state = state.copyWith(strokeWidth: width);
}

final toolProvider = NotifierProvider<ToolNotifier, ToolState>(ToolNotifier.new);
