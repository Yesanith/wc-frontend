import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/open_events.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'open_event_labels.dart';

class OpenEventFormScreen extends ConsumerStatefulWidget {
  const OpenEventFormScreen({super.key, this.editing});

  final OpenEvent? editing;

  @override
  ConsumerState<OpenEventFormScreen> createState() => _OpenEventFormScreenState();
}

class _OpenEventFormScreenState extends ConsumerState<OpenEventFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _max;
  late final TextEditingController _map;
  late String _region;
  late final Set<String> _tags;
  late String _activity;
  late String _language;
  late DateTime _start;
  late int _duration;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _max = TextEditingController(text: e?.maxParticipants?.toString() ?? '');
    _map = TextEditingController(text: e?.mapId?.toString() ?? '');
    _region = e?.region ?? 'all';
    _tags = Set<String>.of(e?.tags ?? const []);
    _activity = e?.activity ?? 'raid';
    _language = e?.language ?? 'any';
    // tomorrow at eight in the evening, which is when most are played
    final base = DateTime.now().add(const Duration(days: 1));
    _start = e?.startAt ?? DateTime(base.year, base.month, base.day, 20);
    _duration = e?.durationMinutes ?? 120;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _max.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateUtils.dateOnly(_start).isBefore(today) ? DateUtils.dateOnly(_start) : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: first,
      lastDate: today.add(const Duration(days: 91)),
    );
    if (picked != null)
      setState(() => _start = DateTime(picked.year, picked.month, picked.day, _start.hour, _start.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (picked != null)
      setState(() => _start = DateTime(_start.year, _start.month, _start.day, picked.hour, picked.minute));
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final title = _title.text.trim();
    if (title.length < 3 || title.length > 80) {
      showToast(context, s.t('oe_err_title'));
      return;
    }
    final maxText = _max.text.trim();
    final max = maxText.isEmpty ? null : int.tryParse(maxText);
    if (maxText.isNotEmpty && (max == null || max < 2 || max > 100)) {
      showToast(context, s.t('oe_err_capacity'));
      return;
    }
    final mapText = _map.text.trim();
    final mapId = mapText.isEmpty ? null : int.tryParse(mapText);
    if (mapText.isNotEmpty && (mapId == null || mapId < 1 || mapId > 100000)) {
      showToast(context, s.t('oe_err_map'));
      return;
    }
    setState(() => _busy = true);
    try {
      final editing = widget.editing;
      if (editing == null) {
        await createOpenEvent(
          title: title,
          startAt: _start,
          durationMinutes: _duration,
          description: _description.text.trim(),
          activity: _activity,
          language: _language,
          maxParticipants: max,
          region: _region,
          tags: _tags.toList()..sort(),
          mapId: mapId,
        );
      } else {
        await updateOpenEvent(
          editing.id,
          title: title,
          startAt: _start,
          durationMinutes: _duration,
          description: _description.text.trim(),
          activity: _activity,
          language: _language,
          maxParticipants: max,
          tags: _tags.toList()..sort(),
          mapId: mapId,
        );
      }
      if (!mounted) return;
      showToast(context, s.t(editing == null ? 'oe_created' : 'oe_saved'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, s.t(openEventErrorKey(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final editing = widget.editing != null;
    final mine = ref.watch(myRegionsProvider).valueOrNull;
    final makeable = mine?.makeable ?? const ['all'];
    return Scaffold(
      appBar: AppBar(title: Text(s.t(editing ? 'oe_form_edit' : 'oe_form_create'))),
      body: ContentFrame(
        maxWidth: readingMaxWidth,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Kicker(s.t('event_title')),
            const SizedBox(height: 6),
            TextField(
              controller: _title,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration(''),
            ),
            const SizedBox(height: 8),
            Kicker(s.t('event_activity')),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _activity,
              dropdownColor: AppColors.surface,
              decoration: fieldDecoration(''),
              items: [for (final a in openEventActivities) DropdownMenuItem(value: a, child: Text(s.t('activity_$a')))],
              onChanged: (v) => setState(() => _activity = v ?? _activity),
            ),
            const SizedBox(height: 16),
            Kicker(s.t('oe_region')),
            const SizedBox(height: 6),
            if (editing)
              // what an event is for stays what it was made for: those who signed up did so with an account of it
              Text(s.t('oe_region_$_region'), style: const TextStyle(fontWeight: FontWeight.w700))
            else
              DropdownButtonFormField<String>(
                initialValue: makeable.contains(_region) ? _region : 'all',
                dropdownColor: AppColors.surface,
                decoration: fieldDecoration(''),
                items: [for (final r in makeable) DropdownMenuItem(value: r, child: Text(s.t('oe_region_$r')))],
                onChanged: (v) => setState(() => _region = v ?? _region),
              ),
            const SizedBox(height: 6),
            Text(
              mine != null && mine.hasAccount && mine.regions.isEmpty
                  ? s.t('oe_region_unknown')
                  : s.t('oe_region_note'),
              style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            Kicker(s.t('oe_language')),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _language,
              dropdownColor: AppColors.surface,
              decoration: fieldDecoration(''),
              items: [for (final l in openEventLanguages) DropdownMenuItem(value: l, child: Text(openEventLanguageName(s, l)))],
              onChanged: (v) => setState(() => _language = v ?? _language),
            ),
            const SizedBox(height: 16),
            Kicker(s.t('oe_tags')),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in openEventTags)
                  FilterChip(
                    label: Text(s.t('oe_tag_$t')),
                    selected: _tags.contains(t),
                    onSelected: (on) => setState(() {
                      if (!on) {
                        _tags.remove(t);
                      } else if (_tags.length < 3) {
                        _tags.add(t);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Kicker(s.t('oe_map')),
            const SizedBox(height: 6),
            TextField(
              controller: _map,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              decoration: fieldDecoration(''),
            ),
            const SizedBox(height: 8),
            Kicker(s.t('event_when')),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text('${pad2(_start.day)}.${pad2(_start.month)}.${_start.year}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text('${pad2(_start.hour)}:${pad2(_start.minute)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Kicker(s.t('event_duration')),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: openEventDurations.contains(_duration) ? _duration : null,
              dropdownColor: AppColors.surface,
              decoration: fieldDecoration(''),
              items: [
                for (final d in openEventDurations) DropdownMenuItem(value: d, child: Text(openEventDuration(d)))
              ],
              onChanged: (v) => setState(() => _duration = v ?? _duration),
            ),
            const SizedBox(height: 16),
            Kicker(s.t('oe_places_field')),
            const SizedBox(height: 6),
            TextField(
              controller: _max,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fieldDecoration(''),
            ),
            const SizedBox(height: 16),
            Kicker(s.t('event_description')),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              maxLength: 1000,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration(''),
            ),
            const SizedBox(height: 8),
            Text(s.t('oe_form_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(s.t('oe_save')),
            ),
          ],
        ),
      ),
    );
  }
}
