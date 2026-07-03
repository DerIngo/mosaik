import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models.dart';

class OriginalImageNotifier extends Notifier<ui.Image?> {
  @override
  ui.Image? build() => null;
  void setImage(ui.Image? image) => state = image;
}
final originalImageProvider = NotifierProvider<OriginalImageNotifier, ui.Image?>(OriginalImageNotifier.new);

class EffectImageNotifier extends Notifier<ui.Image?> {
  @override
  ui.Image? build() => null;
  void setImage(ui.Image? image) => state = image;
}
final effectImageProvider = NotifierProvider<EffectImageNotifier, ui.Image?>(EffectImageNotifier.new);

class IsGeneratingEffectNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setGenerating(bool val) => state = val;
}
final isGeneratingEffectProvider = NotifierProvider<IsGeneratingEffectNotifier, bool>(IsGeneratingEffectNotifier.new);

class PathsNotifier extends Notifier<List<PathData>> {
  @override
  List<PathData> build() => [];

  void addPath(PathData path) {
    state = [...state, path];
  }

  void updateLastPath(Offset point) {
    if (state.isEmpty) return;
    final lastPath = state.last;
    final updatedPath = PathData(
      points: [...lastPath.points, point],
      mode: lastPath.mode,
      brushSize: lastPath.brushSize,
    );
    state = [
      ...state.sublist(0, state.length - 1),
      updatedPath,
    ];
  }

  void undo() {
    if (state.isNotEmpty) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void clear() {
    state = [];
  }
}
final pathsProvider = NotifierProvider<PathsNotifier, List<PathData>>(PathsNotifier.new);

class ToolModeNotifier extends Notifier<ToolMode> {
  @override
  ToolMode build() => ToolMode.draw;
  void setMode(ToolMode mode) => state = mode;
}
final toolModeProvider = NotifierProvider<ToolModeNotifier, ToolMode>(ToolModeNotifier.new);

class FilterTypeNotifier extends Notifier<FilterType> {
  @override
  FilterType build() => FilterType.unscha1;
  void setFilter(FilterType type) => state = type;
}
final filterTypeProvider = NotifierProvider<FilterTypeNotifier, FilterType>(FilterTypeNotifier.new);

class IntensityNotifier extends Notifier<double> {
  @override
  double build() => 30.0;
  void setIntensity(double val) => state = val;
}
final intensityProvider = NotifierProvider<IntensityNotifier, double>(IntensityNotifier.new);

class BrushSizeNotifier extends Notifier<double> {
  @override
  double build() => 20.0;
  void setSize(double val) => state = val;
}
final brushSizeProvider = NotifierProvider<BrushSizeNotifier, double>(BrushSizeNotifier.new);
