import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';
import 'admin_logs.dart';

/// one of the jobs an administrator may run by hand, as the database lists them: its name, what it does, whether it wakes a sync function
/// (kind 'wake') or runs in the database ('job'), and whether it lets go of data
class AdminJob {
  const AdminJob(this.name, this.what, this.kind, this.danger);

  final String name;
  final String what;
  final String kind;
  final bool danger;

  bool get wakes => kind == 'wake';

  static AdminJob? parse(dynamic raw) {
    if (raw is! Map || raw['name'] == null) return null;
    return AdminJob(
        '${raw['name']}', '${raw['what'] ?? raw['name']}', '${raw['kind'] ?? 'job'}', raw['danger'] == true);
  }
}

/// what running a job said: it went well, or how it did not, and for a sync function the number of its call, to ask for its answer
class JobResult {
  const JobResult({required this.ok, this.error, this.requestId});

  final bool ok;
  final String? error;
  final int? requestId;

  static JobResult parse(dynamic raw) {
    if (raw is! Map) return const JobResult(ok: false, error: 'The database gave no answer');
    final id = raw['request_id'];
    return JobResult(
      ok: raw['ok'] == true,
      error: raw['error'] == null ? null : '${raw['error']}',
      requestId: id == null ? null : asInt(id),
    );
  }
}

/// what a sync function answered to a call: the status, what it said, and whether it timed out
class CallAnswer {
  const CallAnswer({required this.statusCode, required this.content, required this.timedOut, this.error});

  final int? statusCode;
  final String content;
  final bool timedOut;
  final String? error;

  bool get ok => statusCode != null && statusCode! >= 200 && statusCode! < 300;

  static CallAnswer? parse(dynamic raw) {
    if (raw is! Map) return null;
    return CallAnswer(
      statusCode: raw['status_code'] == null ? null : asInt(raw['status_code']),
      content: '${raw['content'] ?? ''}',
      timedOut: raw['timed_out'] == true,
      error: raw['error'] == null ? null : '${raw['error']}',
    );
  }

  /// how it is told: 200 {"read":28000}, 401 unauthorized (the secret does not match), timed out
  String get summary {
    if (timedOut) return 'Timed out';
    if (statusCode == null) return error == null ? 'No status' : 'Failed: $error';
    final hint = statusCode == 401 ? ' (the secret of the function and of the database do not match)' : '';
    return '$statusCode$hint';
  }
}

/// asks for what a call answered until it has, a number of times, a while apart. null when it never did: the call is slower than that
Future<CallAnswer?> waitForAnswer(Future<CallAnswer?> Function() ask,
    {int tries = 15, Duration every = const Duration(seconds: 1)}) async {
  for (var i = 0; i < tries; i++) {
    final answer = await ask();
    if (answer != null) return answer;
    if (i < tries - 1) await Future<void>.delayed(every);
  }
  return null;
}

/// a column of a table: its name and type, whether it is the key, and whether it is hidden because it is a secret by its name
class TableColumn {
  const TableColumn(this.name, this.type, this.key, this.hidden);

  final String name;
  final String type;
  final bool key;
  final bool hidden;
}

/// which page of which table, with what searched for in it. a record, so that the same page is the same page
typedef TableQuery = ({String table, int offset, String filter});

/// a page of a table, as the database gives it
class AdminTablePage {
  const AdminTablePage(this.raw);

  final Map<String, dynamic> raw;

  String get table => '${raw['table'] ?? ''}';

  List<TableColumn> get columns => [
        for (final c in (raw['columns'] as List? ?? const []))
          if (c is Map) TableColumn('${c['name']}', '${c['type']}', c['key'] == true, c['hidden'] == true),
      ];

  List<Map<String, dynamic>> get rows => [
        for (final r in (raw['rows'] as List? ?? const []))
          if (r is Map) Map<String, dynamic>.from(r),
      ];

  int get total => asInt(raw['total']);
  int get limit => asInt(raw['limit']) == 0 ? 50 : asInt(raw['limit']);
  int get offset => asInt(raw['offset']);
  String? get orderedBy => raw['ordered_by'] == null ? null : '${raw['ordered_by']}';
  bool get hasPrevious => offset > 0;
  bool get hasNext => offset + rows.length < total;
}

/// 1–50 of 1,234, 0 of 0, 51–60 of 60
String rowsLabel(int offset, int shown, int total) =>
    shown == 0 ? '0 of ${fmtInt(total)}' : '${fmtInt(offset + 1)}–${fmtInt(offset + shown)} of ${fmtInt(total)}';

/// how a value is written in a row: nothing as null, a string as it is, a list or a map as compact JSON
String cellText(dynamic v) {
  if (v == null) return 'null';
  if (v is String) return v;
  if (v is Map || v is List) return jsonEncode(v);
  return '$v';
}

/// what a row is called in the list: its key, else its first columns, as `name: value`. a hidden column is not told
String rowTitle(List<TableColumn> columns, Map<String, dynamic> row, {int parts = 2}) {
  final keys = columns.where((c) => c.key && !c.hidden).toList();
  final chosen = (keys.isNotEmpty ? keys : columns.where((c) => !c.hidden)).take(parts);
  final text = [for (final c in chosen) '${c.name}: ${cellText(row[c.name])}'].join(', ');
  return text.isEmpty ? '(row)' : text;
}

