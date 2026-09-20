import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(accountProvider);
    ref.invalidate(walletProvider);
    ref.invalidate(vaultProvider);
    try {
      await ref.read(accountProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final wallet = ref.watch(walletProvider);
    final vault = ref.watch(vaultProvider);
    final v = vault.valueOrNull;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _refresh(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          AsyncView<Json>(
            value: account,
            onRetry: () => ref.invalidate(accountProvider),
            builder: (a) => _AccountHeader(a),
          ),
          const SizedBox(height: 14),
          AsyncView<List<WalletEntry>>(
            value: wallet,
            onRetry: () => ref.invalidate(walletProvider),
            builder: (w) => _WalletStrip(w),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: "Wizard's Vault · Günlük",
            trailing: v == null
                ? null
                : '${asInt(v['meta_progress_current'])}/${asInt(v['meta_progress_complete'])}',
          ),
          const SizedBox(height: 10),
          AsyncView<Json>(
            value: vault,
            onRetry: () => ref.invalidate(vaultProvider),
            builder: (data) => _VaultList(data),
          ),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader(this.a);

  final Json a;

  @override
  Widget build(BuildContext context) {
    final wvw = a['wvw'];
    final rank = wvw is Map ? asInt(wvw['rank']) : asInt(a['wvw_rank']);
    final created = '${a['created'] ?? ''}';
    final year = created.length >= 4 ? created.substring(0, 4) : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hoş geldin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
        Text('${a['name'] ?? ''}', style: display(26)),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StatTile(label: 'Oynama süresi', value: fmtHours(a['age']))),
                  Expanded(child: StatTile(label: 'WvW rank', value: rank > 0 ? fmtInt(rank) : '-')),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: StatTile(label: 'Fractal seviyesi', value: '${asInt(a['fractal_level'])}')),
                  Expanded(child: StatTile(label: 'Hesap açılışı', value: year)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalletStrip extends StatelessWidget {
  const _WalletStrip(this.entries);

  final List<WalletEntry> entries;

  int _value(int id) {
    for (final e in entries) {
      if (e.id == id) return e.value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final coins = Coins(_value(1));
    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            dot: AppColors.gold,
            label: 'Altın',
            value: '${fmtInt(coins.gold)} g',
            sub: '${coins.silver} s ${coins.copper} c',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniCard(dot: const Color(0xFFD58CF0), label: 'Karma', value: compact(_value(2))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniCard(dot: AppColors.green, label: 'Laurel', value: fmtInt(_value(3))),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.dot, required this.label, required this.value, this.sub});

  final Color dot;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final s = sub;
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          if (s != null) Text(s, style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
        ],
      ),
    );
  }
}

class _VaultList extends StatelessWidget {
  const _VaultList(this.data);

  final Json data;

  @override
  Widget build(BuildContext context) {
    final objectives = ((data['objectives'] as List?) ?? const []).whereType<Map>().toList();
    if (objectives.isEmpty) {
      return const Panel(
        child: Text('Bugün için görev bulunamadı.', style: TextStyle(color: AppColors.muted)),
      );
    }
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < objectives.length; i++)
            _VaultRow(Map<String, dynamic>.from(objectives[i]), last: i == objectives.length - 1),
        ],
      ),
    );
  }
}

class _VaultRow extends StatelessWidget {
  const _VaultRow(this.o, {required this.last});

  final Json o;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cur = asInt(o['progress_current']);
    final total = asInt(o['progress_complete']);
    final done = total > 0 && cur >= total;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.track)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${o['title'] ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.muted : AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$cur/$total',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Bar(value: total == 0 ? 0 : cur / total, color: done ? AppColors.green : AppColors.gold),
        ],
      ),
    );
  }
}
