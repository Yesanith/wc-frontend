import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/open_events.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

/// the official Discord server: what it is and how to join it. It gives its members the role of each region they have an
/// account in, and opens a channel for an event that started that only those who signed up can see
class OpenEventRolesScreen extends ConsumerWidget {
  const OpenEventRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final info = ref.watch(officialDiscordProvider);
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
              Text(s.t('oe_roles_none'), style: TextStyle(color: AppColors.muted))
            else if (invite != null)
              FilledButton.icon(
                onPressed: () => openUrl(context, invite, failMessage: s.t('open_failed')),
                icon: const Icon(Icons.login, size: 18),
                label: Text(s.t('oe_roles_join')),
              ),
          ],
        ),
      ),
    );
  }
}
