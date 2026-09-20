import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _mask(String key) {
    if (key.length <= 12) return '********';
    return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('remove_key')),
        content: Text(s.t('remove_key_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.t('remove'))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(apiKeyProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final info = ref.watch(tokenInfoProvider);
    final key = ref.watch(apiKeyProvider).valueOrNull ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(s.t('nav_settings'), style: display(28)),
        const SizedBox(height: 16),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(s.t('language').toUpperCase()),
              const SizedBox(height: 4),
              for (final l in AppLang.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => ref.read(langProvider.notifier).set(l),
                  leading: Icon(
                    l == lang ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: l == lang ? AppColors.gold : AppColors.muted,
                  ),
                  title: Text(l.nativeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Text(l.code.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                ),
              const Divider(color: AppColors.track),
              const SizedBox(height: 4),
              _InfoRow(
                s.t('data_language'),
                lang.apiLang == lang.code ? lang.nativeName : s.t('data_lang_fallback'),
              ),
              const SizedBox(height: 6),
              _InfoRow(s.t('wiki_source'), Uri.parse(lang.wikiBase).host),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(s.t('api_key').toUpperCase()),
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
                      Text(s.t('key_name', {'n': i['name'] ?? '-'}),
                          style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final p in perms) Pill(p)],
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
          label: Text(s.t('remove_key')),
        ),
        const SizedBox(height: 28),
        Text(s.t('disclaimer'), style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.hint)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
