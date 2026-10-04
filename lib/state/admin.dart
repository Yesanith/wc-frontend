import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/update_check.dart' show compareVersions;
import '../util.dart';
import 'community.dart';

part 'admin/format.dart';
part 'admin/models.dart';

/// whether the signed in player runs the backend, which decides whether the dashboard is offered. the
/// database answers for the player themselves, it says nothing of anybody else
final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!communityConfigured) return false;
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return false;
  try {
    return await Supabase.instance.client.rpc('is_admin') == true;
  } catch (_) {
    return false;
  }
});

/// the numbers of the backend, from one function of the database that answers an administrator only
final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((ref) async {
  final answer = await Supabase.instance.client.rpc('admin_dashboard');
  return AdminDashboard(Map<String, dynamic>.from(answer as Map));
});

/// what the database server says of itself, from a function that answers an administrator only
final adminServerProvider = FutureProvider.autoDispose<AdminServer>((ref) async {
  final answer = await Supabase.instance.client.rpc('admin_server');
  return AdminServer(Map<String, dynamic>.from(answer as Map));
});

/// the history of the backend: the daily numbers, the status of the functions, the counters, every guild and server
final adminHistoryProvider = FutureProvider.autoDispose<AdminHistory>((ref) async {
  final answer = await Supabase.instance.client.rpc('admin_history');
  return AdminHistory(Map<String, dynamic>.from(answer as Map));
});

/// the public events, for an administrator: what waits for a look, what is hidden, what was made lately
final adminOpenEventsProvider = FutureProvider.autoDispose<AdminOpenEvents>((ref) async {
  final answer = await Supabase.instance.client.rpc('admin_open_events');
  return AdminOpenEvents(Map<String, dynamic>.from(answer as Map));
});

/// what an administrator does to a public event, in the words the database knows: keep (the reports were
/// wrong, they are done), hide, unhide, delete, ban_creator (no more public events from the organizer, and the
/// ones that are to come are hidden)
Future<void> moderateOpenEvent(WidgetRef ref, String eventId, String action) async {
  await Supabase.instance.client.rpc('admin_set_open_event', params: {'p_event': eventId, 'p_action': action});
  ref.invalidate(adminOpenEventsProvider);
}

/// the official Discord server, for an administrator: whether it is set up, what waits to be posted, how the roles
/// of the players are doing, and who is kept from making public events
final adminOfficialProvider = FutureProvider.autoDispose<AdminOfficial>((ref) async {
  final answer = await Supabase.instance.client.rpc('admin_official');
  return AdminOfficial(Map<String, dynamic>.from(answer as Map));
});

/// lets somebody who was kept from making public events make them again
Future<void> unbanOpenCreator(WidgetRef ref, String userId) async {
  await Supabase.instance.client.rpc('admin_unban_open_creator', params: {'p_user': userId});
  ref.invalidate(adminOfficialProvider);
  ref.invalidate(adminOpenEventsProvider);
}

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e)
      ]
    : const [];
