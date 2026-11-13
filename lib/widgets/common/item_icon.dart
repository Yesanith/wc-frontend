import 'package:flutter/material.dart';

import '../../services/icon_cache.dart';
import '../../theme.dart';
import '../responsive.dart';
import 'surfaces.dart';

/// icon, title, optional subtitle and trailing widget. the shape of almost
/// every list in the app
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    this.icon,
    this.rarity,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconSize = 40,
    this.titleLines = 2,
  });

  final String? icon;
  final String? rarity;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double iconSize;
  final int titleLines;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    final end = trailing;
    // on the site a list is a table: flat rows with a line between them, not a card each
    if (SiteScope.of(context)) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.track))),
            child: Row(
              children: [
                ItemIcon(url: icon, rarity: rarity, size: iconSize < 34 ? iconSize : 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      if (sub != null)
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                if (end != null) ...[const SizedBox(width: 8), end],
              ],
            ),
          ),
        ),
      );
    }
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ItemIcon(url: icon, rarity: rarity, size: iconSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                if (sub != null) Text(sub, style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          if (end != null) ...[const SizedBox(width: 8), end],
        ],
      ),
    );
  }
}

class ItemIcon extends StatelessWidget {
  const ItemIcon({super.key, this.url, this.rarity, this.size, this.count, this.empty = false, this.bound});

  final String? url;
  final String? rarity;
  final double? size;
  final int? count;
  final bool empty;

  /// Account or Character where the item is bound, drawn as a small mark in the corner
  final String? bound;

  @override
  Widget build(BuildContext context) {
    final fixed = size;
    if (fixed != null) return SizedBox.square(dimension: fixed, child: _framed(fixed));
    // in a grid the cell decides the size
    return LayoutBuilder(builder: (context, box) {
      final side = box.biggest.shortestSide.isFinite ? box.biggest.shortestSide : 44.0;
      return _framed(side);
    });
  }

  Widget _framed(double side) {
    final u = url;
    final n = count;
    // rounder corners on bigger icons, a frame drawn over the art so the
    // image never covers the rarity colour
    final radius = BorderRadius.circular(side * 0.22);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: empty ? AppColors.track : (rarity == null ? AppColors.line : rarityColor(rarity)),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: ColoredBox(
              color: empty ? AppColors.navBg : AppColors.surface2,
              child: empty || u == null ? const SizedBox.expand() : CachedIcon(url: u),
            ),
          ),
        ),
        if (!empty && bound != null && side >= 30)
          Positioned(
            left: 3,
            top: 3,
            child: Icon(
              bound == 'Character' ? Icons.lock : Icons.person,
              size: (side * 0.26).clamp(9, 14).toDouble(),
              color: Colors.white,
              shadows: const [Shadow(blurRadius: 3), Shadow(blurRadius: 1)],
            ),
          ),
        if (!empty && n != null && n > 1)
          Positioned(
            right: 3,
            bottom: 1,
            child: Text(
              n > 9999 ? '${n ~/ 1000}k' : '$n',
              style: TextStyle(
                fontSize: (side * 0.26).clamp(9, 14).toDouble(),
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 3), Shadow(blurRadius: 1)],
              ),
            ),
          ),
      ],
    );
  }
}
