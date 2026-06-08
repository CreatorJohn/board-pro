import 'package:flutter/material.dart';

enum BoardObjectType { drawing, text, image, shape, line }
enum ShapeType { rectangle, circle, stickyNote }

abstract class BoardObject {
  final String id;
  final double x; // Relative to cell
  final double y; // Relative to cell
  final double width;
  final double height;
  final double rotation;
  final int zIndex;

  BoardObject({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    required this.zIndex,
  });

  Map<String, dynamic> toJson();
  BoardObject copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
  });

  static BoardObject fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'];
    if (typeStr == 'drawing') return DrawingObject.fromJson(json);
    if (typeStr == 'text') return TextObject.fromJson(json);
    if (typeStr == 'image') return ImageObject.fromJson(json);
    if (typeStr == 'shape') return ShapeObject.fromJson(json);
    if (typeStr == 'line') return LineObject.fromJson(json);
    throw Exception('Unknown BoardObject type: $typeStr');
  }
}

class DrawingObject extends BoardObject {
  final List<Offset> points; // Relative to object x,y
  final int color;
  final double strokeWidth;

  DrawingObject({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation,
    required super.zIndex,
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'drawing',
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'zIndex': zIndex,
        'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color,
        'strokeWidth': strokeWidth,
      };

  factory DrawingObject.fromJson(Map<String, dynamic> json) => DrawingObject(
        id: json['id'],
        x: json['x'].toDouble(),
        y: json['y'].toDouble(),
        width: json['width'].toDouble(),
        height: json['height'].toDouble(),
        rotation: (json['rotation'] ?? 0).toDouble(),
        zIndex: json['zIndex'],
        points: (json['points'] as List)
            .map((p) => Offset(p['dx'].toDouble(), p['dy'].toDouble()))
            .toList(),
        color: json['color'],
        strokeWidth: json['strokeWidth'].toDouble(),
      );

  @override
  DrawingObject copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    List<Offset>? points,
    int? color,
    double? strokeWidth,
  }) =>
      DrawingObject(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        zIndex: zIndex ?? this.zIndex,
        points: points ?? this.points,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
      );
}

class TextObject extends BoardObject {
  final String text;
  final int color;
  final double fontSize;

  TextObject({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation,
    required super.zIndex,
    required this.text,
    required this.color,
    required this.fontSize,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'text',
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'zIndex': zIndex,
        'text': text,
        'color': color,
        'fontSize': fontSize,
      };

  factory TextObject.fromJson(Map<String, dynamic> json) => TextObject(
        id: json['id'],
        x: json['x'].toDouble(),
        y: json['y'].toDouble(),
        width: json['width'].toDouble(),
        height: json['height'].toDouble(),
        rotation: (json['rotation'] ?? 0).toDouble(),
        zIndex: json['zIndex'],
        text: json['text'],
        color: json['color'],
        fontSize: json['fontSize'].toDouble(),
      );

  @override
  TextObject copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    String? text,
    int? color,
    double? fontSize,
  }) =>
      TextObject(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        zIndex: zIndex ?? this.zIndex,
        text: text ?? this.text,
        color: color ?? this.color,
        fontSize: fontSize ?? this.fontSize,
      );
}

class ShapeObject extends BoardObject {
  final ShapeType shapeType;
  final int color;
  final String? text; // For sticky notes

  ShapeObject({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation,
    required super.zIndex,
    required this.shapeType,
    required this.color,
    this.text,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'shape',
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'zIndex': zIndex,
        'shapeType': shapeType.name,
        'color': color,
        'text': text,
      };

  factory ShapeObject.fromJson(Map<String, dynamic> json) => ShapeObject(
        id: json['id'],
        x: json['x'].toDouble(),
        y: json['y'].toDouble(),
        width: json['width'].toDouble(),
        height: json['height'].toDouble(),
        rotation: (json['rotation'] ?? 0).toDouble(),
        zIndex: json['zIndex'],
        shapeType: ShapeType.values.byName(json['shapeType']),
        color: json['color'],
        text: json['text'],
      );

  @override
  ShapeObject copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    ShapeType? shapeType,
    int? color,
    String? text,
  }) =>
      ShapeObject(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        zIndex: zIndex ?? this.zIndex,
        shapeType: shapeType ?? this.shapeType,
        color: color ?? this.color,
        text: text ?? this.text,
      );
}

