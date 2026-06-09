import 'dart:ui';

class Whiteboard {
  final String id;
  final String title;
  final Map<String, List<BoardObject>> cells;

  Whiteboard({
    required this.id,
    required this.title,
    required this.cells,
  });

  Whiteboard copyWith({String? id, String? title, Map<String, List<BoardObject>>? cells}) {
    return Whiteboard(
      id: id ?? this.id,
      title: title ?? this.title,
      cells: cells ?? this.cells,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cells': cells.map((k, v) => MapEntry(k, v.map((o) => o.toJson()).toList())),
  };

  factory Whiteboard.fromJson(Map<String, dynamic> json) => Whiteboard(
    id: json['id'],
    title: json['title'],
    cells: (json['cells'] as Map).map((k, v) => MapEntry(k.toString(), (v as List).map((o) => BoardObject.fromJson(o)).toList())),
  );
}

abstract class BoardObject {
  final String id;
  final double x;
  final double y;
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
    this.rotation = 0.0,
    this.zIndex = 0,
  });

  Map<String, dynamic> toJson();
  BoardObject copyWith({double? x, double? y, double? width, double? height, double? rotation, int? zIndex});

  factory BoardObject.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'drawing') return DrawingObject.fromJson(json);
    return TextObject.fromJson(json);
  }
}

class DrawingObject extends BoardObject {
  final List<Offset> points;
  final int color;
  final double strokeWidth;

  DrawingObject({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation,
    super.zIndex,
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
    x: json['x'],
    y: json['y'],
    width: json['width'],
    height: json['height'],
    rotation: json['rotation'] ?? 0.0,
    zIndex: json['zIndex'] ?? 0,
    points: (json['points'] as List).map((p) => Offset(p['dx'], p['dy'])).toList(),
    color: json['color'],
    strokeWidth: json['strokeWidth'],
  );

  @override
  DrawingObject copyWith({double? x, double? y, double? width, double? height, double? rotation, int? zIndex, List<Offset>? points, int? color, double? strokeWidth}) {
    return DrawingObject(
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
    super.zIndex,
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
    x: json['x'],
    y: json['y'],
    width: json['width'],
    height: json['height'],
    rotation: json['rotation'] ?? 0.0,
    zIndex: json['zIndex'] ?? 0,
    text: json['text'],
    color: json['color'],
    fontSize: json['fontSize'],
  );

  @override
  TextObject copyWith({double? x, double? y, double? width, double? height, double? rotation, int? zIndex, String? text, int? color, double? fontSize}) {
    return TextObject(
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
}
