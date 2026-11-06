import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  static const _optional = ['builds', 'progression', 'unlocks', 'tradingpost', 'pvp', 'guilds', 'wvw'];

  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  /// set once the key checked out: its account and permissions
  String? _account;
  List<String>? _perms;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && mounted) setState(() => _ctrl.text = text.trim());
  }

  Future<void> _connect() async {
    final s = ref.read(stringsProvider);
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = s.t('err_empty_key'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _account = null;
      _perms = null;
    });
    // one client for both checks, closed again whatever happens
    final api = Gw2Api(key);
    try {
      final info = await api.tokenInfo();
      final perms = ((info['permissions'] as List?) ?? const []).map((e) => '$e').toList();
      // label the key with the account it belongs to
      var accountName = '${info['name'] ?? ''}';
      try {
        final account = await api.account();
        accountName = '${account['name'] ?? accountName}';
      } catch (_) {}
      final missing = _required.where((p) => !perms.contains(p)).toList();
      if (!mounted) return;
      setState(() {
        _account = accountName;
        _perms = perms;
        if (missing.isNotEmpty) _error = s.t('err_missing_perms', {'p': missing.join(', ')});
      });
    } catch (e) {
      if (mounted) setState(() => _error = s.t('err_key_invalid', {'e': e}));
    } finally {
      api.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    await ref.read(keysProvider.notifier).add(_ctrl.text.trim(), _account ?? '');
    // a key ends the guest choice, after the key is in so the app never
    // passes through the welcome screen on its way
    await ref.read(guestModeProvider.notifier).set(false);
    // opened from settings as a route: go back once the key is saved
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  bool get _ready => _perms != null && _required.every(_perms!.contains);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final error = _error;
    final perms = _perms;
    return Scaffold(
      body: Stack(
        children: [
          // two soft glows behind the title
          Positioned(top: -120, left: -80, child: _Glow(color: AppColors.gold.withValues(alpha: 0.2), size: 360)),
          Positioned(top: 40, right: -120, child: _Glow(color: AppColors.ember.withValues(alpha: 0.14), size: 300)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Row(
                  children: [
                    const DiamondEmblem(size: 34),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Wondrous Compass', style: display(19))),
                    PopupMenuButton<AppLang>(
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
                            Icon(Icons.translate, size: 18, color: AppColors.gold),
                            const SizedBox(width: 6),
                            Text(
                              lang.nativeName,
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(s.t('welcome_title'), style: display(34).copyWith(height: 1.15)),
                const SizedBox(height: 12),
                Text(s.t('welcome_body'), style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.muted)),
                const SizedBox(height: 24),
                _Step(1, s.t('step_create')),
                Padding(
                  padding: const EdgeInsets.only(left: 40, top: 6, bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          openUrl(context, 'https://account.arena.net/applications', failMessage: s.t('open_failed')),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(s.t('open_arena_net')),
                    ),
                  ),
                ),
                _Step(2, s.t('step_paste')),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  autocorrect: false,
                  enableSuggestions: false,
                  minLines: 1,
                  maxLines: 2,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  onChanged: (_) => setState(() {
                    _account = null;
                    _perms = null;
                    _error = null;
                  }),
                  onSubmitted: (_) => _connect(),
                  decoration: fieldDecoration(
                    'XXXXXXXX-XXXX-XXXX-XXXX-…',
                    suffixIcon: IconButton(
                      tooltip: s.t('paste'),
                      icon: const Icon(Icons.content_paste_rounded),
                      onPressed: _paste,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (perms != null) ...[
                  _TokenCard(account: _account ?? '', perms: perms, required: _required, optional: _optional),
                  const SizedBox(height: 12),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      error,
                      style: TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : (_ready ? _save : _connect),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.onGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onGold),
                          )
                        : Text(
                            _ready ? s.t('continue') : s.t('connect'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
                // the first screen only: opened from settings there is a key or a way back
                if (!Navigator.of(context).canPop()) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : () => ref.read(guestModeProvider.notifier).set(true),
                      child: Text(s.t('guest_continue'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Text(
                    s.t('guest_note'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppColors.hint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.t('privacy_note'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// what the key turned out to be: whose it is and what it may read
class _TokenCard extends ConsumerWidget {
  const _TokenCard({required this.account, required this.perms, required this.required, required this.optional});

  final String account;
  final List<String> perms;
  final List<String> required;
  final List<String> optional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final ok = required.every(perms.contains);
    final tint = ok ? AppColors.green : AppColors.amber;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: tint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.t('key_for', {'name': account}),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Kicker(s.t('permissions'), color: AppColors.muted),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in [...required, ...optional])
                _PermChip(p, granted: perms.contains(p), isRequired: required.contains(p)),
            ],
          ),
        ],
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
          child: Text(
            '$number',
            style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSoft)),
        ),
      ],
    );
  }
}

class _PermChip extends StatelessWidget {
  const _PermChip(this.label, {required this.granted, required this.isRequired});

  final String label;
  final bool granted;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    // a missing required permission is the one thing worth flagging in red
    final color = granted ? AppColors.green : (isRequired ? AppColors.red : AppColors.hint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(granted ? Icons.check : Icons.remove, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: granted ? AppColors.text : AppColors.muted)),
        ],
      ),
    );
  }
}
