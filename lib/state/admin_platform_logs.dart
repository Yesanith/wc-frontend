import '../util.dart';
import 'admin_logs.dart' show LogLevel;

/// what of the platform's logs is asked for: what an Edge Function wrote to its console, or the requests that were made to it
enum PlatformSource {
  console('console', 'Console'),
  requests('requests', 'Requests');

  const PlatformSource(this.code, this.label);

  /// what the function calls it
  final String code;
  final String label;
}

/// what the logs of the platform are asked for: which source, which function (by the number the platform gives it), which level of the console, a text, how many hours back from the
/// end of the window, the end of the window when it is not now (the time of the oldest line seen, which is how older lines are asked for), and of the requests only those that failed
typedef PlatformQuery = ({PlatformSource source, String? fnId, LogLevel? level, String search, int hours, String? before, bool onlyErrors});

const platformStart = (source: PlatformSource.console, fnId: null, level: null, search: '', hours: 1, before: null, onlyErrors: false);

/// how many hours back a window may go, which is as many as the platform's API takes
const platformHours = [1, 6, 24];

/// how many lines a page holds
const platformPageSize = 50;

/// what is sent to the function for a query
Map<String, dynamic> platformBody(PlatformQuery q) => {
      'source': q.source.code,
      if (q.fnId != null) 'fnId': q.fnId,
      // the level is of the console, and whether a request failed is of the requests: each is sent only where it means something
      if (q.source == PlatformSource.console && q.level != null) 'level': q.level!.code,
      if (q.source == PlatformSource.requests && q.onlyErrors) 'onlyErrors': true,
      if (q.search.isNotEmpty) 'search': q.search,
      'hours': q.hours,
      if (q.before != null) 'before': q.before,
      'limit': platformPageSize,
    };

/// what went wrong in reading the logs of the platform, as a kind the screen has words for
enum PlatformProblem {
  /// the function has no token: it has not been set up
  notConfigured,

  /// the platform turned the token down: it is wrong, revoked, or may not read logs
  tokenRejected,

  /// the plan does not have the logs
  plan,
  rateLimited,

  /// the platform did not answer, or answered with something that is no logs
  upstream,

  /// the query was refused by the platform: what the function wrote of it is in the detail
  queryError,
  notAdmin,
  notSignedIn,

  /// the window goes back further than the logs do
  tooFar,
  unknown;

  static PlatformProblem of(Object? code) => switch (code) {
        'not_configured' => notConfigured,
        'token_rejected' => tokenRejected,
        'plan' => plan,
        'rate_limited' => rateLimited,
        'upstream' => upstream,
        'query_error' => queryError,
        'not_admin' => notAdmin,
        'not_signed_in' => notSignedIn,
        'bad_before' => tooFar,
        _ => unknown,
      };
}

/// the logs of the platform could not be read
class PlatformLogsException implements Exception {
  const PlatformLogsException(this.problem, [this.detail]);

  final PlatformProblem problem;

  /// what the platform said of the query, when it said
  final String? detail;

  @override
  String toString() => 'PlatformLogsException($problem${detail == null ? '' : ': $detail'})';
}

/// a function of the project: the number the platform gives it, and its name
class PlatformFunction {
  const PlatformFunction({required this.id, required this.slug});

  final String id;
  final String slug;

  static PlatformFunction? parse(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['slug'] is! String) return null;
    return PlatformFunction(id: raw['id'] as String, slug: raw['slug'] as String);
  }
}

/// one line of the platform's logs: of the console of a function, or of a request to it
class PlatformLogLine {
  const PlatformLogLine({
    required this.id,
    required this.at,
    required this.level,
    required this.message,
    required this.fn,
    required this.fnId,
    this.status,
    this.method = '',
    this.path = '',
    this.ms,
    this.attrs = const {},
  });

  final String id;
  final DateTime? at;
  final LogLevel level;
  final String message;

  /// the name of the function, or "" when it is not known; its number is [fnId]
  final String fn;
  final String fnId;

  /// of a request: how it was answered, how, where to, and how long it took
  final int? status;
  final String method;
  final String path;
  final int? ms;

