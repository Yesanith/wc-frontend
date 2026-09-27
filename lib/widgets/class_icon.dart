import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/icon_cache.dart';
import '../state/professions.dart';
import '../theme.dart';
import '../util.dart';

/// a character's class icon in a frame of its profession colour: the elite
/// line's icon when one is slotted, else the profession's. until the icons
/// load it shows [fallback]
class ClassIcon extends ConsumerWidget {
  const ClassIcon({super.key, required this.character, required this.size, required this.fallback});

  final Json character;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prof = '${character['profession'] ?? ''}';
    final color = professionColor(prof);
    final info = ref.watch(professionsProvider).valueOrNull?[prof];
    final url = classIcon(character, info, big: size > 48);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color, width: 2),
      ),
      child: url == null ? fallback : CachedIcon(url: url, fit: BoxFit.contain),
    );
  }
}

/// just the icon of a profession, for lists that have no character
class ProfessionIcon extends StatelessWidget {
  const ProfessionIcon({super.key, required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final u = url;
    return SizedBox(
      width: size,
      height: size,
      child: u == null ? null : CachedIcon(url: u, fit: BoxFit.contain),
    );
  }
}
