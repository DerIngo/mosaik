import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../state/providers.dart';

class MosaikToolbar extends ConsumerWidget {
  const MosaikToolbar({super.key});

  Widget _buildEffectGroup(BuildContext context, WidgetRef ref, String title, Map<FilterType, String> effects) {
    final currentFilter = ref.watch(filterTypeProvider);
    
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
              selected: currentFilter == entry.key,
              onSelected: (val) {
                if (val) {
                  ref.read(filterTypeProvider.notifier).setFilter(entry.key);
                }
              },
              showCheckmark: false,
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolMode = ref.watch(toolModeProvider);
    final intensity = ref.watch(intensityProvider);
    final brushSize = ref.watch(brushSizeProvider);
    final filterType = ref.watch(filterTypeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Werkzeug', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SegmentedButton<ToolMode>(
            segments: const [
              ButtonSegment(value: ToolMode.draw, icon: Icon(Icons.brush), label: Text('Zeichnen')),
              ButtonSegment(value: ToolMode.erase, icon: Icon(Icons.cleaning_services), label: Text('Radieren')),
            ],
            selected: {toolMode},
            onSelectionChanged: (newSel) => ref.read(toolModeProvider.notifier).setMode(newSel.first),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Effekt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          _buildEffectGroup(context, ref, 'Verpixelung & Raster', {
            FilterType.pixelate: 'Mosaik', FilterType.hexagon: 'Hexagon', FilterType.drei: 'Dreiecke',
            FilterType.polygon: 'Voronoi', FilterType.punkt: 'Punkte', FilterType.retroDot: 'Retro Dot',
          }),
          
          _buildEffectGroup(context, ref, 'Unschärfe', {
            FilterType.unscha1: 'Gauß (Leicht)', FilterType.unscha2: 'Gauß (Stark)', FilterType.weich: 'Weichzeichner',
            FilterType.linie1: 'Motion (Horiz.)', FilterType.linie2: 'Motion (Diag.)', FilterType.bewe: 'Motion (Vert.)',
            FilterType.zoom: 'Zoom',
          }),

          _buildEffectGroup(context, ref, 'Künstlerisch & Glas', {
            FilterType.kris: 'Kristallisieren', FilterType.glas1: 'Milchglas', FilterType.glas2: 'Prisma',
          }),

          _buildEffectGroup(context, ref, 'Abdeckung', {
            FilterType.solidColor: 'Zensurbalken',
          }),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 24),

          const Text('Feinabstimmung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Intensität'),
          Row(
            children: [
              const Icon(Icons.tune, size: 20),
              Expanded(
                child: Slider(
                  value: intensity,
                  min: 0.0,
                  max: 100.0,
                  label: '${intensity.toInt()} %',
                  onChanged: filterType == FilterType.solidColor ? null : (val) => ref.read(intensityProvider.notifier).setIntensity(val),
                ),
              ),
              SizedBox(width: 45, child: Text('${intensity.toInt()} %')),
            ],
          ),

          const SizedBox(height: 16),
          const Text('Pinselgröße'),
          Row(
            children: [
              const Icon(Icons.circle, size: 16),
              Expanded(
                child: Slider(
                  value: brushSize,
                  min: 10.0,
                  max: 80.0,
                  label: '${brushSize.toInt()} px',
                  onChanged: (val) => ref.read(brushSizeProvider.notifier).setSize(val),
                ),
              ),
              SizedBox(width: 45, child: Text('${brushSize.toInt()} px')),
            ],
          ),
        ],
      ),
    );
  }
}
