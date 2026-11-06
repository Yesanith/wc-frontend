part of '../settings_screen.dart';

/// the link between the account and the Blish HUD module, the overlay of the game: the player asks for a code here and types it into the
/// module, which then shows the events in the game. a link is cut from here as well
class _ModuleLinkPanel extends ConsumerStatefulWidget {
  const _ModuleLinkPanel();

  @override
  ConsumerState<_ModuleLinkPanel> createState() => _ModuleLinkPanelState();
}

class _ModuleLinkPanelState extends ConsumerState<_ModuleLinkPanel> {
  bool _busy = false;
  ModuleLinkCode? _code;

  Future<void> _get() async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      final code = await createModuleLinkCode();
      if (mounted) setState(() => _code = code);
    } catch (_) {
      if (mounted) showToast(context, s.t('community_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String code) async {
    final s = ref.read(stringsProvider);
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) showToast(context, s.t('module_link_copied'));
  }

  Future<void> _cut(ModuleLink link) async {
    final s = ref.read(stringsProvider);
    try {
      await revokeModuleLink(link.id);
      ref.invalidate(myModuleLinksProvider);
    } catch (_) {
      if (mounted) showToast(context, s.t('community_failed'));
    }
  }

  String _when(DateTime at) => '${at.year}-${pad2(at.month)}-${pad2(at.day)} ${pad2(at.hour)}:${pad2(at.minute)}';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    // a code that has run out is not shown any more
    final shown = _code;
    final code = shown != null && shown.expiresAt.isAfter(DateTime.now()) ? shown : null;
    final links = ref.watch(myModuleLinksProvider).valueOrNull ?? const <ModuleLink>[];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(s.t('module_link_title').toUpperCase()),
          const SizedBox(height: 8),
          Text(s.t('module_link_note'), style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted)),
          const SizedBox(height: 12),
          if (code != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          code.code,
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3, color: AppColors.gold),
                        ),
                        const SizedBox(height: 2),
                        Text(s.t('module_link_expires'), style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: s.t('module_link_copy'),
                    onPressed: () => _copy(code.code),
                    icon: Icon(Icons.copy, color: AppColors.gold),
                  ),
                ],
              ),
            )
          else
            FilledButton.icon(
              onPressed: _busy ? null : _get,
              icon: const Icon(Icons.link, size: 18),
              label: Text(s.t('module_link_get')),
            ),
          const SizedBox(height: 14),
          if (links.isEmpty)
            Text(s.t('module_link_none'), style: TextStyle(fontSize: 12, color: AppColors.hint))
          else
            for (final link in links)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.extension_outlined, size: 20, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(link.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(
                            link.lastUsedAt == null
                                ? s.t('module_link_never')
                                : s.t('module_link_used', {'when': _when(link.lastUsedAt!)}),
                            style: TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: s.t('module_link_cut'),
                      onPressed: () => _cut(link),
                      icon: Icon(Icons.link_off, size: 20, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