class LineObject extends BoardObject {
  final Offset start; // Relative to x,y
  final Offset end;   // Relative to x,y
  final int color;
  final double strokeWidth;
  final bool hasArrow;

  LineObject({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation,
    required super.zIndex,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
    this.hasArrow = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'line',
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'zIndex': zIndex,
        'start': {'dx': start.dx, 'dy': start.dy},
        'end': {'dx': end.dx, 'dy': end.dy},
        'color': color,
        'strokeWidth': strokeWidth,
        'hasArrow': hasArrow,
      };

  factory LineObject.fromJson(Map<String, dynamic> json) => LineObject(
        id: json['id'],
        x: json['x'].toDouble(),
        y: json['y'].toDouble(),
        width: json['width'].toDouble(),
        height: json['height'].toDouble(),
        rotation: (json['rotation'] ?? 0).toDouble(),
        zIndex: json['zIndex'],
        start: Offset(json['start']['dx'].toDouble(), json['start']['dy'].toDouble()),
        end: Offset(json['end']['dx'].toDouble(), json['end']['dy'].toDouble()),
        color: json['color'],
        strokeWidth: json['strokeWidth'].toDouble(),
        hasArrow: json['hasArrow'] ?? false,
      );

  @override
  LineObject copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    Offset? start,
    Offset? end,
    int? color,
    double? strokeWidth,
    bool? hasArrow,
  }) =>
      LineObject(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        zIndex: zIndex ?? this.zIndex,
        start: start ?? this.start,
        end: end ?? this.end,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        hasArrow: hasArrow ?? this.hasArrow,
      );
}

class ImageObject extends BoardObject {
  final String imagePath;

  ImageObject({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation,
    required super.zIndex,
    required this.imagePath,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'image',
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'zIndex': zIndex,
        'imagePath': imagePath,
      };

  factory ImageObject.fromJson(Map<String, dynamic> json) => ImageObject(
        id: json['id'],
        x: json['x'].toDouble(),
        y: json['y'].toDouble(),
        width: json['width'].toDouble(),
        height: json['height'].toDouble(),
        rotation: (json['rotation'] ?? 0).toDouble(),
        zIndex: json['zIndex'],
        imagePath: json['imagePath'],
      );

  @override
  ImageObject copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    String? imagePath,
  }) =>
      ImageObject(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        zIndex: zIndex ?? this.zIndex,
        imagePath: imagePath ?? this.imagePath,
      );
}

class Whiteboard {
  final String id;
  final String title;
  final Map<String, List<BoardObject>> cells; // Key: "x y"

  Whiteboard({
    required this.id,
    required this.title,
    required this.cells,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cells': cells.map((key, value) => MapEntry(key, value.map((o) => o.toJson()).toList())),
      };

  factory Whiteboard.fromJson(Map<String, dynamic> json) {
    final cellsJson = json['cells'] as Map<String, dynamic>;
    final cells = cellsJson.map((key, value) {
      return MapEntry(
        key,
        (value as List).map((o) => BoardObject.fromJson(o)).toList(),
      );
    });
    return Whiteboard(
      id: json['id'],
      title: json['title'],
      cells: cells,
    );
  }

  Whiteboard copyWith({
    String? id,
    String? title,
    Map<String, List<BoardObject>>? cells,
  }) =>
      Whiteboard(
        id: id ?? this.id,
        title: title ?? this.title,
        cells: cells ?? this.cells,
      );
}
