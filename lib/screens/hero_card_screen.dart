import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

enum CardStyle { dark, gold, profession }

class HeroCardScreen extends ConsumerStatefulWidget {
  const HeroCardScreen({super.key, required this.name});

  final String name;

  @override
  ConsumerState<HeroCardScreen> createState() => _HeroCardScreenState();
}

class _HeroCardScreenState extends ConsumerState<HeroCardScreen> {
  final _cardKey = GlobalKey();
  CardStyle _style = CardStyle.dark;
  bool _busy = false;

  Future<void> _share() async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/hero_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: '${widget.name} · Tyria Codex');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('share_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final chars = ref.watch(charactersProvider).valueOrNull;
    final account = ref.watch(accountProvider).valueOrNull;
    final c = chars == null ? null : characterByName(chars, widget.name);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('hero_card'), style: display(20)),
      ),
      body: c == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                RepaintBoundary(
                  key: _cardKey,
                  child: _HeroCard(c: c, account: account, style: _style),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final st in CardStyle.values) ...[
                      Expanded(
                        child: Center(
                          child: ChoiceChip(
                            label: Text(s.t('style_${st.name}')),
                            selected: _style == st,
                            onSelected: (_) => setState(() => _style = st),
                          ),
                        ),
                      ),
                      if (st != CardStyle.values.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.ios_share),
                    label: Text(s.t('share')),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.c, required this.account, required this.style});

  final Json c;
  final Json? account;
  final CardStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final prof = '${c['profession'] ?? ''}';
    final pc = professionColor(prof);

    final Color bg;
    final Color fg;
    final Color muted;
    final Color accent;
    switch (style) {
      case CardStyle.dark:
        bg = AppColors.surface;
        fg = AppColors.text;
        muted = AppColors.muted;
        accent = pc;
      case CardStyle.gold:
        bg = AppColors.gold;
        fg = AppColors.onGold;
        muted = const Color(0xFF5A4520);
        accent = AppColors.onGold;
      case CardStyle.profession:
        bg = Color.lerp(AppColors.bg, pc, 0.35)!;
        fg = AppColors.text;
        muted = AppColors.textSoft;
        accent = AppColors.gold;
    }

    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted)),
            ],
          ),
        );

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withAlpha(140), width: 2),
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: DiamondEmblem(size: 120, color: accent),
              ),
            ),
            Text('${c['name'] ?? ''}', textAlign: TextAlign.center, style: display(28, color: fg)),
            const SizedBox(height: 4),
            Text('$prof · ${c['race'] ?? ''}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accent)),
            const SizedBox(height: 16),
            Divider(color: muted.withAlpha(90), height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                stat(s.t('level'), '${asInt(c['level'])}'),
                stat(s.t('hours'), fmtInt(asInt(c['age']) ~/ 3600)),
                stat(s.t('deaths'), fmtInt(asInt(c['deaths']))),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'TYRIA CODEX${account?['name'] != null ? ' · ${account!['name']}' : ''}'.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
