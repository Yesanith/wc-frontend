part of '../settings_screen.dart';

/// switch between saved api keys, add or remove them
class _AccountsPanel extends ConsumerWidget {
  const _AccountsPanel();

  String _mask(String key) =>
      key.length <= 12 ? '********' : '${key.substring(0, 8)}...${key.substring(key.length - 4)}';

  Future<void> _remove(BuildContext context, WidgetRef ref, int index, String label) async {
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
    if (ok == true) await ref.read(keysProvider.notifier).removeAt(index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final keys = ref.watch(keysProvider).valueOrNull ?? const <StoredKey>[];
    final active = ref.watch(activeKeyProvider);
    final info = ref.watch(tokenInfoProvider);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < keys.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => ref.read(activeKeyProvider.notifier).set(i),
              leading: Icon(
                i == active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: i == active ? AppColors.gold : AppColors.muted,
              ),
              title: Text(keys[i].name.isEmpty ? s.t('unnamed_account') : keys[i].name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_mask(keys[i].key),
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.muted)),
              trailing: IconButton(
                tooltip: s.t('remove_key'),
                onPressed: () => _remove(context, ref, i, keys[i].name),
                icon: Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 4),
          if (keys.isEmpty)
            Text(s.t('guest_note'), style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted))
          else
            AsyncView<Json>(
              value: info,
              onRetry: () => ref.invalidate(tokenInfoProvider),
              builder: (i) {
                final perms = ((i['permissions'] as List?) ?? const []).map((e) => '$e').toList();
                return Wrap(spacing: 6, runSpacing: 6, children: [for (final p in perms) Pill(p)]);
              },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(keys.isEmpty ? s.t('add_api_key') : s.t('add_account')),
          ),
        ],
      ),
    );
  }
}

/// the paste field for a backup, which disposes its own controller once the
/// dialog is gone
class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.s});

  final S s;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.t('import_backup')),
      content: TextField(
        controller: _ctrl,
        maxLines: 6,
        decoration: fieldDecoration(s.t('import_hint')),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.t('cancel'))),
        FilledButton(onPressed: () => Navigator.of(context).pop(_ctrl.text), child: Text(s.t('import_backup'))),
      ],
    );
  }
}
