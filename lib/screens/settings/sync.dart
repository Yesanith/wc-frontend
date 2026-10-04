part of '../settings_screen.dart';

/// launch sync status, with a way to pull the account down again
class _SyncPanel extends ConsumerWidget {
  const _SyncPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final sync = ref.watch(syncProvider);
    final at = sync.finishedAt;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('sync_now').toUpperCase()),
          const SizedBox(height: 8),
          Text(s.t('sync_note'), style: TextStyle(fontSize: 13, color: AppColors.textSoft, height: 1.4)),
          if (sync.running) ...[
            const SizedBox(height: 12),
            Bar(value: sync.ratio),
            const SizedBox(height: 6),
            Text('${s.t('syncing')} ${sync.done}/${sync.total}',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ] else if (at != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${pad2(at.hour)}:${pad2(at.minute)}', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                if (sync.failed > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.error_outline, size: 14, color: AppColors.red),
                  const SizedBox(width: 4),
                  Text('${sync.failed}', style: TextStyle(fontSize: 12, color: AppColors.red)),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: sync.running ? null : () => ref.read(syncProvider.notifier).run(),
            icon: const Icon(Icons.sync, size: 18),
            label: Text(s.t('sync_now')),
          ),
        ],
      ),
    );
  }
}

/// shows the installed version and offers the apk of a newer release
class _UpdatePanel extends ConsumerWidget {
  const _UpdatePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final update = ref.watch(updateProvider);
    final latest = update.valueOrNull;
    final hasUpdate = latest != null && latest.isNewerThan;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.t('version'), style: TextStyle(fontSize: 14, color: AppColors.textSoft)),
              ),
              Text(appVersion, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold)),
              IconButton(
                tooltip: s.t('check_updates'),
                onPressed: () => ref.invalidate(updateProvider),
                icon: Icon(Icons.refresh, size: 20, color: AppColors.muted),
              ),
            ],
          ),
          if (update.isLoading)
            Text(s.t('checking'), style: TextStyle(fontSize: 12, color: AppColors.muted))
          else if (update.hasError)
            Text(s.t('check_failed'), style: TextStyle(fontSize: 12, color: AppColors.muted))
          else if (hasUpdate) ...[
            Text(s.t('update_available', {'v': latest.version}),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openUrl(
                      context,
                      latest.apkUrl ?? latest.pageUrl,
                      failMessage: s.t('open_failed'),
                    ),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(s.t('download_update')),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => openUrl(context, latest.pageUrl, failMessage: s.t('open_failed')),
                  child: Text(s.t('release_notes')),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(s.t('install_note'), style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.hint)),
          ] else
            Text(s.t('up_to_date'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
