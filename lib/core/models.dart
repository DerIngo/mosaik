import 'package:flutter/material.dart';

enum FilterType { pixelate, unscha1, unscha2, weich, linie1, linie2, bewe, zoom, solidColor, hexagon, retroDot, drei, polygon, punkt, kris, glas1, glas2 }

enum ToolMode { draw, erase }

class PathData {
  final List<Offset> points;
  final ToolMode mode;
  final double brushSize;

  PathData({required this.points, required this.mode, required this.brushSize});
}
