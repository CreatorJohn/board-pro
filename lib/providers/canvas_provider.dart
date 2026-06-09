import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final transformationControllerProvider = Provider((ref) {
  final controller = TransformationController();
  ref.onDispose(() => controller.dispose());
  return controller;
});
