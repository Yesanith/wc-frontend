import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';

/// how one member answered the guild's events of the span
class AttendanceRow {
  const AttendanceRow({
    required this.accountName,
    required this.role,
    required this.going,
    required this.maybe,
    required this.declined,
    required this.waitlist,
    required this.noAnswer,
    this.lastGoing,
  });

  final String accountName;
  final String role;
  final int going;
  final int maybe;
  final int declined;
  final int waitlist;
  final int noAnswer;
  final DateTime? lastGoing;
}

class GuildAttendance {
  const GuildAttendance(this.events, this.rows);

  /// how many of the guild's events of the span have begun, cancelled ones left out
  final int events;
  final List<AttendanceRow> rows;
}

GuildAttendance parseAttendance(dynamic raw) {
  if (raw is! Map) return const GuildAttendance(0, []);
  return GuildAttendance(asInt(raw['events']), [
    for (final r in (raw['rows'] as List?) ?? const [])
      if (r is Map)
        AttendanceRow(
          accountName: '${r['account_name'] ?? ''}',
          role: '${r['role'] ?? 'member'}',
          going: asInt(r['going']),
          maybe: asInt(r['maybe']),
          declined: asInt(r['declined']),
          waitlist: asInt(r['waitlist']),
          noAnswer: asInt(r['no_answer']),
          lastGoing: DateTime.tryParse('${r['last_going'] ?? ''}')?.toLocal(),
        ),
  ]);
}

/// for the leaders and officers: how each member answered the guild's events of the last 30, 90 or 180 days
final guildAttendanceProvider = FutureProvider.autoDispose.family<GuildAttendance, (String, int)>((ref, key) async {
  final raw = await Supabase.instance.client.rpc('guild_attendance', params: {'p_guild': key.$1, 'p_days': key.$2});
  return parseAttendance(raw);
});
