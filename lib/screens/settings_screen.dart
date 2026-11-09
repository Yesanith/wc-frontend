import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../l10n/strings.dart';
import '../services/backup.dart';
import '../services/icon_cache.dart';
import '../services/sync.dart';
import '../services/update_check.dart';
import '../state/account.dart';
import '../state/api.dart';
import '../services/boss_alerts.dart';
import '../services/push.dart';
import '../services/web_push.dart';
import '../state/boss_alerts.dart';
import '../state/community.dart';
import '../state/kept_keys.dart';
import '../state/link_refresh.dart';
import '../state/module_link.dart';
import 'guild_roster_screen.dart';
import '../state/settings.dart';
import '../state/trade_notify.dart';
import '../state/trade_watch.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/site_header.dart' show sitePageUrl;
import '../widgets/trade_watch_ask.dart';
import '../widgets/ui_zoom.dart';
import 'onboarding_screen.dart';

part 'settings/sync.dart';
part 'settings/accounts.dart';
part 'settings/community.dart';
part 'settings/module.dart';
part 'settings/alerts.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    // the dialog owns its text field's controller: disposing it here, as soon
    // as the dialog returned, broke the field while the dialog animated out
    final text = await showDialog<String>(context: context, builder: (_) => _ImportDialog(s: s));
    if (text == null || text.trim().isEmpty) return;
    var message = s.t('imported');
    try {
      await restoreBackup(ref, text);
    } catch (_) {
      message = s.t('import_failed');
    }
    if (context.mounted) {
      showToast(context, message);
    }
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    await clearCache(ref.read(diskCacheProvider));
    // the copy in memory too, otherwise the next save writes it straight back
    ref.read(gw2ApiProvider).clearStaticCaches();
    await ref.read(iconCacheProvider)?.clear();
    if (context.mounted) {
      showToast(context, s.t('cache_cleared'));
    }
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final current = ref.watch(langProvider);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final l in AppLang.values)
                    ListTile(
                      onTap: () {
                        ref.read(langProvider.notifier).set(l);
                        Navigator.of(ctx).pop();
                      },
                      leading: Icon(
                        l == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: l == current ? AppColors.gold : AppColors.muted,
                      ),
                      title: Text(l.nativeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: Text(l.code.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final signedIn = communityReady && ref.watch(sessionProvider).valueOrNull != null;
    final tradeWatchOn = signedIn && (ref.watch(tradeWatchesProvider).valueOrNull?.any((w) => w.on) ?? false);

    final sections = <_Section>[
      // who the player is: the community account (shown only in builds that know the backend), the keys of the game,
      // and the addons of the game that link to the account
      if (communityReady)
        _Section(
          title: s.t('settings_account'),
          note: s.t('settings_account_note'),
          children: const [_CommunityPanel()],
        ),
      _Section(
        title: s.t('settings_keys'),
        note: s.t('settings_keys_note'),
        children: const [_AccountsPanel()],
      ),
      if (signedIn)
        _Section(
          title: s.t('settings_modules'),
          note: s.t('settings_modules_note'),
          children: const [_ModuleLinkPanel()],
        ),
      // how the app looks, in one card
      _Section(
        title: s.t('settings_appearance'),
        note: s.t('settings_appearance_note'),
        children: [
          if (kIsWeb)
            _AppearanceRows(lang: lang)
          else
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(s.t('look').toUpperCase()),
                  const SizedBox(height: 10),
                  const _LookChoice(),
                  Divider(height: 28, color: AppColors.track),
                  Kicker(s.t('language').toUpperCase()),
                  const SizedBox(height: 4),
                  // one line instead of nine, the list opens from the bottom
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _pickLanguage(context, ref),
                    leading: Icon(Icons.translate, color: AppColors.gold),
                    title: Text(lang.nativeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lang.code.toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                        const SizedBox(width: 4),
                        Icon(Icons.expand_more, color: AppColors.muted),
                      ],
                    ),
                  ),
                  _InfoRow(
                    s.t('data_language'),
                    lang.apiLang == lang.code ? lang.nativeName : s.t('data_lang_fallback'),
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(s.t('wiki_source'), Uri.parse(lang.wikiBase).host),
                  if (kIsWeb) ...[
                    Divider(height: 28, color: AppColors.track),
                    const _UiSizeChoice(),
                  ],
                ],
              ),
            ),
        ],
      ),
      if (bossAlertsReady || (signedIn && pushReady))
        _Section(
          title: s.t('settings_notifications'),
          note: s.t('settings_notifications_note'),
          children: [
            // what the trading post did for the player, told by the server even when the app is closed
            if (signedIn && pushReady) const _TradeWatchPanel(),
            if (bossAlertsReady) ...[
              const _BossAlertsPanel(),
              const _ResetAlertsPanel(),
              // or looked at by the phone alone, with the key that stays on it, for who would rather not give the
              // server anything. not both: every sale would be told twice
              if (!kIsWeb && !tradeWatchOn) const _TradeNotifyPanel(),
            ],
          ],
        ),
      _Section(
        title: s.t('settings_data'),
        note: s.t('settings_data_note'),
        children: [
          const _SyncPanel(),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(s.t('backup').toUpperCase()),
                const SizedBox(height: 8),
                Text(s.t('backup_note'), style: TextStyle(fontSize: 13, color: AppColors.textSoft, height: 1.4)),
                const SizedBox(height: 12),
                // on the web two buttons of their own size, on the phone two halves of the card
                if (kIsWeb)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => shareBackup(ref),
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: Text(s.t('export_backup')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _import(context, ref),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: Text(s.t('import_backup')),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => shareBackup(ref),
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: Text(s.t('export_backup')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _import(context, ref),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: Text(s.t('import_backup')),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _clearCache(context, ref),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: Text(s.t('clear_cache')),
                ),
              ],
            ),
          ),
        ],
      ),
      // an apk cannot be installed from a browser
      if (!kIsWeb) _Section(title: s.t('settings_app'), children: const [_UpdatePanel()]),
    ];
    // in a browser the settings are a page with its sections listed beside it, or above it on a phone;
    // the app keeps them one under the other
    if (kIsWeb) return _SettingsPage(sections: sections);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: sections,
    );
  }
}

