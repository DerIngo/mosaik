import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_saver/file_saver.dart';

import '../core/models.dart';
import '../state/providers.dart';
import '../painters/mosaik_painters.dart';
import '../filters/image_filters.dart';
import '../core/pwa/pwa_helper.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'widgets/toolbar.dart';
import 'widgets/canvas_area.dart';

class MainEditor extends ConsumerStatefulWidget {
  const MainEditor({super.key});

  @override
  ConsumerState<MainEditor> createState() => _MainEditorState();
}

class _MainEditorState extends ConsumerState<MainEditor> {
  bool _isProcessing = false;
  bool _showInstallButton = false;
  Timer? _installCheckTimer;

  Future<void> _loadImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);

    if (xfile != null) {
      setState(() => _isProcessing = true);
      try {
        final bytes = await xfile.readAsBytes();
        final decodedImage = await decodeImageFromList(bytes);

        final oldImage = ref.read(originalImageProvider);
        oldImage?.dispose();
        
        ref.read(originalImageProvider.notifier).setImage(decodedImage);
        ref.read(pathsProvider.notifier).clear();

        await _updateEffectImage();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<ui.Image> _renderPainter(CustomPainter painter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final orig = ref.read(originalImageProvider)!;
    final size = Size(orig.width.toDouble(), orig.height.toDouble());
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    return await picture.toImage(size.width.toInt(), size.height.toInt());
  }

  Future<void> _updateEffectImage() async {
    final originalImage = ref.read(originalImageProvider);
    if (originalImage == null) return;

    final filterType = ref.read(filterTypeProvider);
    final intensity = ref.read(intensityProvider);

    if (filterType == FilterType.solidColor) {
      ref.read(effectImageProvider.notifier).setImage(null);
      return;
    }

    ref.read(isGeneratingEffectProvider.notifier).setGenerating(true);

    try {
      ui.Image? newEffect;
      if (filterType == FilterType.unscha1) {
        final sigma = 1.0 + (intensity / 100.0) * 49.0;
        newEffect = await ImageFilters.createBlurred(originalImage, sigma);
      } else if (filterType == FilterType.unscha2) {
        final sigma = 1.0 + (intensity / 100.0) * 49.0 * 2.0;
        newEffect = await ImageFilters.createBlurred(originalImage, sigma);
      } else if (filterType == FilterType.weich) {
        newEffect = await _renderPainter(BoxBlurPainter(originalImage, intensity));
      } else if (filterType == FilterType.linie1) {
        newEffect = await _renderPainter(MotionBlurPainter(originalImage, intensity, const Offset(1, 0)));
      } else if (filterType == FilterType.linie2) {
        newEffect = await _renderPainter(MotionBlurPainter(originalImage, intensity, const Offset(1, 1)));
      } else if (filterType == FilterType.bewe) {
        newEffect = await _renderPainter(MotionBlurPainter(originalImage, intensity * 1.5, const Offset(0.5, 1)));
      } else if (filterType == FilterType.zoom) {
        newEffect = await _renderPainter(ZoomBlurPainter(originalImage, intensity));
      } else if (filterType == FilterType.pixelate) {
        final blockSize = 5.0 + (intensity / 100.0) * 95.0;
        newEffect = await ImageFilters.createPixelated(originalImage, blockSize);
      } else if (filterType == FilterType.hexagon) {
        final blockSize = 5.0 + (intensity / 100.0) * 95.0;
        newEffect = await ImageFilters.createHexagonMosaik(originalImage, blockSize);
      } else if (filterType == FilterType.retroDot) {
        final blockSize = 5.0 + (intensity / 100.0) * 95.0;
        newEffect = await ImageFilters.createRetroDot(originalImage, blockSize);
      } else if (filterType == FilterType.drei) {
        final blockSize = 5.0 + (intensity / 100.0) * 95.0;
        newEffect = await ImageFilters.createTriangleMosaik(originalImage, blockSize);
      } else if (filterType == FilterType.polygon) {
        final blockSize = 5.0 + (intensity / 100.0) * 95.0;
        newEffect = await ImageFilters.createVoronoiMosaik(originalImage, blockSize);
      } else if (filterType == FilterType.punkt) {
        final blockSize = 5.0 + (intensity / 100.0) * 95.0;
        newEffect = await ImageFilters.createDotMatrix(originalImage, blockSize);
      } else if (filterType == FilterType.kris) {
        final blockSize = 5.0 + (intensity / 100.0) * 95.0;
        newEffect = await ImageFilters.createKris(originalImage, blockSize);
      } else if (filterType == FilterType.glas1) {
        final blockSize = 5.0 + (intensity / 100.0) * 95.0;
        newEffect = await ImageFilters.createGlas1Frosted(originalImage, blockSize);
      } else if (filterType == FilterType.glas2) {
        final blockSize = 5.0 + (intensity / 100.0) * 95.0;
        newEffect = await ImageFilters.createGlas2Prisms(originalImage, blockSize);
      }

      final oldEffect = ref.read(effectImageProvider);
      ref.read(effectImageProvider.notifier).setImage(newEffect);
      oldEffect?.dispose();
    } catch (e) {
      debugPrint('Error updating effect image: $e');
    } finally {
      if (mounted) {
        ref.read(isGeneratingEffectProvider.notifier).setGenerating(false);
      }
    }
  }

  Future<void> _exportImage() async {
    final originalImage = ref.read(originalImageProvider);
    if (originalImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(
        originalImage.width.toDouble(),
        originalImage.height.toDouble(),
      );

      final painter = MosaikPainter(
        original: originalImage,
        effectImage: ref.read(effectImageProvider),
        paths: ref.read(pathsProvider),
        filterType: ref.read(filterTypeProvider),
      );

      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      final exportedImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );

      final byteData = await exportedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final buffer = byteData!.buffer.asUint8List();

      await FileSaver.instance.saveFile(
        name: 'mosaik_export_${DateTime.now().millisecondsSinceEpoch}',
        bytes: buffer,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bild erfolgreich exportiert!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Export: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb && !isPwaInstalled) {
      _installCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          final canPrompt = hasDeferredPrompt || defaultTargetPlatform == TargetPlatform.iOS;
          if (canPrompt != _showInstallButton) {
            setState(() => _showInstallButton = canPrompt);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _installCheckTimer?.cancel();
    super.dispose();
  }

  void _handleInstallPwa() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('App installieren (iOS)'),
          content: const Text('Um Mosaik+ als App zu installieren, tippe unten in Safari auf das "Teilen"-Symbol (Viereck mit Pfeil) und wähle dann "Zum Home-Bildschirm".'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Verstanden')),
          ],
        ),
      );
    } else {
      final success = await promptInstall();
      if (success && mounted) {
        setState(() => _showInstallButton = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes that trigger image generation
    ref.listen(filterTypeProvider, (previous, next) {
      if (previous != next) {
        _updateEffectImage();
      }
    });

    ref.listen(intensityProvider, (previous, next) {
      if (previous != next) {
        _updateEffectImage();
      }
    });

    final originalImage = ref.watch(originalImageProvider);
    final paths = ref.watch(pathsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mosaik+', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
        actions: [
          if (_showInstallButton)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, left: 8.0),
              child: FilledButton.icon(
                icon: const Icon(Icons.install_mobile),
                label: const Text('App installieren'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _handleInstallPwa,
              ),
            ),
          if (originalImage != null)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Rückgängig',
              onPressed: paths.isEmpty ? null : () => ref.read(pathsProvider.notifier).undo(),
            ),
          if (originalImage != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Maske löschen',
              onPressed: paths.isEmpty ? null : () => ref.read(pathsProvider.notifier).clear(),
            ),
          if (originalImage != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, left: 8.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Neues Bild'),
                onPressed: _loadImage,
              ),
            ),
          if (originalImage != null)
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
          : originalImage == null
          ? _buildEmptyState()
          : _buildWorkspace(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_search, size: 100, color: Colors.grey.withValues(alpha: 0.5)),
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
                child: const MosaikToolbar(),
              ),
              const VerticalDivider(width: 1),
              const Expanded(child: CanvasArea()),
            ],
          );
        } else {
          return Column(
            children: [
              const Expanded(child: CanvasArea()),
              const Divider(height: 1),
              Container(
                height: 280,
                color: Theme.of(context).colorScheme.surface,
                child: const MosaikToolbar(),
              ),
            ],
          );
        }
      },
    );
  }
}
