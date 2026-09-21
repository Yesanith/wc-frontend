import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gw2_api.dart';
import '../l10n/strings.dart';
import '../state/api.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _required = ['account', 'characters', 'inventories', 'wallet'];
  static const _optional = ['builds', 'progression', 'unlocks', 'tradingpost', 'pvp', 'guilds'];

  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null) setState(() => _ctrl.text = text.trim());
  }

  Future<void> _connect() async {
    final s = ref.read(stringsProvider);
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = s.t('err_empty_key'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await Gw2Api(key).tokenInfo();
      final perms = ((info['permissions'] as List?) ?? const []).map((e) => '$e').toList();
      final missing = _required.where((p) => !perms.contains(p)).toList();
      if (missing.isNotEmpty) {
        setState(() => _error = s.t('err_missing_perms', {'p': missing.join(', ')}));
        return;
      }
      // label the key with the account it belongs to
      var accountName = '${info['name'] ?? ''}';
      try {
        final account = await Gw2Api(key).account();
        accountName = '${account['name'] ?? accountName}';
      } catch (_) {}
      await ref.read(keysProvider.notifier).add(key, accountName);
    } catch (e) {
      if (mounted) setState(() => _error = s.t('err_key_invalid', {'e': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final error = _error;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<AppLang>(
                tooltip: s.t('language'),
                initialValue: lang,
                onSelected: (l) => ref.read(langProvider.notifier).set(l),
                itemBuilder: (_) => [
                  for (final l in AppLang.values) PopupMenuItem(value: l, child: Text(l.nativeName)),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.translate, size: 18, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text(lang.nativeName,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: DiamondEmblem(size: 72)),
            const SizedBox(height: 12),
            Text('Tyria Codex', textAlign: TextAlign.center, style: display(34)),
            const SizedBox(height: 6),
            Text(
              s.t('tagline'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(s.t('how_to_get_key')),
                  const SizedBox(height: 14),
                  _Step(1, s.t('step1')),
                  const SizedBox(height: 12),
                  _Step(2, s.t('step2')),
                  const SizedBox(height: 12),
                  _Step(3, s.t('step3')),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => openUrl(context, 'https://account.arena.net/applications',
                        failMessage: s.t('open_failed')),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(s.t('open_arena_net')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(s.t('api_key'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSoft)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: fieldDecoration('XXXXXXXX-XXXX-XXXX-…'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: IconButton.filledTonal(
                    onPressed: _paste,
                    tooltip: s.t('paste'),
                    icon: const Icon(Icons.content_paste),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Kicker(s.t('permissions'), color: AppColors.muted),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _required) _PermChip(p, isRequired: true),
                for (final p in _optional) _PermChip(s.t('optional_perm', {'p': p}), isRequired: false),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(error, style: const TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _busy ? null : _connect,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.onGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onGold),
                      )
                    : Text(s.t('connect'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(s.t('key_local_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold),
          ),
          child: Text('$number',
              style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSoft)),
        ),
      ],
    );
  }
}

class _PermChip extends StatelessWidget {
  const _PermChip(this.label, {required this.isRequired});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isRequired ? Icons.check : Icons.add, size: 14, color: isRequired ? AppColors.green : AppColors.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isRequired ? AppColors.textSoft : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
