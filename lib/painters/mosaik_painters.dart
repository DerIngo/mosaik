import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/models.dart';

class MosaikPainter extends CustomPainter {
  final ui.Image original;
  final ui.Image? effectImage;
  final List<PathData> paths;
  final FilterType filterType;

  MosaikPainter({
    required this.original,
    required this.effectImage,
    required this.paths,
    required this.filterType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(original, Offset.zero, Paint());

    if (paths.isEmpty) return;

    canvas.saveLayer(Offset.zero & size, Paint());

    for (var pathData in paths) {
      if (pathData.points.isEmpty) continue;

      Paint pathPaint = Paint()
        ..strokeWidth = pathData.brushSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (pathData.mode == ToolMode.erase) {
        pathPaint.blendMode = BlendMode.clear;
      } else {
        pathPaint.color = Colors.black;
      }

      if (pathData.points.length == 1) {
        canvas.drawCircle(
          pathData.points.first,
          pathData.brushSize / 2,
          pathPaint..style = PaintingStyle.fill,
        );
      } else {
        Path maskPath = Path();
        maskPath.moveTo(pathData.points.first.dx, pathData.points.first.dy);
        for (int i = 1; i < pathData.points.length; i++) {
          maskPath.lineTo(pathData.points[i].dx, pathData.points[i].dy);
        }
        canvas.drawPath(maskPath, pathPaint);
      }
    }

    Paint compositePaint = Paint()..blendMode = BlendMode.srcIn;

    if (filterType == FilterType.solidColor) {
      canvas.drawRect(
        Offset.zero & size,
        compositePaint..color = const Color(0xFF1E1E1E),
      );
    } else if (effectImage != null) {
      canvas.drawImage(effectImage!, Offset.zero, compositePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MosaikPainter oldDelegate) {
    return true;
  }
}

Paint getOpacityPaint(double opacity) {
  return Paint()
    ..colorFilter = ui.ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, opacity, 0,
    ]);
}

class BoxBlurPainter extends CustomPainter {
  final ui.Image original;
  final double intensity;

  BoxBlurPainter(this.original, this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    int r = (intensity / 15).clamp(1, 6).toInt();
    
    int i = 0;
    for (int x = -r; x <= r; x++) {
      for (int y = -r; y <= r; y++) {
        double opacity = 1.0 / (i + 1);
        canvas.drawImage(original, Offset(x * 3.0, y * 3.0), getOpacityPaint(opacity));
        i++;
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MotionBlurPainter extends CustomPainter {
  final ui.Image original;
  final double intensity;
  final Offset direction;

  MotionBlurPainter(this.original, this.intensity, this.direction);

  @override
  void paint(Canvas canvas, Size size) {
    int steps = (intensity / 2).clamp(2, 50).toInt();
    
    for (int i = 0; i < steps; i++) {
      double dx = direction.dx * i * 2.0;
      double dy = direction.dy * i * 2.0;
      double opacity = 1.0 / (i + 1);
      canvas.drawImage(original, Offset(dx, dy), getOpacityPaint(opacity));
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ZoomBlurPainter extends CustomPainter {
  final ui.Image original;
  final double intensity;

  ZoomBlurPainter(this.original, this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    int steps = (intensity / 3).clamp(2, 30).toInt();
    double maxScale = 1.0 + (intensity / 100.0) * 0.5;
    double cx = size.width / 2;
    double cy = size.height / 2;
    
    for (int i = 0; i < steps; i++) {
      double scale = 1.0 + (maxScale - 1.0) * (i / steps);
      double opacity = 1.0 / (i + 1);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale);
      canvas.translate(-cx, -cy);
      canvas.drawImage(original, Offset.zero, getOpacityPaint(opacity));
      canvas.restore();
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BackgroundPainter extends CustomPainter {
  final ui.Image original;
  BackgroundPainter(this.original);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(original, Offset.zero, Paint());
  }
  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) => false;
}

class InverseMaskPainter extends CustomPainter {
  final ui.Image original;
  final List<PathData> paths;

  InverseMaskPainter({
    required this.original,
    required this.paths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (paths.isEmpty) {
      canvas.drawImage(original, Offset.zero, Paint());
      return;
    }

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawImage(original, Offset.zero, Paint());

    for (var pathData in paths) {
      if (pathData.points.isEmpty) continue;

      Paint pathPaint = Paint()
        ..strokeWidth = pathData.brushSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (pathData.mode == ToolMode.draw) {
        pathPaint.blendMode = BlendMode.clear;
      } else {
        pathPaint.blendMode = BlendMode.srcOver;
        pathPaint.shader = ui.ImageShader(
          original,
          ui.TileMode.clamp,
          ui.TileMode.clamp,
          Float64List.fromList([
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
          ]),
        );
      }

      if (pathData.points.length == 1) {
        canvas.drawCircle(
          pathData.points.first,
          pathData.brushSize / 2,
          pathPaint..style = PaintingStyle.fill,
        );
      } else {
        Path maskPath = Path();
        maskPath.moveTo(pathData.points.first.dx, pathData.points.first.dy);
        for (int i = 1; i < pathData.points.length; i++) {
          maskPath.lineTo(pathData.points[i].dx, pathData.points[i].dy);
        }
        canvas.drawPath(maskPath, pathPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant InverseMaskPainter oldDelegate) => true;
}