/// a group of the settings: a title, a line on what it is for, and its cards one under the other
class _Section extends StatelessWidget {
  const _Section({required this.title, this.note, required this.children});

  final String title;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final n = note;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kIsWeb ? 0 : 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: display(kIsWeb ? 22 : 18)),
                if (n != null) ...[
                  const SizedBox(height: 3),
                  Text(n, style: TextStyle(fontSize: kIsWeb ? 14 : 12.5, height: 1.4, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
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
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.muted))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// how large the interface is in the browser: automatic, which grows with a wide screen, or one of the sizes
class _UiSizeChoice extends ConsumerWidget {
  const _UiSizeChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final chosen = ref.watch(uiScaleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(s.t('ui_scale').toUpperCase()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final size in uiScaleChoices)
              ChoiceChip(
                label: Text(size == null ? s.t('ui_scale_auto') : '${(size * 100).round()}%'),
                selected: chosen == size,
                onSelected: (_) => ref.read(uiScaleProvider.notifier).set(size),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(s.t('ui_scale_hint'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

/// light, dark or whichever the phone is set to
class _LookChoice extends ConsumerWidget {
  const _LookChoice({this.compact = false});

  /// at its own width, as a choice on a page, instead of across the card
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final mode = ref.watch(lookProvider);
    return SizedBox(
      width: compact ? null : double.infinity,
      child: SegmentedButton<LookMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: LookMode.system,
            icon: const Icon(Icons.brightness_auto_outlined, size: 18),
            label: Text(s.t(compact ? 'look_device' : 'look_system')),
          ),
          ButtonSegment(
            value: LookMode.light,
            icon: const Icon(Icons.light_mode_outlined, size: 18),
            label: Text(s.t('look_light')),
          ),
          ButtonSegment(
            value: LookMode.dark,
            icon: const Icon(Icons.dark_mode_outlined, size: 18),
            label: Text(s.t('look_dark')),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (picked) => ref.read(lookProvider.notifier).set(picked.first),
      ),
    );
  }
}

/// the settings as a page: the sections listed on the left, and a click on one brings it up; on a narrow screen the
/// list is a row above the page that scrolls sideways. the one being read is marked as the page scrolls
class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.sections});

  final List<_Section> sections;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final _scroll = ScrollController();
  final _keys = <GlobalKey>[];
  var _active = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_track);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<GlobalKey> _keysFor(int n) {
    while (_keys.length < n) {
      _keys.add(GlobalKey());
    }
    return _keys;
  }

  /// the section whose heading went last past the top of the page, or the last one at the bottom of it
  void _track() {
    final view = _scroll.position.context.storageContext.findRenderObject() as RenderBox?;
    if (view == null) return;
    final top = view.localToGlobal(Offset.zero).dy;
    var active = 0;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 4) {
      active = widget.sections.length - 1;
    } else {
      for (var i = 0; i < widget.sections.length; i++) {
        final box = _keys[i].currentContext?.findRenderObject() as RenderBox?;
        if (box == null) continue;
        if (box.localToGlobal(Offset.zero).dy - top <= 60) active = i;
      }
    }
    if (active != _active) setState(() => _active = active);
  }

  void _go(int i) {
    final target = _keys[i].currentContext;
    if (target == null) return;
    setState(() => _active = i);
    Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  Widget _link(int i, {required bool row}) {
    final on = i == _active;
    return Padding(
      padding: row ? const EdgeInsets.only(right: 4) : const EdgeInsets.only(bottom: 2),
      child: Material(
        color: on ? AppColors.track : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _go(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              widget.sections[i].title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: on ? AppColors.text : AppColors.textSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = _keysFor(widget.sections.length);
    final content = SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.sections.length; i++) KeyedSubtree(key: keys[i], child: widget.sections[i]),
              // room enough for the last section to come up to the top when its name is clicked
              const SizedBox(height: 240),
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 860) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 0, 0),
              child: SizedBox(
                width: 210,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (var i = 0; i < widget.sections.length; i++) _link(i, row: false)],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: content),
          ],
        );
      }
      return Column(
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.track))),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [for (var i = 0; i < widget.sections.length; i++) _link(i, row: true)],
            ),
          ),
          Expanded(child: content),
        ],
      );
    });
  }
}