/// a row as JSON that can be copied, written out
String rowJson(Map<String, dynamic> row) => const JsonEncoder.withIndent('  ').convert(row);

/// whether an address is one of a Discord webhook, which is all the alerts may be sent to
bool isDiscordWebhook(String url) =>
    RegExp(r'^https://(discord|discordapp)\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+$').hasMatch(url.trim());

/// something that was sent to the administrator, or a test
class AlertEntry {
  const AlertEntry({required this.at, required this.kind, required this.message, required this.sent});

  final DateTime? at;

  /// raised, reminder, resolved or test
  final String kind;
  final String message;

  /// it left for Discord: false when there was no webhook to send to
  final bool sent;
}

/// what is wrong, what was sent, and whether the alerts have anywhere to go
class AdminAlerts {
  const AdminAlerts(this.raw);

  final Map<String, dynamic> raw;

  bool get webhookSet => raw['webhook_set'] == true;
  String get webhookTail => '${raw['webhook_tail'] ?? ''}';

  List<({String key, String message, String severity})> get problemsNow => [
        for (final p in (raw['problems_now'] as List? ?? const []))
          if (p is Map) (key: '${p['key']}', message: '${p['message']}', severity: '${p['severity'] ?? 'warn'}'),
      ];

  List<AlertEntry> get recent => [
        for (final r in (raw['recent'] as List? ?? const []))
          if (r is Map)
            AlertEntry(
                at: DateTime.tryParse('${r['at']}')?.toLocal(),
                kind: '${r['kind']}',
                message: '${r['message']}',
                sent: r['sent'] == true),
      ];
}

/// everything the dashboard asks of the database to do and to show. one place, so that a test can put another in its stead
abstract class AdminBackend {
  Future<List<AdminJob>> jobs();

  Future<JobResult> run(String job);

  Future<CallAnswer?> callResult(int requestId);

  Future<AdminTablePage> table(TableQuery query);

  Future<AdminAlerts> alerts();

  /// where the alerts go: the address of a Discord webhook, or none to take it away. whether there is one now
  Future<bool> setAlertWebhook(String? url);

  /// sends a test to the webhook and gives the number of its call
  Future<int> testAlert();

  /// what the Edge Functions said, newest first, [logsPageSize] lines at a time
  Future<FunctionLogsPage> functionLogs(LogQuery query);
}

class SupabaseAdminBackend implements AdminBackend {
  const SupabaseAdminBackend();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<AdminJob>> jobs() async {
    final raw = await _client.rpc('admin_jobs');
    return [
      for (final j in (raw as List? ?? const []))
        if (AdminJob.parse(j) case final job?) job,
    ];
  }

  @override
  Future<JobResult> run(String job) async =>
      JobResult.parse(await _client.rpc('admin_run_job', params: {'p_job': job}));

  @override
  Future<CallAnswer?> callResult(int requestId) async =>
      CallAnswer.parse(await _client.rpc('admin_call_result', params: {'p_request_id': requestId}));

  @override
  Future<AdminTablePage> table(TableQuery query) async {
    final raw = await _client.rpc('admin_table', params: {
      'p_table': query.table,
      'p_limit': 50,
      'p_offset': query.offset,
      'p_filter': query.filter.isEmpty ? null : query.filter,
    });
    return AdminTablePage(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<FunctionLogsPage> functionLogs(LogQuery query) async => FunctionLogsPage.parse(await _client.rpc('admin_function_logs', params: {
        'p_fn': query.fn,
        'p_level': query.level?.code,
        'p_search': query.search.isEmpty ? null : query.search,
        'p_limit': logsPageSize,
        'p_before': query.before,
      }));

  @override
  Future<AdminAlerts> alerts() async =>
      AdminAlerts(Map<String, dynamic>.from(await _client.rpc('admin_alerts') as Map));

  @override
  Future<bool> setAlertWebhook(String? url) async {
    final raw = await _client.rpc('admin_set_alert_webhook', params: {'p_url': url});
    return raw is Map && raw['set'] == true;
  }

  @override
  Future<int> testAlert() async => asInt(await _client.rpc('admin_test_alert'));
}

final adminBackendProvider = Provider<AdminBackend>((ref) => const SupabaseAdminBackend());

/// how long to wait between asking what a call answered
final adminPollEveryProvider = Provider<Duration>((ref) => const Duration(seconds: 1));

final adminJobsProvider = FutureProvider.autoDispose<List<AdminJob>>((ref) => ref.watch(adminBackendProvider).jobs());

final adminTableProvider = FutureProvider.autoDispose
    .family<AdminTablePage, TableQuery>((ref, query) => ref.watch(adminBackendProvider).table(query));

final adminAlertsProvider = FutureProvider.autoDispose<AdminAlerts>((ref) => ref.watch(adminBackendProvider).alerts());

/// a page of what the Edge Functions said
final adminLogsProvider = FutureProvider.autoDispose
    .family<FunctionLogsPage, LogQuery>((ref, query) => ref.watch(adminBackendProvider).functionLogs(query));
