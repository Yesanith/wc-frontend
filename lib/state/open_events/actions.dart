part of '../open_events.dart';

Future<String> createOpenEvent({
  required String title,
  required DateTime startAt,
  required int durationMinutes,
  required String description,
  required String activity,
  required String language,
  int? maxParticipants,
  String region = 'all',
  List<String> tags = const [],
  int? mapId,
  Map<String, int> roles = const {},
  String? myRole,
  String? myProfession,
}) async {
  final id = await _rpc('create_open_event', {
    'p_title': title,
    'p_start_at': _utc(startAt),
    'p_duration_minutes': durationMinutes,
    'p_description': description,
    'p_activity': activity,
    'p_language': language,
    'p_max_participants': maxParticipants,
    'p_region': region,
    'p_tags': tags,
    'p_map_id': mapId,
    'p_roles': _rolesJson(roles),
    'p_my_role': myRole,
    'p_my_profession': myProfession,
  });
  return '$id';
}

Future<void> updateOpenEvent(
  String id, {
  required String title,
  required DateTime startAt,
  required int durationMinutes,
  required String description,
  required String activity,
  required String language,
  int? maxParticipants,
  List<String> tags = const [],
  int? mapId,
  Map<String, int>? roles,
}) async {
  await _rpc('update_open_event', {
    'p_event': id,
    'p_title': title,
    'p_start_at': _utc(startAt),
    'p_duration_minutes': durationMinutes,
    'p_description': description,
    'p_activity': activity,
    'p_language': language,
    'p_max_participants': maxParticipants,
    'p_tags': tags,
    'p_map_id': mapId,
    'p_roles': roles == null ? null : _rolesJson(roles),
  });
}

Future<void> cancelOpenEvent(String id) async {
  await _rpc('cancel_open_event', {'p_event': id});
}

Future<void> deleteOpenEvent(String id) async {
  await _rpc('delete_open_event', {'p_event': id});
}

/// signs up as going or maybe, as the account asked for, or the first of the region of the event
Future<void> joinOpenEvent(String id, String status, {String? account, String? role, String? profession}) async {
  await _rpc('join_open_event', {
    'p_event': id,
    'p_status': status,
    'p_account': account,
    'p_role': role,
    'p_profession': profession,
  });
}

Future<void> leaveOpenEvent(String id) async {
  await _rpc('leave_open_event', {'p_event': id});
}

Future<void> reportOpenEvent(String id, String reason) async {
  await _rpc('report_open_event', {'p_event': id, 'p_reason': reason, 'p_note': ''});
}
