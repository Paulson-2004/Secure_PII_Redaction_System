class ManualRegion {
  final int id;
  final int page;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? action;

  ManualRegion({
    required this.id,
    this.page = 1,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.action,
  });

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'x': double.parse(x.toStringAsFixed(4)),
      'y': double.parse(y.toStringAsFixed(4)),
      'width': double.parse(width.toStringAsFixed(4)),
      'height': double.parse(height.toStringAsFixed(4)),
      if (action != null && action!.isNotEmpty) 'action': action,
    };
  }

  factory ManualRegion.fromJson(Map<String, dynamic> json, {int id = 1}) {
    return ManualRegion(
      id: id,
      page: (json['page'] as num?)?.toInt() ?? 1,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.1,
      height: (json['height'] as num?)?.toDouble() ?? 0.1,
      action: json['action'] as String?,
    );
  }
}
