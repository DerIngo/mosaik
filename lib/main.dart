import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_saver/file_saver.dart';

void main() {
  runApp(const MosaikApp());
}

class MosaikApp extends StatelessWidget {
  const MosaikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mosaik+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainEditor(),
    );
  }
}

enum FilterType { pixelate, unscha1, unscha2, weich, linie1, linie2, bewe, zoom, solidColor, hexagon, retroDot, drei, polygon, punkt, kris, glas1, glas2 }

enum ToolMode { draw, erase }

class PathData {
  final List<Offset> points;
  final ToolMode mode;
  final double brushSize;

  PathData({required this.points, required this.mode, required this.brushSize});
}

class MainEditor extends StatefulWidget {
  const MainEditor({super.key});

  @override
  State<MainEditor> createState() => _MainEditorState();
}

class _MainEditorState extends State<MainEditor> {
  ui.Image? _originalImage;
  ui.Image? _effectImage;

  final List<PathData> _paths = [];

  double _brushSize = 30.0;
  double _intensity = 30.0; // Slider value 0 - 100

  FilterType _filterType = FilterType.pixelate;
  ToolMode _toolMode = ToolMode.draw;

  bool _isProcessing = false;
  bool _isGeneratingEffect = false;

  Future<void> _loadImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);

    if (xfile != null) {
      setState(() => _isProcessing = true);
      try {
        final bytes = await xfile.readAsBytes();
        final decodedImage = await decodeImageFromList(bytes);

        _originalImage?.dispose();
        _effectImage?.dispose();

        setState(() {
          _originalImage = decodedImage;
          _paths.clear();
        });

        await _updateEffectImage();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<ui.Image> _createBlurred(ui.Image original, double sigma) async {
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

  Future<ui.Image> _createPixelated(ui.Image original, double blockSize) async {
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

  Future<ui.Image> _createHexagonMosaik(
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

  Future<ui.Image> _createRetroDot(ui.Image original, double blockSize) async {
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

  Future<ui.Image> _createTriangleMosaik(ui.Image original, double blockSize) async {
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

  Future<ui.Image> _createVoronoiMosaik(ui.Image original, double blockSize) async {
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

  Future<ui.Image> _createDotMatrix(ui.Image original, double blockSize) async {
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

  Future<ui.Image> _createKris(ui.Image original, double blockSize) async {
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

  Future<ui.Image> _createGlas1Frosted(ui.Image original, double blockSize) async {
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

  Future<ui.Image> _createGlas2Prisms(ui.Image original, double blockSize) async {
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

  Future<ui.Image> _renderPainter(CustomPainter painter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(
      _originalImage!.width.toDouble(),
      _originalImage!.height.toDouble(),
    );
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    return await picture.toImage(size.width.toInt(), size.height.toInt());
  }

  Future<void> _updateEffectImage() async {
    if (_originalImage == null) return;

    if (_filterType == FilterType.solidColor) {
      setState(() => _effectImage = null);
      return;
    }

    setState(() => _isGeneratingEffect = true);

    try {
      ui.Image? newEffect;
      if (_filterType == FilterType.unscha1) {
        final sigma = 1.0 + (_intensity / 100.0) * 49.0;
        newEffect = await _createBlurred(_originalImage!, sigma);
      } else if (_filterType == FilterType.unscha2) {
        final sigma = 1.0 + (_intensity / 100.0) * 49.0 * 2.0;
        newEffect = await _createBlurred(_originalImage!, sigma);
      } else if (_filterType == FilterType.weich) {
        newEffect = await _renderPainter(BoxBlurPainter(_originalImage!, _intensity));
      } else if (_filterType == FilterType.linie1) {
        newEffect = await _renderPainter(MotionBlurPainter(_originalImage!, _intensity, const Offset(1, 0)));
      } else if (_filterType == FilterType.linie2) {
        newEffect = await _renderPainter(MotionBlurPainter(_originalImage!, _intensity, const Offset(1, 1)));
      } else if (_filterType == FilterType.bewe) {
        newEffect = await _renderPainter(MotionBlurPainter(_originalImage!, _intensity * 1.5, const Offset(0.5, 1)));
      } else if (_filterType == FilterType.zoom) {
        newEffect = await _renderPainter(ZoomBlurPainter(_originalImage!, _intensity));
      } else if (_filterType == FilterType.pixelate) {
        final blockSize = 5.0 + (_intensity / 100.0) * 95.0;
        newEffect = await _createPixelated(_originalImage!, blockSize);
      } else if (_filterType == FilterType.hexagon) {
        final blockSize = 5.0 + (_intensity / 100.0) * 95.0;
        newEffect = await _createHexagonMosaik(_originalImage!, blockSize);
      } else if (_filterType == FilterType.retroDot) {
        final blockSize = 5.0 + (_intensity / 100.0) * 95.0;
        newEffect = await _createRetroDot(_originalImage!, blockSize);
      } else if (_filterType == FilterType.drei) {
        final blockSize = 5.0 + (_intensity / 100.0) * 95.0;
        newEffect = await _createTriangleMosaik(_originalImage!, blockSize);
      } else if (_filterType == FilterType.polygon) {
        final blockSize = 5.0 + (_intensity / 100.0) * 95.0;
        newEffect = await _createVoronoiMosaik(_originalImage!, blockSize);
      } else if (_filterType == FilterType.punkt) {
        final blockSize = 5.0 + (_intensity / 100.0) * 95.0;
        newEffect = await _createDotMatrix(_originalImage!, blockSize);
      } else if (_filterType == FilterType.kris) {
        final blockSize = 5.0 + (_intensity / 100.0) * 95.0;
        newEffect = await _createKris(_originalImage!, blockSize);
      } else if (_filterType == FilterType.glas1) {
        final blockSize = 5.0 + (_intensity / 100.0) * 95.0;
        newEffect = await _createGlas1Frosted(_originalImage!, blockSize);
      } else if (_filterType == FilterType.glas2) {
        final blockSize = 5.0 + (_intensity / 100.0) * 95.0;
        newEffect = await _createGlas2Prisms(_originalImage!, blockSize);
      }

      final oldEffect = _effectImage;
      setState(() {
        _effectImage = newEffect;
      });
      oldEffect?.dispose();
    } catch (e) {
      debugPrint('Error updating effect image: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingEffect = false);
    }
  }

  void _clearMask() {
    setState(() => _paths.clear());
  }

  void _undo() {
    if (_paths.isNotEmpty) {
      setState(() => _paths.removeLast());
    }
  }

  void _setFilterType(FilterType type) {
    if (_filterType == type) return;
    setState(() => _filterType = type);
    _updateEffectImage();
  }

  void _setIntensity(double value) {
    setState(() => _intensity = value);
  }

  void _applyIntensity(double value) {
    _updateEffectImage();
  }

  Future<void> _exportImage() async {
    if (_originalImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(
        _originalImage!.width.toDouble(),
        _originalImage!.height.toDouble(),
      );

      final painter = MosaikPainter(
        original: _originalImage!,
        effectImage: _effectImage,
        paths: _paths,
        filterType: _filterType,
      );

      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      final exportedImage = await picture.toImage(
        _originalImage!.width,
        _originalImage!.height,
      );

      final byteData = await exportedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final buffer = byteData!.buffer.asUint8List();

      await FileSaver.instance.saveFile(
        name: 'mosaik_export_${DateTime.now().millisecondsSinceEpoch}',
        bytes: buffer,
        ext: 'png',
        mimeType: MimeType.png,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bild erfolgreich exportiert!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Export: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mosaik+',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
        actions: [
          if (_originalImage != null)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Rückgängig',
              onPressed: _paths.isEmpty ? null : _undo,
            ),
          if (_originalImage != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Maske löschen',
              onPressed: _paths.isEmpty ? null : _clearMask,
            ),
          if (_originalImage != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, left: 8.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Neues Bild'),
                onPressed: _loadImage,
              ),
            ),
          if (_originalImage != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Exportieren'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: _isProcessing ? null : _exportImage,
              ),
            ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _originalImage == null
          ? _buildEmptyState()
          : _buildWorkspace(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_search,
            size: 100,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Lade ein Bild, um sensible Bereiche unkenntlich zu machen.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Bild vom Gerät laden'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: _loadImage,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return Row(
            children: [
              Container(
                width: 320,
                color: Theme.of(context).colorScheme.surface,
                child: _buildToolbar(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildEditor()),
            ],
          );
        } else {
          return Column(
            children: [
              Expanded(child: _buildEditor()),
              const Divider(height: 1),
              Container(
                height: 280,
                color: Theme.of(context).colorScheme.surface,
                child: _buildToolbar(),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildEffectGroup(String title, Map<FilterType, String> effects) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
          child: Text(
            title,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: effects.entries.map((entry) {
            return ChoiceChip(
              label: Text(entry.value),
              selected: _filterType == entry.key,
              onSelected: (val) => val ? _setFilterType(entry.key) : null,
              showCheckmark: false,
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildToolbar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Werkzeug',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ToolMode>(
            segments: const [
              ButtonSegment(
                value: ToolMode.draw,
                icon: Icon(Icons.brush),
                label: Text('Zeichnen'),
              ),
              ButtonSegment(
                value: ToolMode.erase,
                icon: Icon(Icons.cleaning_services),
                label: Text('Radieren'),
              ),
            ],
            selected: {_toolMode},
            onSelectionChanged: (newSel) =>
                setState(() => _toolMode = newSel.first),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          const Text(
            'Effekt',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          _buildEffectGroup('Verpixelung & Raster', {
            FilterType.pixelate: 'Mosaik',
            FilterType.hexagon: 'Hexagon',
            FilterType.drei: 'Dreiecke',
            FilterType.polygon: 'Voronoi',
            FilterType.punkt: 'Punkte',
            FilterType.retroDot: 'Retro Dot',
          }),
          
          _buildEffectGroup('Unschärfe', {
            FilterType.unscha1: 'Gauß (Leicht)',
            FilterType.unscha2: 'Gauß (Stark)',
            FilterType.weich: 'Weichzeichner',
            FilterType.linie1: 'Motion (Horiz.)',
            FilterType.linie2: 'Motion (Diag.)',
            FilterType.bewe: 'Motion (Vert.)',
            FilterType.zoom: 'Zoom',
          }),

          _buildEffectGroup('Künstlerisch & Glas', {
            FilterType.kris: 'Kristallisieren',
            FilterType.glas1: 'Milchglas',
            FilterType.glas2: 'Prisma',
          }),

          _buildEffectGroup('Abdeckung', {
            FilterType.solidColor: 'Zensurbalken',
          }),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 24),

          const Text(
            'Feinabstimmung',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Intensität'),
          Row(
            children: [
              const Icon(Icons.tune, size: 20),
              Expanded(
                child: Slider(
                  value: _intensity,
                  min: 0.0,
                  max: 100.0,
                  label: '${_intensity.toInt()} %',
                  onChanged: _filterType == FilterType.solidColor
                      ? null
                      : _setIntensity,
                  onChangeEnd: _filterType == FilterType.solidColor
                      ? null
                      : _applyIntensity,
                ),
              ),
              SizedBox(width: 45, child: Text('${_intensity.toInt()} %')),
            ],
          ),

          const SizedBox(height: 16),
          const Text('Pinselgröße'),
          Row(
            children: [
              const Icon(Icons.circle, size: 16),
              Expanded(
                child: Slider(
                  value: _brushSize,
                  min: 10.0,
                  max: 80.0,
                  label: '${_brushSize.toInt()} px',
                  onChanged: (val) => setState(() => _brushSize = val),
                ),
              ),
              SizedBox(width: 45, child: Text('${_brushSize.toInt()} px')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _originalImage!.width.toDouble(),
                height: _originalImage!.height.toDouble(),
                child: Builder(
                  builder: (context) {
                    bool isBackdrop = _filterType == FilterType.unscha1 || _filterType == FilterType.unscha2;
                    double sigma = _filterType == FilterType.unscha2 
                        ? 1.0 + (_intensity / 100.0) * 49.0 * 2.0 
                        : 1.0 + (_intensity / 100.0) * 49.0;
                    return Stack(
                      children: [
                        if (isBackdrop) ...[
                          CustomPaint(
                            size: Size(_originalImage!.width.toDouble(), _originalImage!.height.toDouble()),
                            painter: BackgroundPainter(_originalImage!),
                          ),
                          Positioned.fill(
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                          ),
                        ],
                        MouseRegion(
                          cursor: _toolMode == ToolMode.erase
                              ? SystemMouseCursors.cell
                              : SystemMouseCursors.precise,
                          child: GestureDetector(
                            onPanStart: (details) {
                              setState(() {
                                _paths.add(
                                  PathData(
                                    points: [details.localPosition],
                                    mode: _toolMode,
                                    brushSize: _brushSize,
                                  ),
                                );
                              });
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                _paths.last.points.add(details.localPosition);
                              });
                            },
                            child: CustomPaint(
                              size: Size(_originalImage!.width.toDouble(), _originalImage!.height.toDouble()),
                              painter: isBackdrop
                                  ? InverseMaskPainter(
                                      original: _originalImage!,
                                      paths: _paths,
                                    )
                                  : MosaikPainter(
                                      original: _originalImage!,
                                      effectImage: _effectImage,
                                      paths: _paths,
                                      filterType: _filterType,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
            ),
          ),
        ),
        if (_isGeneratingEffect)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

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

Paint _getOpacityPaint(double opacity) {
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
        canvas.drawImage(original, Offset(x * 3.0, y * 3.0), _getOpacityPaint(opacity));
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
      canvas.drawImage(original, Offset(dx, dy), _getOpacityPaint(opacity));
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
      canvas.drawImage(original, Offset.zero, _getOpacityPaint(opacity));
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
