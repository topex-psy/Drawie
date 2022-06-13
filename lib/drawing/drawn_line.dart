import 'package:flutter/material.dart';

class DrawnLine {
  final List<Offset?> path;
  final Color color;
  final double width;
  final double zoom;
  final double panX;
  final double panY;
  bool isEraser;

  DrawnLine(this.path, this.color, this.width, {this.zoom = 1.0, this.panX = 0.0, this.panY = 0.0, this.isEraser = false});

  @override
  String toString() => "DrawnLine ($color/$width)${isEraser ? ' (eraser)' : ''}";
}

class DrawnText {
  final String text;
  Color? color;
  double? size;
  Offset? offset;
  final double zoom;

  DrawnText(this.text, {this.zoom = 1.0, this.color, this.size, this.offset});
}
