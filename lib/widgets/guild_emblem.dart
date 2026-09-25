import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/icon_cache.dart';
import '../state/reference.dart';
import '../theme.dart';
import '../util.dart';

/// a guild emblem rebuilt from its layers: the background tinted with its
/// dye, then the two foreground layers with theirs, flipped as the guild set
class GuildEmblem extends ConsumerWidget {
  const GuildEmblem({super.key, required this.emblem, this.size = 48});

  final Json? emblem;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgs = ref.watch(emblemBackgroundsProvider).valueOrNull;
    final fgs = ref.watch(emblemForegroundsProvider).valueOrNull;
    final colors = ref.watch(colorsProvider).valueOrNull;
    final e = emblem;
    if (e == null || bgs == null || fgs == null || colors == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.shield_outlined, size: size * 0.7, color: AppColors.muted),
      );
    }
    final bg = e['background'] is Map ? Map<String, dynamic>.from(e['background'] as Map) : const <String, dynamic>{};
    final fg = e['foreground'] is Map ? Map<String, dynamic>.from(e['foreground'] as Map) : const <String, dynamic>{};
    final flags = {for (final f in (e['flags'] as List?) ?? const []) '$f'};
    final bgLayers = [for (final l in (bgs['${bg['id']}']?['layers'] as List?) ?? const []) '$l'];
    final fgLayers = [for (final l in (fgs['${fg['id']}']?['layers'] as List?) ?? const []) '$l'];
    final bgColors = intList(bg['colors']);
    final fgColors = intList(fg['colors']);

    Widget layer(String url, int? colorId, {required bool flipH, required bool flipV}) {
      final tint = colorId == null ? null : dyeColor(colors['$colorId']);
      Widget img = CachedIcon(url: url, fit: BoxFit.contain);
      // the layers are greyscale masks, multiplying keeps their shading
      if (tint != null) img = ColorFiltered(colorFilter: ColorFilter.mode(tint, BlendMode.modulate), child: img);
      if (flipH || flipV) img = Transform.scale(scaleX: flipH ? -1 : 1, scaleY: flipV ? -1 : 1, child: img);
      return Positioned.fill(child: img);
    }

    final flipBgH = flags.contains('FlipBackgroundHorizontal');
    final flipBgV = flags.contains('FlipBackgroundVertical');
    final flipFgH = flags.contains('FlipForegroundHorizontal');
    final flipFgV = flags.contains('FlipForegroundVertical');

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          if (bgLayers.isNotEmpty)
            layer(bgLayers.first, bgColors.isEmpty ? null : bgColors.first, flipH: flipBgH, flipV: flipBgV),
          // layer 0 of a foreground is a flat preview, 1 and 2 take the two dyes
          if (fgLayers.length > 1)
            layer(fgLayers[1], fgColors.isEmpty ? null : fgColors[0], flipH: flipFgH, flipV: flipFgV),
          if (fgLayers.length > 2)
            layer(fgLayers[2], fgColors.length < 2 ? null : fgColors[1], flipH: flipFgH, flipV: flipFgV),
        ],
      ),
    );
  }
}
