import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/community.dart';
import '../../state/navigation.dart';
import '../../state/recruitment.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/responsive.dart';
import 'editor_screen.dart';

/// opens the page of a guild over the page the app is at. it has an address of its own (/recruit/<number>), in the browser while it is open, and its button copies it.
/// [announce] is false for a link that was followed or that the app was opened with
Future<void> showRecruitPage(BuildContext context, String guildId, {bool announce = true}) {
  final closed = linkOpened(
    ProviderScope.containerOf(context, listen: false),
    RecruitLink(guildId),
    announce: announce,
  );
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => RecruitPageScreen(guildId: guildId)))
      .whenComplete(closed);
}

/// what a guild says of itself, for the players who may want to join it, and how to reach it. read by everybody: a visitor who is not signed in too. who manages it may edit it
class RecruitPageScreen extends ConsumerWidget {
  const RecruitPageScreen({super.key, required this.guildId});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (!communityReady) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('recruitment'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              s.t('rec_unavailable'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }
    final page = ref.watch(recruitPageProvider(guildId));
    final shown = page.valueOrNull;
    final signedIn = ref.watch(sessionProvider).valueOrNull != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(shown?.title ?? s.t('recruitment'), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // the address of this page, which opens the app at it: what is shared
          if (isEventId(guildId))
            IconButton(
              tooltip: s.t('copy_page_link'),
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: linkUrl(RecruitLink(guildId))));
                showToast(context, s.t('copied'));
              },
            ),
          if (shown != null && shown.canEdit)
            IconButton(
              tooltip: s.t('rec_edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RecruitEditorScreen(
                      guild: MyRecruitGuild(
                        guildId: shown.guildId,
                        gw2GuildId: shown.gw2GuildId,
                        name: shown.name,
                        tag: shown.tag,
                        isLeader: shown.isLeader,
                        hasPage: true,
                        published: shown.published,
                        hidden: shown.hidden,
                        stale: shown.stale,
                      ),
                    ),
                  ),
                );
                ref.invalidate(recruitPageProvider(guildId));
                ref.invalidate(recruitListProvider);
                ref.invalidate(myRecruitProvider);
              },
            )
          else if (shown != null && signedIn)
            IconButton(
              tooltip: s.t('oe_report'),
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => _report(context, ref),
            ),
        ],
      ),
      body: AsyncView<RecruitPage?>(
        value: page,
        onRetry: () => ref.invalidate(recruitPageProvider(guildId)),
        builder: (p) => p == null
            ? Center(
                child: Text(s.t('rec_not_found'), style: TextStyle(color: AppColors.muted)),
              )
            : ContentFrame(
                maxWidth: readingMaxWidth,
                child: _PageBody(page: p),
              ),
      ),
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReportDialog(question: s.t('rec_report_why')),
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(recruitBackendProvider).report(guildId, reason);
      if (context.mounted) showToast(context, s.t('oe_reported'));
    } catch (e) {
      if (context.mounted) showToast(context, s.t(recruitErrorKey(e)));
    }
  }
}

/// asks why a page is reported, in a few words
class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog({required this.question});

  final String question;

  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return AlertDialog(
      title: Text(s.t('oe_report')),
      content: TextField(
        key: const Key('report-reason'),
        controller: _reason,
        maxLength: 300,
        maxLines: 3,
        decoration: InputDecoration(labelText: widget.question),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.t('cancel'))),
        FilledButton(
          onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_reason.text.trim()),
          child: Text(s.t('oe_report')),
        ),
      ],
    );
  }
}

class _PageBody extends ConsumerWidget {
  const _PageBody({required this.page});

  final RecruitPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    Widget fact(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.hint),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
    Widget note(String text, Color color) => Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: color, height: 1.35)),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Icon(Icons.groups, size: 36, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(page.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              label: Text(page.recruiting ? s.t('rec_recruiting') : s.t('rec_closed')),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: page.recruiting ? AppColors.gold : AppColors.line),
              labelStyle: TextStyle(color: page.recruiting ? AppColors.gold : AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        if (page.hidden)
          note(s.t('rec_hidden_note') + (page.hiddenReason == null ? '' : '\n${page.hiddenReason}'), AppColors.ember)
        else if (!page.published)
          note(s.t('rec_draft_note'), AppColors.amber),
        if (page.stale && page.published && !page.hidden) note(s.t('rec_stale'), AppColors.amber),
        if (page.headline.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              page.headline,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
        if (page.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SelectableText(
              page.description,
              style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSoft),
            ),
          ),
        if (page.lookingFor.isNotEmpty)
          fact(
            s.t('rec_page_looking_for'),
            Wrap(spacing: 8, runSpacing: 4, children: [for (final t in page.lookingFor) _Tag(recruitTagLabel(s, t))]),
          ),
        if (page.requirements.isNotEmpty)
          fact(s.t('rec_page_requirements'), SelectableText(page.requirements, style: const TextStyle(height: 1.4))),
        if (page.playTimes.isNotEmpty) fact(s.t('rec_page_play_times'), SelectableText(page.playTimes)),
        if (page.languages.isNotEmpty)
          fact(
            s.t('rec_page_languages'),
            Wrap(spacing: 8, runSpacing: 4, children: [for (final l in page.languages) _Tag(recruitLanguageLabel(l))]),
          ),
        if (page.region != RecruitRegion.any) fact(s.t('rec_page_region'), Text(recruitRegionLabel(s, page.region))),
        if (page.canBeReached)
          fact(
            s.t('rec_page_contact'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (page.discordInvite != null && isDiscordInvite(page.discordInvite!))
                  FilledButton.icon(
                    onPressed: () => launchUrl(Uri.parse(page.discordInvite!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(s.t('rec_discord_join')),
                  ),
                if (page.contact.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: page.discordInvite == null ? 0 : 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            page.contact,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: page.contact));
                            showToast(context, s.t('copied'));
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.line),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSoft)),
  );
}