  /// what else the platform knows of the line
  final Map<String, String> attrs;

  bool get isRequest => status != null || method.isNotEmpty;

  /// a request in a line: POST /functions/v1/tp-sync → 503, 1235 ms. the address is cut to what is after the host
  String get requestLine {
    final shown = path.replaceFirst(RegExp(r'^https?://[^/]+'), '');
    final parts = [
      if (method.isNotEmpty) method,
      if (shown.isNotEmpty) shown,
      if (status != null) '→ $status',
      if (ms != null) '· $ms ms',
    ];
    return parts.join(' ');
  }

  /// what it knew of it, as text to be read and copied
  String? get attrsText {
    if (attrs.isEmpty) return null;
    final keys = attrs.keys.toList()..sort();
    return [for (final k in keys) '$k: ${attrs[k]}'].join('\n');
  }

  static PlatformLogLine? parse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final level = LogLevel.parse(raw['level']);
    if (id is! String || id.isEmpty || level == null) return null;
    final attrs = raw['attrs'];
    return PlatformLogLine(
      id: id,
      at: raw['at'] == null ? null : DateTime.tryParse('${raw['at']}')?.toLocal(),
      level: level,
      message: raw['message'] is String ? raw['message'] as String : '',
      fn: raw['fn'] is String ? raw['fn'] as String : '',
      fnId: raw['fnId'] is String ? raw['fnId'] as String : '',
      status: raw['status'] is num ? (raw['status'] as num).toInt() : null,
      method: raw['method'] is String ? raw['method'] as String : '',
      path: raw['path'] is String ? raw['path'] as String : '',
      ms: raw['ms'] is num ? (raw['ms'] as num).toInt() : null,
      attrs: attrs is Map ? {for (final e in attrs.entries) '${e.key}': '${e.value}'} : const {},
    );
  }
}

/// a page of the platform's logs, newest first, and the functions there are to choose among
class PlatformLogsPage {
  const PlatformLogsPage({required this.rows, required this.functions, this.oldest});

  final List<PlatformLogLine> rows;
  final List<PlatformFunction> functions;

  /// the time of the oldest line, which is where the next page begins. null when there are none
  final String? oldest;

  /// there may be older ones: this page is full
  bool get mayHaveOlder => rows.length >= platformPageSize;

  /// what a function is called in a chip: its name, or the start of its number when the platform did not name it
  String nameOf(String fnId) {
    for (final f in functions) {
      if (f.id == fnId && f.slug.isNotEmpty) return f.slug;
    }
    return fnId.length > 8 ? fnId.substring(0, 8) : fnId;
  }

  /// the answer of the function. one that says it did not go well is an exception with the kind of what went wrong
  static PlatformLogsPage parse(Object? raw) {
    final map = raw is Map ? raw : const {};
    if (map['ok'] != true) {
      throw PlatformLogsException(PlatformProblem.of(map['error']), map['detail'] is String ? map['detail'] as String : null);
    }
    return PlatformLogsPage(
      rows: [
        for (final r in (map['rows'] as List? ?? const []))
          if (PlatformLogLine.parse(r) case final line?) line,
      ],
      functions: [
        for (final f in (map['functions'] as List? ?? const []))
          if (PlatformFunction.parse(f) case final fn?) fn,
      ],
      oldest: map['oldest'] is String ? map['oldest'] as String : null,
    );
  }
}

/// one key that the platform's logs have, of one source, and in how many of the lines. what is listed when a query was refused, to see what the lines really carry
class PlatformKey {
  const PlatformKey({required this.source, required this.key, required this.events});

  final String source;
  final String key;
  final int events;

  static List<PlatformKey> parseAll(Object? raw) {
    final map = raw is Map ? raw : const {};
    if (map['ok'] != true) {
      throw PlatformLogsException(PlatformProblem.of(map['error']), map['detail'] is String ? map['detail'] as String : null);
    }
    return [
      for (final k in (map['keys'] as List? ?? const []))
        if (k is Map && k['source'] is String && k['key'] is String)
          PlatformKey(source: k['source'] as String, key: k['key'] as String, events: asInt(k['events'])),
    ];
  }
}
