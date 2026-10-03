import 'dart:convert';

import '../util.dart';

/// how serious a line of what a function said is
enum LogLevel {
  error('error', 'Errors'),
  warn('warn', 'Warnings'),
  info('info', 'Notes');

  const LogLevel(this.code, this.label);

  /// what the database calls it
  final String code;
  final String label;

  static LogLevel? parse(Object? code) {
    for (final level in values) {
      if (level.code == code) return level;
    }
    return null;
  }
}

/// one line of what an Edge Function said: which, when, how serious, what, and what it knew of it. the database counts the same line said again within a minute
class FunctionLogLine {
  const FunctionLogLine({
    required this.id,
    required this.at,
    required this.fn,
    required this.level,
    required this.message,
    this.detail,
  });

  final int id;
  final DateTime? at;
  final String fn;
  final LogLevel level;
  final String message;
  final Map<String, dynamic>? detail;

  /// how many times it was said in that minute
  int get repeats {
    final n = detail?['repeats'];
    return n is num && n >= 2 ? n.toInt() : 1;
  }

  /// what it knew of it, as text to be read and copied, without the count
  String? get detailText {
    final rest = {...?detail}..remove('repeats');
    if (rest.isEmpty) return null;
    return const JsonEncoder.withIndent('  ').convert(rest);
  }

  static FunctionLogLine? parse(Object? raw) {
    if (raw is! Map) return null;
    final level = LogLevel.parse(raw['level']);
    final fn = raw['fn'];
    final message = raw['message'];
    if (level == null || fn is! String || message is! String) return null;
    final detail = raw['detail'];
    return FunctionLogLine(
      id: asInt(raw['id']),
      at: raw['at'] == null ? null : DateTime.tryParse('${raw['at']}')?.toLocal(),
      fn: fn,
      level: level,
      message: message,
      detail: detail is Map ? Map<String, dynamic>.from(detail) : null,
    );
  }
}

/// how a function did in the last day
class FunctionStat {
  const FunctionStat({required this.fn, required this.errors, required this.warnings, required this.notes, this.lastAt});

  final String fn;
  final int errors;
  final int warnings;
  final int notes;
  final DateTime? lastAt;

  /// what to say of it in a line: the errors and the warnings, or that it had none
  String get summary {
    final parts = [
      if (errors > 0) '$errors ${errors == 1 ? 'error' : 'errors'}',
      if (warnings > 0) '$warnings ${warnings == 1 ? 'warning' : 'warnings'}',
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    return notes > 0 ? '$notes ${notes == 1 ? 'note' : 'notes'}' : 'nothing';
  }

  static FunctionStat? parse(Object? raw) {
    if (raw is! Map || raw['fn'] is! String) return null;
    return FunctionStat(
      fn: raw['fn'] as String,
      errors: asInt(raw['errors']),
      warnings: asInt(raw['warnings']),
      notes: asInt(raw['notes']),
      lastAt: raw['last_at'] == null ? null : DateTime.tryParse('${raw['last_at']}')?.toLocal(),
    );
  }
}

/// which lines: of one function or all, of one level or all, with a text in them, older than the line with the number [before]. a record, so that the same page is the same page
typedef LogQuery = ({String? fn, LogLevel? level, String search, int? before});

const noLogQuery = (fn: null, level: null, search: '', before: null);

/// how many lines a page holds
const logsPageSize = 50;

/// a page of the logs, as the database gives it
class FunctionLogsPage {
  const FunctionLogsPage({required this.rows, required this.functions, required this.total});

  /// newest first
  final List<FunctionLogLine> rows;

  /// how each function did in the last day, whatever the query
  final List<FunctionStat> functions;

  /// the lines kept in all
  final int total;

  /// the number to ask for the older lines with: the oldest of these. null when there are none
  int? get oldestId => rows.isEmpty ? null : rows.last.id;

  /// there may be older ones: this page is full
  bool get mayHaveOlder => rows.length >= logsPageSize;

  int get errorsToday => functions.fold(0, (sum, f) => sum + f.errors);

  static FunctionLogsPage parse(Object? raw) {
    final map = raw is Map ? raw : const {};
    return FunctionLogsPage(
      rows: [
        for (final r in (map['rows'] as List? ?? const []))
          if (FunctionLogLine.parse(r) case final line?) line,
      ],
      functions: [
        for (final f in (map['functions'] as List? ?? const []))
          if (FunctionStat.parse(f) case final stat?) stat,
      ],
      total: asInt(map['total']),
    );
  }
}
