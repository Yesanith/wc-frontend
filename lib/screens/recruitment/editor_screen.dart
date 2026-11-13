import 'package:flutter/material.dart';
import '../../util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../state/recruitment.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/responsive.dart';

/// the page of a guild, made or changed: what the guild says of itself, what it looks for, how to reach it. whoever manages it may save it as a draft, show it to everybody once it has what it
/// takes (a headline, a description and a way to be reached), and say that the guild is still looking, which keeps it in the list. the leader may delete it
class RecruitEditorScreen extends ConsumerStatefulWidget {
  const RecruitEditorScreen({super.key, required this.guild});

  final MyRecruitGuild guild;

  @override
  ConsumerState<RecruitEditorScreen> createState() => _RecruitEditorScreenState();
}

class _RecruitEditorScreenState extends ConsumerState<RecruitEditorScreen> {
  final _headline = TextEditingController();
  final _description = TextEditingController();
  final _requirements = TextEditingController();
  final _playTimes = TextEditingController();
  final _discord = TextEditingController();
  final _contact = TextEditingController();

  RecruitDraft _draft = const RecruitDraft();

  /// the page as the database has it, null while there is none
  RecruitPage? _page;
  bool _loaded = false;

  /// whether the page is to be shown to everybody, as the switch says
  bool _published = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_headline, _description, _requirements, _playTimes, _discord, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  /// what is on the screen is what the database had, once
  void _load(RecruitPage? page) {
    if (_loaded) return;
    _loaded = true;
    _page = page;
    _draft = page == null ? const RecruitDraft() : RecruitDraft.fromPage(page);
    _published = page?.published ?? false;
    _headline.text = _draft.headline;
    _description.text = _draft.description;
    _requirements.text = _draft.requirements;
    _playTimes.text = _draft.playTimes;
    _discord.text = _draft.discordInvite;
    _contact.text = _draft.contact;
  }

  void _set(RecruitDraft draft) => setState(() => _draft = draft);

  /// the set with a value put in it, or taken out
  Set<String> _toggled(Set<String> set, String value, bool on) => on ? {...set, value} : ({...set}..remove(value));

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final problems = _draft.problems();
    if (problems.isNotEmpty) {
      // too many tags, or a language the forum has no tag for, which a page that chose before may have: said as it is, and not as a text that is too long
      final tags = problems.contains(RecruitField.tags) || problems.contains(RecruitField.languages);
      showToast(
          context,
          tags
              ? s.t('rec_f_tags_hint', {'n': _draft.lookingFor.length + _draft.languages.length})
              : s.t('rec_err_invalid'));
      return;
    }
    // a page that is shown to everybody stays whole
    if (_published && _draft.missingToPublish().isNotEmpty) {
      showToast(context, s.t('rec_publish_needs'));
      return;
    }
    setState(() => _busy = true);
    final backend = ref.read(recruitBackendProvider);
    final refresh = _refreshLater();
    try {
      final id = widget.guild.guildId;
      final wasPublished = _page?.published ?? false;
      // the database keeps a page that is shown to everybody whole and refuses to save it otherwise, so a page that is being taken back to a draft is taken back before it is changed
      // (it may be that it was emptied), and one that is being shown is shown after it has been saved, when it has what it takes
      if (wasPublished && !_published) await backend.setPublished(id, false);
      var saved = await backend.save(id, _draft);
      if (!wasPublished && _published && saved != null) saved = await backend.setPublished(id, true);
      refresh();
      if (!mounted) return;
      setState(() => _page = saved ?? _page);
      showToast(context, s.t('rec_saved'));
    } catch (e) {
      if (mounted) showToast(context, s.t(recruitErrorKey(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final s = ref.read(stringsProvider);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.t('rec_delete_ask')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.t('rec_delete'))),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final refresh = _refreshLater();
    try {
      await ref.read(recruitBackendProvider).delete(widget.guild.guildId);
      refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, s.t(recruitErrorKey(e)));
    }
  }

