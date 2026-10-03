import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyria_codex/screens/admin/logs_screen.dart';
import 'package:tyria_codex/state/admin_actions.dart';
import 'package:tyria_codex/state/admin_logs.dart';
import 'package:tyria_codex/state/admin_platform_logs.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/theme.dart';

import 'admin_actions_test.dart' show FakeBackend;

String _at(int minutesAgo) => DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)).toIso8601String();

Map<String, dynamic> _line(String id, String level, String message,
        {String fn = 'tp-sync', String fnId = 'f-1', int minutesAgo = 5, Map<String, dynamic>? more}) =>
    {'id': id, 'at': _at(minutesAgo), 'level': level, 'message': message, 'fn': fn, 'fnId': fnId, ...?more};

Map<String, dynamic> _request(String id, int status,
        {int? ms = 1235, String path = 'https://abc.supabase.co/functions/v1/tp-sync'}) =>
    _line(id, status >= 500 ? 'error' : (status >= 400 ? 'warn' : 'info'), 'POST | $status',
        more: {'status': status, 'method': 'POST', 'path': path, 'ms': ms});

PlatformLogsPage _page(List<Map<String, dynamic>> rows, {List<Map<String, dynamic>>? functions, String? oldest}) =>
    PlatformLogsPage.parse({
      'ok': true,
      'rows': rows,
      'functions': functions ??
          [
            {'id': 'f-1', 'slug': 'tp-sync'},
            {'id': 'f-2', 'slug': 'push-sync'},
          ],
      'oldest': oldest ?? (rows.isEmpty ? null : rows.last['at']),
    });

