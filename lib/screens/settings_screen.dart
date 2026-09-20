import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _mask(String key) {
    if (key.length <= 12) return '••••••••';
    return '${key.substring(0, 8)}…${key.substring(key.length - 4)}';
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Key'i kaldır"),
        content: const Text('API key bu cihazdan silinecek ve giriş ekranına döneceksin.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Kaldır')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(apiKeyProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(tokenInfoProvider);
    final key = ref.watch(apiKeyProvider).valueOrNull ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Ayarlar', style: display(28)),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Kicker('API KEY'),
              const SizedBox(height: 8),
              Text(_mask(key), style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
              const SizedBox(height: 14),
              AsyncView<Json>(
                value: info,
                onRetry: () => ref.invalidate(tokenInfoProvider),
                builder: (i) {
                  final perms = ((i['permissions'] as List?) ?? const []).map((e) => '$e').toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Key adı: ${i['name'] ?? '-'}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final p in perms)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(p,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSoft)),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _confirmRemove(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.red,
            side: const BorderSide(color: AppColors.red),
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.logout),
          label: const Text("Key'i kaldır"),
        ),
        const SizedBox(height: 28),
        const Text(
          'Tyria Codex resmi olmayan bir hayran uygulamasıdır. Guild Wars 2, ArenaNet ve NCSOFT '
          'ilgili sahiplerinin ticari markalarıdır. Veriler resmi GW2 API ve Guild Wars 2 Wiki '
          'üzerinden alınır.',
          style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.hint),
        ),
      ],
    );
  }
}