  /// the page and the lists, read again through the container: the editor may have been left while the database
  /// answered, and the lists behind it still have to show what was saved or deleted
  void Function() _refreshLater() {
    final container = ProviderScope.containerOf(context, listen: false);
    final guildId = widget.guild.guildId;
    return () {
      container.invalidate(recruitPageProvider(guildId));
      container.invalidate(recruitListProvider);
      container.invalidate(myRecruitProvider);
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final page = ref.watch(recruitPageProvider(widget.guild.guildId));
    return Scaffold(
      appBar: AppBar(
          title: Text('${s.t('rec_editor')} · ${widget.guild.title}', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: AsyncView<RecruitPage?>(
        value: page,
        onRetry: () => ref.invalidate(recruitPageProvider(widget.guild.guildId)),
        builder: (loaded) {
          _load(loaded);
          return ContentFrame(maxWidth: readingMaxWidth, child: _form(s));
        },
      ),
    );
  }

  Widget _form(S s) {
    final missing = _draft.missingToPublish();
    // a page plays in one language and looks for four things at the most: they are the five tags of its post in the forum. when four are chosen what is not waits until one is taken off
    final chosen = _draft.lookingFor.length + _draft.languages.length;
    final full = _draft.lookingFor.length >= recruitLookingForMax;
    // a language the page has that the app offers no choice for stays a chip, so that it can be taken off
    final languages = [...recruitLanguages, ..._draft.languages.where((l) => !recruitLanguages.contains(l))];
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(text.caps,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.hint)),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        TextField(
          key: const Key('rec-headline'),
          controller: _headline,
          maxLength: recruitHeadlineMax,
          decoration: InputDecoration(labelText: s.t('rec_f_headline')),
          onChanged: (v) => _set(_draft.copyWith(headline: v)),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('rec-description'),
          controller: _description,
          maxLength: recruitDescriptionMax,
          minLines: 4,
          maxLines: 10,
          decoration: InputDecoration(labelText: s.t('rec_f_description'), alignLabelWithHint: true),
          onChanged: (v) => _set(_draft.copyWith(description: v)),
        ),
        label(s.t('rec_f_recruiting')),
        SwitchListTile(
          key: const Key('rec-recruiting'),
          contentPadding: EdgeInsets.zero,
          title: Text(s.t('rec_f_recruiting')),
          // the post of the page in the forum of the official server is locked while it is off: it is this switch that does it, and nothing else
          subtitle: Text(s.t('rec_f_recruiting_hint'), style: TextStyle(color: AppColors.hint, fontSize: 12)),
          value: _draft.recruiting,
          onChanged: (v) => _set(_draft.copyWith(recruiting: v)),
        ),
        // five between what it looks for and the languages, said once above both, with how many are chosen: amber when a page that chose more before has to take some off
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(
            s.t('rec_f_tags_hint', {'n': chosen}),
            key: const Key('rec-tags-hint'),
            style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: chosen > recruitTagsMax ||
                        _draft.lookingFor.length > recruitLookingForMax ||
                        _draft.problems().contains(RecruitField.languages)
                    ? AppColors.amber
                    : AppColors.hint),
          ),
        ),
        label(s.t('rec_page_looking_for')),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final tag in recruitTags)
              FilterChip(
                label: Text(recruitTagLabel(s, tag)),
                selected: _draft.lookingFor.contains(tag),
                onSelected: !_draft.lookingFor.contains(tag) && full
                    ? null
                    : (on) => _set(_draft.copyWith(lookingFor: _toggled(_draft.lookingFor, tag, on))),
              ),
          ],
        ),
        label(s.t('rec_f_languages')),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // one language: choosing another takes the first off, and choosing the one that is on takes it off
            for (final code in languages)
              ChoiceChip(
                key: Key('rec-lang-$code'),
                label: Text(recruitLanguageLabel(code)),
                selected: _draft.languages.contains(code),
                onSelected: (on) =>
                    _set(_draft.copyWith(languages: on ? {code} : _toggled(_draft.languages, code, false))),
              ),
          ],
        ),
        label(s.t('rec_page_region')),
        SegmentedButton<RecruitRegion>(
          segments: [
            for (final r in RecruitRegion.values) ButtonSegment(value: r, label: Text(recruitRegionLabel(s, r)))
          ],
          selected: {_draft.region},
          onSelectionChanged: (v) => _set(_draft.copyWith(region: v.first)),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const Key('rec-requirements'),
          controller: _requirements,
          maxLength: recruitRequirementsMax,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(labelText: s.t('rec_f_requirements'), alignLabelWithHint: true),
          onChanged: (v) => _set(_draft.copyWith(requirements: v)),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('rec-play-times'),
          controller: _playTimes,
          maxLength: recruitPlayTimesMax,
          decoration: InputDecoration(labelText: s.t('rec_f_play_times')),
          onChanged: (v) => _set(_draft.copyWith(playTimes: v)),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('rec-discord'),
          controller: _discord,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: s.t('rec_f_discord'),
            // an invite that is none is said when it is typed and not when it is sent
            errorText: _draft.discordInvite.trim().isNotEmpty && !isDiscordInvite(_draft.discordInvite.trim())
                ? s.t('rec_err_invalid')
                : null,
          ),
          onChanged: (v) => _set(_draft.copyWith(discordInvite: v)),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('rec-contact'),
          controller: _contact,
          maxLength: recruitContactMax,
          decoration: InputDecoration(labelText: s.t('rec_f_contact')),
          onChanged: (v) => _set(_draft.copyWith(contact: v)),
        ),
        const Divider(height: 32),
        SwitchListTile(
          key: const Key('rec-published'),
          contentPadding: EdgeInsets.zero,
          title: Text(s.t('rec_f_published')),
          // what it takes, until it has it, and then where it is shown besides the app: the page is also read in a server that everybody is in
          subtitle: missing.isNotEmpty && !_published
              ? Text(s.t('rec_publish_needs'), style: TextStyle(color: AppColors.amber, fontSize: 12))
              : Text(s.t('rec_f_published_hint'), style: TextStyle(color: AppColors.hint, fontSize: 12)),
          value: _published,
          // it can be shown once it has what it takes, and always taken back
          onChanged: _published || missing.isEmpty ? (v) => setState(() => _published = v) : null,
        ),
        if (_page?.hidden == true)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.t('rec_hidden_note'), style: TextStyle(color: AppColors.ember, fontSize: 12)),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _save, child: Text(s.t('rec_save'))),
        // saving is what keeps the page in the list: a page that is not saved for sixty days leaves it, and there is no other button for it
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(s.t('rec_save_hint'), style: TextStyle(fontSize: 12, color: AppColors.hint)),
        ),
        if (_page != null && widget.guild.isLeader) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: AppColors.ember),
            child: Text(s.t('rec_delete')),
          ),
        ],
      ],
    );
  }
}
