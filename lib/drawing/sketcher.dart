import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'drawn_line.dart';

class Sketcher extends CustomPainter {
  final ui.Image? background;
  final ui.Image? prevDrawing;
  final List<dynamic> lines;
  final DrawnLine? erase;

  Sketcher({
    this.background,
    this.prevDrawing,
    this.lines = const [],
    this.erase,
  });

  @override
  void paint(Canvas canvas, Size size) {

    _addBackground(ui.Image background, {double scale = 1.0}) {
      final width = background.width * scale;
      final height = background.height * scale;

      final left = (size.width - width) / 2.0;
      final top = (size.height - height) / 2.0;

      // var recorder = ui.PictureRecorder();
      // var imageCanvas = new Canvas(recorder);
      // var painter = _MarkupPainter(_overlays);

      // Paint the image into a rectangle that matches the requested width/height.
      // This will handle rescaling the image into the rectangle so that it will not be clipped.
      paintImage(
        canvas: canvas, 
        rect: Rect.fromLTWH(left, top, width, height),
        image: background,
        fit: BoxFit.scaleDown,
        repeat: ImageRepeat.noRepeat,
        scale: 1.0,
        alignment: Alignment.center,
        flipHorizontally: false,
        filterQuality: FilterQuality.high
      );

      // Add the markup overlays.
      // painter.paint(canvas, Size(width, height));
      // var picture = recorder.endRecording();
      // return picture.toImage(width.toInt(), height.toInt());
    }

    _addText(DrawnText text) {
      final span = TextSpan(style: TextStyle(color: text.color, fontSize: text.size, fontWeight: FontWeight.bold), text: text.text);
      final tp = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr)..layout(
        minWidth: 0,
        maxWidth: size.width,
      );
      text.offset ??= Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2
      );
      tp.paint(canvas, text.offset!);
    }

    // add background
    if (background != null) {
      // canvas.drawImage(background!, Offset.zero, Paint());
      final scale = min(size.width / background!.width, size.height / background!.height);
      _addBackground(background!, scale: scale);
      canvas.saveLayer(null, Paint());
    }

    // add previous drawing
    if (prevDrawing != null) {
      _addBackground(prevDrawing!);
    }

    Paint paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < lines.length; ++i) {
      final line = lines[i];
      if (line is DrawnLine) {
        for (int j = 0; j < line.path.length - 1; ++j) {
          if (line.path[j] != null && line.path[j + 1] != null) {
            final p1 = line.path[j]!;
            final p2 = line.path[j + 1]!;
            paint.color = line.color;
            paint.strokeWidth = line.width;
            paint.blendMode = line.isEraser ? BlendMode.clear : BlendMode.srcOver;
            canvas.drawLine(p1, p2, paint);
          }
        }
      } else if (line is DrawnText) {
        _addText(line);
      }
    }
  }

  @override
  bool shouldRepaint(Sketcher oldDelegate) {
    return true;
  }
}
