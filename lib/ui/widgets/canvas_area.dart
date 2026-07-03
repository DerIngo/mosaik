import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../state/providers.dart';
import '../../painters/mosaik_painters.dart';

class CanvasArea extends ConsumerWidget {
  const CanvasArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final originalImage = ref.watch(originalImageProvider);
    final effectImage = ref.watch(effectImageProvider);
    final paths = ref.watch(pathsProvider);
    final toolMode = ref.watch(toolModeProvider);
    final brushSize = ref.watch(brushSizeProvider);
    final filterType = ref.watch(filterTypeProvider);
    final isGeneratingEffect = ref.watch(isGeneratingEffectProvider);

    if (originalImage == null) return const SizedBox();

    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: originalImage.width.toDouble(),
                height: originalImage.height.toDouble(),
                child: Builder(
                  builder: (context) {
                    bool isBackdrop = filterType == FilterType.unscha1 || filterType == FilterType.unscha2;
                    double intensity = ref.watch(intensityProvider);
                    double sigma = filterType == FilterType.unscha2 
                        ? 1.0 + (intensity / 100.0) * 49.0 * 2.0 
                        : 1.0 + (intensity / 100.0) * 49.0;
                        
                    return Stack(
                      children: [
                        if (isBackdrop) ...[
                          CustomPaint(
                            size: Size(originalImage.width.toDouble(), originalImage.height.toDouble()),
                            painter: BackgroundPainter(originalImage),
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
                          cursor: toolMode == ToolMode.erase
                              ? SystemMouseCursors.cell
                              : SystemMouseCursors.precise,
                          child: GestureDetector(
                            onPanStart: (details) {
                              ref.read(pathsProvider.notifier).addPath(
                                PathData(
                                  points: [details.localPosition],
                                  mode: toolMode,
                                  brushSize: brushSize,
                                ),
                              );
                            },
                            onPanUpdate: (details) {
                              ref.read(pathsProvider.notifier).updateLastPath(details.localPosition);
                            },
                            child: CustomPaint(
                              size: Size(originalImage.width.toDouble(), originalImage.height.toDouble()),
                              painter: isBackdrop
                                  ? InverseMaskPainter(
                                      original: originalImage,
                                      paths: paths,
                                    )
                                  : MosaikPainter(
                                      original: originalImage,
                                      effectImage: effectImage,
                                      paths: paths,
                                      filterType: filterType,
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
        if (isGeneratingEffect)
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
