import 'dart:ui';

enum ScratchPadTemplate {
  draw,
  type,
  grid,
  craft,
  atis,
  pirep,
  takeoff,
  landing,
  holding,
}

class StrokePoint {
  final double x;
  final double y;
  final double pressure;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'p': pressure,
      };

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        pressure: (json['p'] as num?)?.toDouble() ?? 0.5,
      );
}

class Stroke {
  final List<StrokePoint> points;
  final int colorValue;
  final double strokeWidth;
  final bool isEraser;

  const Stroke({
    required this.points,
    this.colorValue = 0xFFFFFFFF,
    this.strokeWidth = 2.0,
    this.isEraser = false,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'color': colorValue,
        'width': strokeWidth,
        'eraser': isEraser,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
        points: (json['points'] as List)
            .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        colorValue: json['color'] as int? ?? 0xFFFFFFFF,
        strokeWidth: (json['width'] as num?)?.toDouble() ?? 2.0,
        isEraser: json['eraser'] as bool? ?? false,
      );
}

class ScratchPad {
  final String id;
  final ScratchPadTemplate template;
  final List<Stroke> strokes;
  final String? textContent;
  final Map<String, String>? craftHints;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;

  const ScratchPad({
    required this.id,
    required this.template,
    this.strokes = const [],
    this.textContent,
    this.craftHints,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  ScratchPad copyWith({
    List<Stroke>? strokes,
    String? textContent,
    Map<String, String>? craftHints,
    bool clearCraftHints = false,
    DateTime? updatedAt,
    int? sortOrder,
  }) =>
      ScratchPad(
        id: id,
        template: template,
        strokes: strokes ?? this.strokes,
        textContent: textContent ?? this.textContent,
        craftHints: clearCraftHints ? null : (craftHints ?? this.craftHints),
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'template': template.name,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'textContent': textContent,
        'craftHints': craftHints,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'sortOrder': sortOrder,
      };

  factory ScratchPad.fromJson(Map<String, dynamic> json) => ScratchPad(
        id: json['id'] as String,
        template: ScratchPadTemplate.values.firstWhere(
          (t) => t.name == json['template'],
          orElse: () => ScratchPadTemplate.draw,
        ),
        strokes: (json['strokes'] as List?)
                ?.map((s) => Stroke.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        textContent: json['textContent'] as String?,
        craftHints: (json['craftHints'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as String)),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        sortOrder: json['sortOrder'] as int? ?? 0,
      );
}
