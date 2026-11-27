import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/community.dart';
import '../state/guild_attendance.dart';
import '../state/clock.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// for the leaders and officers: how often each member answered the guild's events. it is what they said, going, maybe or no,
/// not who came, and the page says so
class GuildAttendanceScreen extends ConsumerStatefulWidget {
  const GuildAttendanceScreen({super.key, required this.guild});

  final MyGuild guild;

  @override
  ConsumerState<GuildAttendanceScreen> createState() => _GuildAttendanceScreenState();
}

class _GuildAttendanceScreenState extends ConsumerState<GuildAttendanceScreen> {
  var _days = 90;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final key = (widget.guild.id, _days);
    return Scaffold(
      appBar: AppBar(surfaceTintColor: Colors.transparent, title: Text(s.t('attendance'))),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => ref.invalidate(guildAttendanceProvider(key)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(s.t('attendance_note'), style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final d in const [30, 90, 180])
                ChoiceChip(
                  label: Text(s.t('n_days', {'n': d})),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ]),
            const SizedBox(height: 14),
            AsyncView<GuildAttendance>(
              value: ref.watch(guildAttendanceProvider(key)),
              onRetry: () => ref.invalidate(guildAttendanceProvider(key)),
              builder: (a) {
                if (a.events == 0) return EmptyNote(s.t('attendance_none'));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Kicker(s.t('attendance_events', {'n': a.events}).caps),
                    const SizedBox(height: 8),
                    Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(children: [for (final r in a.rows) _Row(row: r, events: a.events)]),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.row, required this.events});

  final AttendanceRow row;
  final int events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final share = events == 0 ? 0.0 : row.going / events;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(row.accountName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
            if (row.role != 'member') Pill(s.t('guild_role_${row.role}')),
            const SizedBox(width: 8),
            Text('${row.going} / $events', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Bar(value: share, color: share >= 0.5 ? AppColors.green : AppColors.gold),
          const SizedBox(height: 4),
          Text(
            [
              if (row.maybe > 0) '${s.t('rsvp_maybe')} ${row.maybe}',
              if (row.declined > 0) '${s.t('rsvp_declined')} ${row.declined}',
              if (row.waitlist > 0) '${s.t('rsvp_waitlist')} ${row.waitlist}',
              if (row.noAnswer > 0) '${s.t('attendance_no_answer')} ${row.noAnswer}',
              if (row.lastGoing != null) s.t('attendance_last', {'d': shortDateText(s, row.lastGoing!)}),
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
