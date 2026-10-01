import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/open_events.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'guild_events_screen.dart' show activityIcon;

/// the official Discord server: how to join it, and which kinds of event the player wants to be told of there. The
/// server gives its members the role of each region they have an account in, and of each kind they pick here
class OpenEventRolesScreen extends ConsumerStatefulWidget {
  const OpenEventRolesScreen({super.key});

  @override
  ConsumerState<OpenEventRolesScreen> createState() => _OpenEventRolesScreenState();
}

class _OpenEventRolesScreenState extends ConsumerState<OpenEventRolesScreen> {
  /// what the player picked here and has not saved yet
  Set<String>? _kinds;
  bool _busy = false;

  void _toggle(Set<String> chosen, String kind, bool on) {
    final next = Set<String>.of(chosen);
    if (on) {
      next.add(kind);
    } else {
      next.remove(kind);
    }
    setState(() => _kinds = next);
  }

  Future<void> _save(Set<String> kinds) async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      await saveOpenEventTypes(kinds);
      ref.invalidate(openEventTypesProvider);
      if (mounted) showToast(context, s.t('oe_roles_saved'));
    } catch (e) {
      if (mounted) showToast(context, s.t(openEventErrorKey(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final info = ref.watch(officialDiscordProvider);
    final saved = ref.watch(openEventTypesProvider);
    final chosen = _kinds ?? saved.valueOrNull ?? const <String>{};
    final configured = info.valueOrNull?.configured ?? false;
    final invite = info.valueOrNull?.inviteUrl;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('oe_roles_title'))),
      body: ContentFrame(
        maxWidth: readingMaxWidth,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(s.t('oe_roles_body'), style: const TextStyle(height: 1.5)),
            const SizedBox(height: 16),
            if (info.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (!configured)
              Text(s.t('oe_roles_none'), style: const TextStyle(color: AppColors.muted))
            else ...[
              if (invite != null)
                FilledButton.icon(
                  onPressed: () => openUrl(context, invite, failMessage: s.t('open_failed')),
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(s.t('oe_roles_join')),
                ),
              const SizedBox(height: 20),
              Kicker(s.t('oe_roles_kinds')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final k in openEventRoleKinds)
                    FilterChip(
                      avatar: Icon(activityIcon(k), size: 16),
                      label: Text(s.t('activity_$k')),
                      selected: chosen.contains(k),
                      onSelected: (on) => _toggle(chosen, k, on),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || _kinds == null ? null : () => _save(_kinds!),
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(s.t('oe_save')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
