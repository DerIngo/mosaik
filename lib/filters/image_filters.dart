import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ImageFilters {
static Future<ui.Image> createBlurred(ui.Image original, double sigma) async {
    if (sigma <= 0.1) return original;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: ui.TileMode.clamp,
      );

    canvas.drawImage(original, Offset.zero, paint);

    final picture = recorder.endRecording();
    return await picture.toImage(original.width, original.height);
  }

  static Future<ui.Image> createPixelated(ui.Image original, double blockSize) async {
    if (blockSize <= 1.0) return original;

    final recorderDown = ui.PictureRecorder();
    final canvasDown = Canvas(recorderDown);

    final double scale = 1.0 / blockSize;
    final int downWidth = (original.width * scale).ceil();
    final int downHeight = (original.height * scale).ceil();

    canvasDown.scale(scale, scale);
    canvasDown.drawImage(
      original,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.none,
    );
    final pictureDown = recorderDown.endRecording();
    final imageDown = await pictureDown.toImage(downWidth, downHeight);

    final recorderUp = ui.PictureRecorder();
    final canvasUp = Canvas(recorderUp);
    canvasUp.scale(1.0 / scale, 1.0 / scale);
    canvasUp.drawImage(
      imageDown,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.none,
    );

    final pictureUp = recorderUp.endRecording();
    final finalImage = await pictureUp.toImage(original.width, original.height);

    imageDown.dispose();
    return finalImage;
  }

  static Future<ui.Image> createHexagonMosaik(
    ui.Image original,
    double blockSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    ByteData? byteData;
    try {
      byteData = await original.toByteData(format: ui.ImageByteFormat.rawRgba);
    } catch (_) {}
    if (byteData == null) return original;

    final int width = original.width;
    final int height = original.height;

    // Hintergrund füllen, um keine Lücken zu haben
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.black,
    );

    final double w = blockSize;
    final double h = blockSize * math.sqrt(3) / 2;
    final double radius = blockSize / math.sqrt(3);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Vorberechnete Winkel für das Hexagon (Pointy Top)
    final List<Offset> hexPoints = [];
    for (int i = 0; i < 6; i++) {
      double angleRad = math.pi / 180.0 * (60.0 * i + 30.0);
      hexPoints.add(
        Offset(radius * math.cos(angleRad), radius * math.sin(angleRad)),
      );
    }

    int row = 0;
    for (double y = 0; y < height + h; y += h) {
      double xOffset = (row % 2 == 1) ? w / 2 : 0;
      for (double x = xOffset; x < width + w; x += w) {
        int px = x.toInt().clamp(0, width - 1);
        int py = y.toInt().clamp(0, height - 1);

        int offset = (py * width + px) * 4;
        int r = byteData.getUint8(offset);
        int g = byteData.getUint8(offset + 1);
        int b = byteData.getUint8(offset + 2);
        int a = byteData.getUint8(offset + 3);

        paint.color = Color.fromARGB(a, r, g, b);

        Path path = Path();
        path.moveTo(x + hexPoints[0].dx, y + hexPoints[0].dy);
        for (int i = 1; i < 6; i++) {
          path.lineTo(x + hexPoints[i].dx, y + hexPoints[i].dy);
        }
        path.close();

        canvas.drawPath(path, paint);
        // Minimaler Stroke verhindert optische Lücken durch Anti-Aliasing
        canvas.drawPath(
          path,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
        paint.style = PaintingStyle.fill;
      }
      row++;
    }

    final picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  static Future<ui.Image> createRetroDot(ui.Image original, double blockSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    ByteData? byteData;
    try {
      byteData = await original.toByteData(format: ui.ImageByteFormat.rawRgba);
    } catch (_) {}
    if (byteData == null) return original;

    final int width = original.width;
    final int height = original.height;

    // Dunkler Hintergrund für Retro-Effekt, um das Original zu überdecken
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF1A1A1A),
    );

    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (double y = 0; y < height; y += blockSize) {
      for (double x = 0; x < width; x += blockSize) {
        double cx = x + blockSize / 2;
        double cy = y + blockSize / 2;

        int px = cx.toInt().clamp(0, width - 1);
        int py = cy.toInt().clamp(0, height - 1);

        int offset = (py * width + px) * 4;
        int r = byteData.getUint8(offset);
        int g = byteData.getUint8(offset + 1);
        int b = byteData.getUint8(offset + 2);
        int a = byteData.getUint8(offset + 3);

        paint.color = Color.fromARGB(a, r, g, b);

        // Radius basierend auf Luminanz für einen coolen Halbton-Effekt
        double luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        double dotRadius = blockSize * (0.2 + 0.3 * luminance);

        canvas.drawCircle(Offset(cx, cy), dotRadius, paint);
      }
    }

    final picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  static Future<ui.Image> createTriangleMosaik(ui.Image original, double blockSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    ByteData? byteData;
    try {
      byteData = await original.toByteData(format: ui.ImageByteFormat.rawRgba);
    } catch (_) {}
    if (byteData == null) return original;

    final int width = original.width;
    final int height = original.height;

    final double w = blockSize;
    final double h = blockSize * math.sqrt(3) / 2;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.5;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = Colors.black);

    for (int row = 0; row < (height / h) + 1; row++) {
      double y = row * h;
      bool isPointyTop = row % 2 == 0;
      
      for (int col = 0; col < (width / (w / 2)) + 1; col++) {
        double x = col * (w / 2);
        bool pointsUp = (col % 2 == 0) ? isPointyTop : !isPointyTop;
        
        Path path = Path();
        double cx, cy;
        
        if (pointsUp) {
          path.moveTo(x - w / 2, y + h);
          path.lineTo(x + w / 2, y + h);
          path.lineTo(x, y);
          path.close();
          cx = x;
          cy = y + h * 0.666;
        } else {
          path.moveTo(x - w / 2, y);
          path.lineTo(x + w / 2, y);
          path.lineTo(x, y + h);
          path.close();
          cx = x;
          cy = y + h * 0.333;
        }
        
        int px = cx.toInt().clamp(0, width - 1);
        int py = cy.toInt().clamp(0, height - 1);
        
        int offset = (py * width + px) * 4;
        int r = byteData.getUint8(offset);
        int g = byteData.getUint8(offset + 1);
        int b = byteData.getUint8(offset + 2);
        int a = byteData.getUint8(offset + 3);
        
        Color color = Color.fromARGB(a, r, g, b);
        paint.color = color;
        strokePaint.color = color;
        
        canvas.drawPath(path, paint);
        canvas.drawPath(path, strokePaint);
      }
    }

    final picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  static Future<ui.Image> createVoronoiMosaik(ui.Image original, double blockSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    ByteData? byteData;
    try {
      byteData = await original.toByteData(format: ui.ImageByteFormat.rawRgba);
    } catch (_) {}
    if (byteData == null) return original;

    final int width = original.width;
    final int height = original.height;
    
    double gridS = blockSize.clamp(10.0, width.toDouble());
    int cols = (width / gridS).ceil();
    int rows = (height / gridS).ceil();
    
    final math.Random rand = math.Random(42);
    final List<Offset> points = List.filled(rows * cols, Offset.zero);
    final List<Color> colors = List.filled(rows * cols, Colors.black);
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double px = c * gridS + gridS * 0.25 + rand.nextDouble() * gridS * 0.5;
        double py = r * gridS + gridS * 0.25 + rand.nextDouble() * gridS * 0.5;
        px = px.clamp(0, width - 1);
        py = py.clamp(0, height - 1);
        
        int idx = r * cols + c;
        points[idx] = Offset(px, py);
        
        int offset = (py.toInt() * width + px.toInt()) * 4;
        colors[idx] = Color.fromARGB(
          byteData.getUint8(offset + 3),
          byteData.getUint8(offset),
          byteData.getUint8(offset + 1),
          byteData.getUint8(offset + 2),
        );
      }
    }
    
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.5;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int idx = r * cols + c;
        Offset p = points[idx];
        
        Rect bounds = Rect.fromLTRB(
          (c - 1) * gridS,
          (r - 1) * gridS,
          (c + 2) * gridS,
          (r + 2) * gridS,
        );
        Path cellPath = Path()..addRect(bounds);
        
        for (int nr = math.max(0, r - 1); nr <= math.min(rows - 1, r + 1); nr++) {
          for (int nc = math.max(0, c - 1); nc <= math.min(cols - 1, c + 1); nc++) {
            if (nr == r && nc == c) continue;
            
            Offset n = points[nr * cols + nc];
            
            Offset mid = Offset((p.dx + n.dx) / 2, (p.dy + n.dy) / 2);
            Offset dir = Offset(n.dx - p.dx, n.dy - p.dy);
            
            Offset norm = Offset(-dir.dy, dir.dx);
            double len = math.sqrt(norm.dx * norm.dx + norm.dy * norm.dy);
            if (len == 0) continue;
            norm = Offset(norm.dx / len, norm.dy / len);
            
            double largeDist = 10000.0;
            Path halfPlane = Path()
              ..moveTo(mid.dx + norm.dx * largeDist, mid.dy + norm.dy * largeDist)
              ..lineTo(mid.dx - norm.dx * largeDist, mid.dy - norm.dy * largeDist)
              ..lineTo(mid.dx - norm.dx * largeDist - dir.dx * largeDist, mid.dy - norm.dy * largeDist - dir.dy * largeDist)
              ..lineTo(mid.dx + norm.dx * largeDist - dir.dx * largeDist, mid.dy + norm.dy * largeDist - dir.dy * largeDist)
              ..close();
              
            cellPath = Path.combine(PathOperation.intersect, cellPath, halfPlane);
          }
        }
        
        paint.color = colors[idx];
        strokePaint.color = colors[idx];
        canvas.drawPath(cellPath, paint);
        canvas.drawPath(cellPath, strokePaint);
      }
    }
    
    final picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  static Future<ui.Image> createDotMatrix(ui.Image original, double blockSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    ByteData? byteData;
    try {
      byteData = await original.toByteData(format: ui.ImageByteFormat.rawRgba);
    } catch (_) {}
    if (byteData == null) return original;

    final int width = original.width;
    final int height = original.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = Colors.black);

    final Paint paint = Paint()..style = PaintingStyle.fill;
    double radius = blockSize * 0.45;

    for (double y = 0; y < height; y += blockSize) {
      for (double x = 0; x < width; x += blockSize) {
        double cx = x + blockSize / 2;
        double cy = y + blockSize / 2;

        int px = cx.toInt().clamp(0, width - 1);
        int py = cy.toInt().clamp(0, height - 1);

        int offset = (py * width + px) * 4;
        int r = byteData.getUint8(offset);
        int g = byteData.getUint8(offset + 1);
        int b = byteData.getUint8(offset + 2);
        int a = byteData.getUint8(offset + 3);

        paint.color = Color.fromARGB(a, r, g, b);
        canvas.drawCircle(Offset(cx, cy), radius, paint);
      }
    }

    final picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  static Future<ui.Image> createKris(ui.Image original, double blockSize) async {
    final int width = original.width;
    final int height = original.height;
    
    ByteData? byteData;
    try {
      byteData = await original.toByteData(format: ui.ImageByteFormat.rawRgba);
    } catch (_) {}
    if (byteData == null) return original;
    
    final pixels = byteData.buffer.asUint32List();
    final outPixels = Uint32List(width * height);
    
    double gridS = blockSize.clamp(10.0, 200.0);
    int cols = (width / gridS).ceil();
    int rows = (height / gridS).ceil();
    
    final math.Random rand = math.Random(42);
    final List<Offset> points = List.filled(rows * cols, Offset.zero);
    final List<int> colors = List.filled(rows * cols, 0);
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double px = c * gridS + rand.nextDouble() * gridS;
        double py = r * gridS + rand.nextDouble() * gridS;
        px = px.clamp(0, width - 1);
        py = py.clamp(0, height - 1);
        
        int idx = r * cols + c;
        points[idx] = Offset(px, py);
        
        int offset = py.toInt() * width + px.toInt();
        colors[idx] = pixels[offset];
      }
    }
    
    double noiseAmplitude = gridS * 0.4;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double jitterX = math.sin(x * 0.1) * math.cos(y * 0.1) * noiseAmplitude;
        double jitterY = math.cos(x * 0.1) * math.sin(y * 0.1) * noiseAmplitude;
        
        double jx = x + jitterX;
        double jy = y + jitterY;
        
        int cellX = jx ~/ gridS;
        int cellY = jy ~/ gridS;
        
        double minDistSq = double.infinity;
        int bestColor = 0;
        
        int minY = math.max(0, cellY - 1);
        int maxY = math.min(rows - 1, cellY + 1);
        int minX = math.max(0, cellX - 1);
        int maxX = math.min(cols - 1, cellX + 1);
        
        for (int ny = minY; ny <= maxY; ny++) {
          for (int nx = minX; nx <= maxX; nx++) {
            int idx = ny * cols + nx;
            Offset p = points[idx];
            double dx = jx - p.dx;
            double dy = jy - p.dy;
            double distSq = dx * dx + dy * dy;
            
            if (distSq < minDistSq) {
              minDistSq = distSq;
              bestColor = colors[idx];
            }
          }
        }
        
        outPixels[y * width + x] = bestColor;
      }
    }
    
    final buffer = await ui.ImmutableBuffer.fromUint8List(outPixels.buffer.asUint8List());
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  static Future<ui.Image> createGlas1Frosted(ui.Image original, double blockSize) async {
    final int width = original.width;
    final int height = original.height;
    
    ByteData? byteData;
    try {
      byteData = await original.toByteData(format: ui.ImageByteFormat.rawRgba);
    } catch (_) {}
    if (byteData == null) return original;
    
    final pixels = byteData.buffer.asUint32List();
    final outPixels = Uint32List(width * height);
    
    final math.Random rand = math.Random(42);
    int s = blockSize.toInt().clamp(1, 100);
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int dx = rand.nextInt(s * 2 + 1) - s;
        int dy = rand.nextInt(s * 2 + 1) - s;
        
        int sx = (x + dx).clamp(0, width - 1);
        int sy = (y + dy).clamp(0, height - 1);
        
        outPixels[y * width + x] = pixels[sy * width + sx];
      }
    }
    
    final buffer = await ui.ImmutableBuffer.fromUint8List(outPixels.buffer.asUint8List());
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  static Future<ui.Image> createGlas2Prisms(ui.Image original, double blockSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final int width = original.width;
    final int height = original.height;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = Colors.black);

    double shift = blockSize * 0.15;
    
    final Paint whiteStroke = Paint()..color = Colors.white.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final Paint darkStroke = Paint()..color = Colors.black.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.0;

    for (double y = 0; y < height; y += blockSize) {
      for (double x = 0; x < width; x += blockSize) {
        Offset tl = Offset(x, y);
        Offset tr = Offset(x + blockSize, y);
        Offset br = Offset(x + blockSize, y + blockSize);
        Offset bl = Offset(x, y + blockSize);
        Offset c = Offset(x + blockSize / 2, y + blockSize / 2);
        
        void drawPrism(Path path, Offset offsetDir) {
          canvas.save();
          canvas.clipPath(path);
          Rect srcRect = Rect.fromLTWH(x - offsetDir.dx, y - offsetDir.dy, blockSize, blockSize);
          Rect dstRect = Rect.fromLTWH(x, y, blockSize, blockSize);
          canvas.drawImageRect(original, srcRect, dstRect, Paint());
          canvas.restore();
        }

        Path topPath = Path()..moveTo(tl.dx, tl.dy)..lineTo(tr.dx, tr.dy)..lineTo(c.dx, c.dy)..close();
        drawPrism(topPath, Offset(0, -shift));
        
        Path rightPath = Path()..moveTo(tr.dx, tr.dy)..lineTo(br.dx, br.dy)..lineTo(c.dx, c.dy)..close();
        drawPrism(rightPath, Offset(shift, 0));

        Path bottomPath = Path()..moveTo(br.dx, br.dy)..lineTo(bl.dx, bl.dy)..lineTo(c.dx, c.dy)..close();
        drawPrism(bottomPath, Offset(0, shift));

        Path leftPath = Path()..moveTo(bl.dx, bl.dy)..lineTo(tl.dx, tl.dy)..lineTo(c.dx, c.dy)..close();
        drawPrism(leftPath, Offset(-shift, 0));
        
        canvas.drawLine(tl, tr, whiteStroke);
        canvas.drawLine(bl, tl, whiteStroke);
        canvas.drawLine(tr, br, darkStroke);
        canvas.drawLine(br, bl, darkStroke);
        
        canvas.drawLine(tl, c, whiteStroke);
        canvas.drawLine(bl, c, darkStroke);
        canvas.drawLine(tr, c, whiteStroke);
        canvas.drawLine(br, c, darkStroke);
      }
    }

    final picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  }