void main() {
  group('what is sent to ask for the logs of the platform', () {
    test('is the source, the window and a page, and nothing that was not chosen', () {
      expect(platformBody(platformStart), {'source': 'console', 'hours': 1, 'limit': 50});
    });

    test('has the function, the text and the end of the window when they are chosen', () {
      final body = platformBody((
        source: PlatformSource.console,
        fnId: 'f-1',
        level: null,
        search: 'boom',
        hours: 6,
        before: '2026-10-03T09:30:00.000Z',
        onlyErrors: false
      ));
      expect(body, {
        'source': 'console',
        'fnId': 'f-1',
        'search': 'boom',
        'hours': 6,
        'before': '2026-10-03T09:30:00.000Z',
        'limit': 50
      });
    });

    test('has the level for the console only, and only the failed for the requests only', () {
      expect(
          platformBody((
            source: PlatformSource.console,
            fnId: null,
            level: LogLevel.error,
            search: '',
            hours: 1,
            before: null,
            onlyErrors: true
          )),
          {'source': 'console', 'level': 'error', 'hours': 1, 'limit': 50},
          reason: 'a request that failed is of the requests');
      expect(
          platformBody((
            source: PlatformSource.requests,
            fnId: null,
            level: LogLevel.warn,
            search: '',
            hours: 24,
            before: null,
            onlyErrors: true
          )),
          {'source': 'requests', 'onlyErrors': true, 'hours': 24, 'limit': 50},
          reason: 'a level is of the console');
      expect(
          platformBody((
            source: PlatformSource.requests,
            fnId: null,
            level: null,
            search: '',
            hours: 1,
            before: null,
            onlyErrors: false
          )).containsKey('onlyErrors'),
          isFalse);
    });

    test('has sources that are named as the function names them', () {
      expect(PlatformSource.console.code, 'console');
      expect(PlatformSource.requests.code, 'requests');
      expect(PlatformSource.values.map((s) => s.label), ['Console', 'Requests']);
      expect(platformHours, [1, 6, 24], reason: 'as far back as the platform\'s API takes');
    });
  });

  group('what went wrong', () {
    test('is told by a kind for each word the function uses', () {
      expect(PlatformProblem.of('not_configured'), PlatformProblem.notConfigured);
      expect(PlatformProblem.of('token_rejected'), PlatformProblem.tokenRejected);
      expect(PlatformProblem.of('plan'), PlatformProblem.plan);
      expect(PlatformProblem.of('rate_limited'), PlatformProblem.rateLimited);
      expect(PlatformProblem.of('upstream'), PlatformProblem.upstream);
      expect(PlatformProblem.of('query_error'), PlatformProblem.queryError);
      expect(PlatformProblem.of('not_admin'), PlatformProblem.notAdmin);
      expect(PlatformProblem.of('not_signed_in'), PlatformProblem.notSignedIn);
      expect(PlatformProblem.of('bad_before'), PlatformProblem.tooFar);
      expect(PlatformProblem.of('something new'), PlatformProblem.unknown);
      expect(PlatformProblem.of(null), PlatformProblem.unknown);
    });
  });

  group('a line of the platform logs', () {
    test('is read: when, how serious, what it said and of which function', () {
      final line = PlatformLogLine.parse(_line('a', 'error', 'tp sync failed', more: {
        'attrs': {'version': '7', 'function_id': 'f-1'}
      }))!;
      expect(line.id, 'a');
      expect(line.level, LogLevel.error);
      expect(line.message, 'tp sync failed');
      expect(line.fn, 'tp-sync');
      expect(line.fnId, 'f-1');
      expect(line.at, isNotNull);
      expect(line.isRequest, isFalse);
      expect(line.attrsText, 'function_id: f-1\nversion: 7', reason: 'in the order of the alphabet');
    });

    test('is a request when it has a status or a method, and says it in a line without the host', () {
      final line = PlatformLogLine.parse(_request('r', 503))!;
      expect(line.isRequest, isTrue);
      expect(line.status, 503);
      expect(line.ms, 1235);
      expect(line.requestLine, 'POST /functions/v1/tp-sync → 503 · 1235 ms');
      expect(PlatformLogLine.parse(_request('r', 200, ms: null))!.requestLine, 'POST /functions/v1/tp-sync → 200');
      expect(PlatformLogLine.parse(_request('r', 200, path: '/functions/v1/x'))!.requestLine,
          'POST /functions/v1/x → 200 · 1235 ms');
      expect(PlatformLogLine.parse(_line('x', 'info', 'm', more: {'status': 404}))!.requestLine, '→ 404');
    });

    test('is not read when it lacks what a line must have', () {
      expect(PlatformLogLine.parse(null), isNull);
      expect(PlatformLogLine.parse('text'), isNull);
      expect(PlatformLogLine.parse({'level': 'info'}), isNull, reason: 'no number');
      expect(PlatformLogLine.parse({'id': '', 'level': 'info'}), isNull);
      expect(PlatformLogLine.parse({'id': 'a', 'level': 'loud'}), isNull, reason: 'a level that is none');
      expect(PlatformLogLine.parse({'id': 'a'}), isNull);
      final bare = PlatformLogLine.parse({'id': 'a', 'level': 'info', 'at': 'not a time'})!;
      expect((bare.at, bare.message, bare.fn, bare.status, bare.attrsText), (null, '', '', null, null));
    });

    test('has attributes written as text, whatever they were', () {
      final line = PlatformLogLine.parse(_line('a', 'info', 'm', more: {
        'attrs': {'n': 5, 'b': true}
      }))!;
      expect(line.attrs, {'n': '5', 'b': 'true'});
    });
  });

  group('a page of the platform logs', () {
    test('has its lines, the functions to choose among and where the next page begins', () {
      final page = _page([_line('b', 'error', 'new'), _line('a', 'info', 'old', minutesAgo: 30)],
          oldest: '2026-10-03T11:00:00.000Z');
      expect(page.rows.map((r) => r.id), ['b', 'a']);
      expect(page.functions.map((f) => f.slug), ['tp-sync', 'push-sync']);
      expect(page.oldest, '2026-10-03T11:00:00.000Z');
      expect(page.mayHaveOlder, isFalse);
    });

    test('may have older lines only when it is full', () {
      expect(_page([for (var i = 0; i < 49; i++) _line('$i', 'info', 'm')]).mayHaveOlder, isFalse);
      expect(_page([for (var i = 0; i < 50; i++) _line('$i', 'info', 'm')]).mayHaveOlder, isTrue);
    });

    test('names a function by its name, or by the start of its number when the platform did not name it', () {
      final page = _page([], functions: [
        {'id': 'f-1', 'slug': 'tp-sync'},
        {'id': 'abcdefghijklmnop', 'slug': ''},
      ]);
      expect(page.nameOf('f-1'), 'tp-sync');
      expect(page.nameOf('abcdefghijklmnop'), 'abcdefgh');
      expect(page.nameOf('short'), 'short');
      expect(page.nameOf('unknown-function-number'), 'unknown-');
    });

    test('is nothing, and no failure, when the platform had nothing', () {
      final page = PlatformLogsPage.parse({'ok': true});
      expect(page.rows, isEmpty);
      expect(page.functions, isEmpty);
      expect(page.oldest, isNull);
    });

    test('leaves out a line or a function that cannot be read and keeps the rest', () {
      final page = PlatformLogsPage.parse({
        'ok': true,
        'rows': [
          _line('a', 'info', 'ok'),
          {'id': 'b'},
          'junk'
        ],
        'functions': [
          {'id': 'f-1', 'slug': 'x'},
          {'slug': 'no id'},
          5,
        ],
      });
      expect(page.rows.length, 1);
      expect(page.functions.length, 1);
    });

    test('is an exception with the kind of what went wrong when the answer says it did not go well', () {
      for (final (raw, problem) in [
        ({'ok': false, 'error': 'not_configured'}, PlatformProblem.notConfigured),
        ({'ok': false, 'error': 'token_rejected', 'status': 401}, PlatformProblem.tokenRejected),
        ({'ok': false}, PlatformProblem.unknown),
        (null, PlatformProblem.unknown),
        ('text', PlatformProblem.unknown),
        (<String, dynamic>{}, PlatformProblem.unknown),
      ]) {
        expect(() => PlatformLogsPage.parse(raw),
            throwsA(isA<PlatformLogsException>().having((e) => e.problem, 'problem', problem)),
            reason: '$raw');
      }
    });

    test('keeps what the platform said of a query it refused', () {
      try {
        PlatformLogsPage.parse({'ok': false, 'error': 'query_error', 'detail': "Unknown identifier 'foo'"});
        fail('it should have thrown');
      } on PlatformLogsException catch (e) {
        expect(e.problem, PlatformProblem.queryError);
        expect(e.detail, "Unknown identifier 'foo'");
        expect(e.toString(), contains("Unknown identifier 'foo'"));
      }
    });
  });

  group('the keys the logs have', () {
    test('are read with their source and how many lines carry each', () {
      final keys = PlatformKey.parseAll({
        'ok': true,
        'keys': [
          {'source': 'function_logs', 'key': 'function_id', 'events': 120},
          {'source': 'function_edge_logs', 'key': 'response.status_code', 'events': '98'},
          {'source': 'function_edge_logs'},
          'junk',
        ],
      });
      expect(keys.map((k) => (k.source, k.key, k.events)),
          [('function_logs', 'function_id', 120), ('function_edge_logs', 'response.status_code', 98)]);
    });

    test('are an exception when the answer did not go well', () {
      expect(() => PlatformKey.parseAll({'ok': false, 'error': 'upstream'}), throwsA(isA<PlatformLogsException>()));
      expect(PlatformKey.parseAll({'ok': true}), isEmpty);
    });
  });

  group('the platform logs in the screen', () {
    late List<String> copied;

    setUp(() => copied = []);

    Future<FakeBackend> open(WidgetTester tester, FakeBackend backend, {bool platform = true}) async {
      tester.view.physicalSize = const Size(1400, 4200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs), adminBackendProvider.overrideWithValue(backend)],
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.6)), child: child!),
          home: AdminLogsScreen(platform: platform),
        ),
      ));
      await tester.pumpAndSettle();
      return backend;
    }

    final console = [
      _line('b', 'error', 'tp sync failed', more: {
        'attrs': {'version': '7'}
      }),
      _line('a', 'info', 'read 28000 prices', fn: 'push-sync', fnId: 'f-2', minutesAgo: 20)
    ];

    testWidgets('begins with the lines the functions kept, and the platform\'s is a choice', (tester) async {
      final backend = await open(tester, FakeBackend(platformOf: (q) => _page(console)), platform: false);
      expect(find.byKey(const Key('log-search')), findsOneWidget);
      expect(find.byKey(const Key('platform-search')), findsNothing);
      expect(backend.platformQueries, isEmpty, reason: 'the platform is not asked until it is looked at');
      await tester.tap(find.text('Supabase platform'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('platform-search')), findsOneWidget);
      expect(find.byKey(const Key('log-search')), findsNothing);
      expect(backend.platformQueries.first, platformStart);
      await tester.tap(find.text('Saved by the functions'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('log-search')), findsOneWidget);
    });

    testWidgets('can begin with the platform\'s', (tester) async {
      final backend = await open(tester, FakeBackend(platformOf: (q) => _page(console)));
      expect(find.byKey(const Key('platform-search')), findsOneWidget);
      expect(backend.platformQueries.first, platformStart);
    });

    testWidgets(
        'shows what the functions wrote, which function, how long ago and how serious, and opens a line to what the platform knows',
        (tester) async {
      await open(tester, FakeBackend(platformOf: (q) => _page(console)));
      expect(find.text('tp sync failed'), findsOneWidget);
      expect(find.text('read 28000 prices'), findsOneWidget);
      expect(find.textContaining('tp-sync ·'), findsOneWidget);
      expect(find.textContaining('push-sync ·'), findsOneWidget);
      expect(find.textContaining('5 min ago'), findsOneWidget);
      expect(find.text('Tap for what the platform knows'), findsOneWidget, reason: 'only the line that has something');
      expect(find.textContaining('version: 7'), findsNothing);
      await tester.tap(find.text('tp sync failed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('version: 7'), findsOneWidget);
      await tester.tap(find.text('tp sync failed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('version: 7'), findsNothing);
    });

    testWidgets(
        'shows a request by its line, with how it was answered, and what the function said of it when it is opened',
        (tester) async {
      await open(tester, FakeBackend(platformOf: (q) => _page([_request('r1', 503)])));
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.text('POST /functions/v1/tp-sync → 503 · 1235 ms'), findsOneWidget);
      expect(find.text('POST | 503'), findsNothing);
      await tester.tap(find.text('POST /functions/v1/tp-sync → 503 · 1235 ms'));
      await tester.pumpAndSettle();
      expect(find.text('POST | 503'), findsOneWidget, reason: 'the message, once it is opened');
    });

    testWidgets('copies a line, with when, how serious, which function, what and what the platform knows',
        (tester) async {
      await open(tester, FakeBackend(platformOf: (q) => _page(console)));
      await tester.tap(find.byTooltip('Copy').first);
      await tester.pump();
      expect(copied.single, contains('error tp-sync: tp sync failed'));
      expect(copied.single, contains('version: 7'));
    });

    testWidgets('has a chip for each function, and asks for the lines of one by its number', (tester) async {
      final backend = await open(tester, FakeBackend(platformOf: (q) => _page(console)));
      expect(find.text('All functions'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'tp-sync'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'push-sync'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.fnId, 'f-2');
      await tester.tap(find.text('All functions'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.fnId, isNull);
    });

    testWidgets('keeps the chip of a function that was chosen when the list no longer has it', (tester) async {
      final backend = await open(
        tester,
        FakeBackend(platformOf: (q) => q.fnId == null ? _page(console) : _page([], functions: [])),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'tp-sync'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.fnId, 'f-1');
      expect(
          find.byType(ChoiceChip).evaluate().any(
              (e) => (e.widget as ChoiceChip).selected && (e.widget as ChoiceChip).label.toString().contains('f-1')),
          isTrue,
          reason: 'it is still there, named by its number');
    });

    testWidgets('asks for the requests, and for the console again', (tester) async {
      final backend = await open(tester, FakeBackend(platformOf: (q) => _page(console)));
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.source, PlatformSource.requests);
      expect(find.text('All levels'), findsNothing, reason: 'a level is of the console');
      expect(find.text('Only the ones that failed'), findsOneWidget);
      await tester.tap(find.text('Console'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.source, PlatformSource.console);
      expect(find.text('All levels'), findsOneWidget);
    });

    testWidgets('asks for one level of the console, and for all again', (tester) async {
      final backend = await open(tester, FakeBackend(platformOf: (q) => _page(console)));
      await tester.tap(find.text('Errors'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.level, LogLevel.error);
      await tester.tap(find.text('All levels'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.level, isNull);
    });

    testWidgets('asks for the requests that failed only', (tester) async {
      final backend = await open(tester, FakeBackend(platformOf: (q) => _page([_request('r', 500)])));
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Only the ones that failed'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.onlyErrors, isTrue);
      await tester.tap(find.text('Only the ones that failed'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.onlyErrors, isFalse);
    });

    testWidgets('asks for the last hour, six hours or the day', (tester) async {
      final backend = await open(tester, FakeBackend(platformOf: (q) => _page(console)));
      expect(find.text('Last hour'), findsOneWidget);
      await tester.tap(find.text('Last 6 hours'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.hours, 6);
      await tester.tap(find.text('Last 24 hours'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.hours, 24);
      await tester.tap(find.text('Last hour'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.hours, 1);
    });

    testWidgets('searches for a text, trimmed, and clears the search', (tester) async {
      final backend = await open(tester, FakeBackend(platformOf: (q) => _page(console)));
      await tester.enterText(find.byKey(const Key('platform-search')), '  fcm  ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.search, 'fcm');
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.last.search, '');
    });

    testWidgets('says so when nothing was recorded in the window', (tester) async {
      await open(tester, FakeBackend(platformOf: (q) => _page([])));
      expect(find.text('Nothing was recorded in this window. Try a longer one.'), findsOneWidget);
      expect(find.text('Older'), findsNothing);
    });

    testWidgets(
        'asks for the older lines with the time of the oldest of the page as the end of the window, and keeps the newer ones',
        (tester) async {
      final newest = [for (var i = 0; i < 50; i++) _line('n$i', 'info', 'newer $i', minutesAgo: i)];
      final backend = await open(
        tester,
        FakeBackend(
            platformOf: (q) => q.before == null
                ? _page(newest, oldest: '2026-10-03T10:00:00.000Z')
                : _page([_line('o1', 'info', 'older one', minutesAgo: 90)])),
      );
      await tester.ensureVisible(find.text('Older'));
      await tester.tap(find.text('Older'));
      await tester.pumpAndSettle();
      expect(backend.platformQueries.any((q) => q.before == '2026-10-03T10:00:00.000Z'), isTrue);
      expect(find.text('older one'), findsOneWidget);
      expect(find.text('newer 0'), findsOneWidget, reason: 'the newer ones are still there');
      expect(find.text('Older'), findsNothing, reason: 'the last page was not full');
    });

    testWidgets('begins again at the newest when a filter is changed', (tester) async {
      final newest = [for (var i = 0; i < 50; i++) _line('n$i', 'info', 'newer $i', minutesAgo: i)];
      await open(
          tester,
          FakeBackend(
              platformOf: (q) => q.before == null
                  ? _page(newest, oldest: '2026-10-03T10:00:00.000Z')
                  : _page([_line('o1', 'info', 'older one', minutesAgo: 90)])));
      await tester.ensureVisible(find.text('Older'));
      await tester.tap(find.text('Older'));
      await tester.pumpAndSettle();
      expect(find.text('older one'), findsOneWidget);
      await tester.tap(find.text('Last 6 hours'));
      await tester.pumpAndSettle();
      expect(find.text('older one'), findsNothing, reason: 'that page belonged to the other window');
    });

    group('when it cannot be read', () {
      PlatformLogsPage failWith(PlatformProblem problem, [String? detail]) =>
          throw PlatformLogsException(problem, detail);

      testWidgets('tells how to set it up when there is no token, with the steps and what to copy', (tester) async {
        await open(tester, FakeBackend(platformOf: (q) => failWith(PlatformProblem.notConfigured)));
        expect(find.text('The platform logs are not set up'), findsOneWidget);
        expect(find.textContaining('https://supabase.com/dashboard/account/tokens'), findsOneWidget);
        expect(find.textContaining('Analytics logs: read'), findsOneWidget);
        expect(find.textContaining('PLATFORM_LOGS_TOKEN'), findsWidgets);
        expect(find.textContaining('Deploy workflow'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget, reason: 'what is done once the token is in and the function is deployed');
        await tester.tap(find.text('Copy the secret name'));
        await tester.pump();
        expect(copied.last, 'PLATFORM_LOGS_TOKEN');
        await tester.tap(find.text('Copy the token page'));
        await tester.pump();
        expect(copied.last, 'https://supabase.com/dashboard/account/tokens');
      });

      testWidgets('says what to do about a token the platform turned down', (tester) async {
        await open(tester, FakeBackend(platformOf: (q) => failWith(PlatformProblem.tokenRejected)));
        expect(find.text('Supabase turned the token down'), findsOneWidget);
        expect(find.textContaining('Analytics logs: read'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
      });

      testWidgets('has words for each of the other things that can go wrong', (tester) async {
        for (final (problem, title) in [
          (PlatformProblem.plan, 'The logs are not in the plan'),
          (PlatformProblem.rateLimited, 'Supabase is limiting the logs'),
          (PlatformProblem.upstream, 'Supabase did not give the logs'),
          (PlatformProblem.notAdmin, 'Only for an administrator'),
          (PlatformProblem.notSignedIn, 'Sign in again'),
          (PlatformProblem.tooFar, 'That is as far back as the logs go'),
          (PlatformProblem.unknown, 'The platform logs could not be read'),
        ]) {
          await open(tester, FakeBackend(platformOf: (q) => failWith(problem)));
          expect(find.text(title), findsOneWidget, reason: '$problem');
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('has no way to try again for what trying again cannot change', (tester) async {
        await open(tester, FakeBackend(platformOf: (q) => failWith(PlatformProblem.notAdmin)));
        expect(find.text('Try again'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await open(tester, FakeBackend(platformOf: (q) => failWith(PlatformProblem.tooFar)));
        expect(find.text('Try again'), findsNothing);
      });

      testWidgets('asks again when asked to', (tester) async {
        var calls = 0;
        final backend = await open(tester, FakeBackend(platformOf: (q) {
          calls++;
          if (calls == 1) failWith(PlatformProblem.upstream);
          return _page(console);
        }));
        expect(find.text('Supabase did not give the logs'), findsOneWidget);
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('tp sync failed'), findsOneWidget);
        expect(backend.platformQueries.length, greaterThan(1));
      });

      testWidgets('shows what the platform said of a query it refused, and what the logs really have', (tester) async {
        final backend = await open(
          tester,
          FakeBackend(
            platformOf: (q) => failWith(PlatformProblem.queryError, "Unknown identifier 'foo'"),
            keysOf: () => const [
              PlatformKey(source: 'function_logs', key: 'function_id', events: 120),
              PlatformKey(source: 'function_edge_logs', key: 'response.status_code', events: 98),
            ],
          ),
        );
        expect(find.text('Supabase refused the query'), findsOneWidget);
        expect(find.textContaining("Unknown identifier 'foo'"), findsOneWidget);
        expect(backend.keyRequests, 0, reason: 'asked only when the administrator wants to see');
        await tester.tap(find.text('Show what the logs have'));
        await tester.pumpAndSettle();
        expect(find.text('What the logs have'), findsOneWidget);
        expect(find.textContaining('function_logs  function_id  ×120'), findsOneWidget);
        expect(find.textContaining('function_edge_logs  response.status_code  ×98'), findsOneWidget);
        expect(backend.keyRequests, 1);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('What the logs have'), findsNothing);
      });

      testWidgets('says so when the keys cannot be read or there are none', (tester) async {
        await open(
            tester, FakeBackend(platformOf: (q) => failWith(PlatformProblem.queryError, 'x'), keysOf: () => const []));
        await tester.tap(find.text('Show what the logs have'));
        await tester.pumpAndSettle();
        expect(find.text('No lines in the last minute.'), findsOneWidget);
      });
    });
  });
}