/// how the site looks, as a short form: a name on the left and its choice beside it, or the name above the choice on
/// a phone
class _AppearanceRows extends ConsumerWidget {
  const _AppearanceRows({required this.lang});

  final AppLang lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final scale = ref.watch(uiScaleProvider);
    final field = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.line),
    );
    Widget dropdown<T>(T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) => Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: field,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              borderRadius: BorderRadius.circular(8),
              dropdownColor: AppColors.surface,
              style: TextStyle(fontSize: 14, color: AppColors.text),
              items: items,
              onChanged: onChanged,
            ),
          ),
        );
    final rows = <(String, Widget, String?)>[
      (s.t('look_theme'), const _LookChoice(compact: true), null),
      (
        s.t('language'),
        dropdown<AppLang>(
          lang,
          [for (final l in AppLang.values) DropdownMenuItem(value: l, child: Text(l.nativeName))],
          (l) {
            if (l != null) ref.read(langProvider.notifier).set(l);
          },
        ),
        '${s.t('data_language')}: ${lang.apiLang == lang.code ? lang.nativeName : s.t('data_lang_fallback')} · '
            '${s.t('wiki_source')}: ${Uri.parse(lang.wikiBase).host}',
      ),
      (
        s.t('ui_scale'),
        dropdown<double?>(
          scale,
          [
            for (final size in uiScaleChoices)
              DropdownMenuItem(
                value: size,
                child: Text(size == null ? s.t('ui_scale_auto') : '${(size * 100).round()}%'),
              ),
          ],
          (size) => ref.read(uiScaleProvider.notifier).set(size),
        ),
        s.t('ui_scale_hint'),
      ),
    ];
    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth >= 520;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, control, hint) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Flex(
                direction: side ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: side ? 160 : null,
                    child: Padding(
                      padding: EdgeInsets.only(top: side ? 9 : 0, bottom: side ? 0 : 6),
                      child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSoft)),
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        control,
                        if (hint != null) ...[
                          const SizedBox(height: 6),
                          Text(hint, style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}
