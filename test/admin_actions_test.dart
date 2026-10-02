import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyria_codex/screens/admin/system_tab.dart';
import 'package:tyria_codex/screens/admin/table_screen.dart';
import 'package:tyria_codex/state/admin.dart';
import 'package:tyria_codex/state/admin_actions.dart';
import 'package:tyria_codex/state/admin_system.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/theme.dart';

const _jobs = [
  AdminJob('dispatch-tp-sync', 'Read all of the trading post now', 'wake', false),
  AdminJob('daily-snapshot', 'Take the daily snapshot of the numbers', 'job', false),
  AdminJob('forget-old-open-events', 'Let go of public events that ended long ago', 'job', true),
];

/// a database that does what it is told to and says what it was told to say
class FakeBackend implements AdminBackend {
  FakeBackend({this.results = const {}, this.answers = const [], this.pageOf, this.failWith});

  final Map<String, JobResult> results;
  final List<CallAnswer?> answers;
  final AdminTablePage Function(TableQuery query)? pageOf;
  final Object? failWith;
  final ran = <String>[];
  final queries = <TableQuery>[];
  int asked = 0;

  @override
  Future<List<AdminJob>> jobs() async => _jobs;

  @override
  Future<JobResult> run(String job) async {
    ran.add(job);
    if (failWith != null) throw failWith!;
    return results[job] ?? const JobResult(ok: true);
  }

  @override
  Future<CallAnswer?> callResult(int requestId) async {
    final i = asked++;
    return answers.isEmpty ? null : answers[i < answers.length ? i : answers.length - 1];
  }

  @override
  Future<AdminTablePage> table(TableQuery query) async {
    queries.add(query);
    return pageOf!(query);
  }
}

AdminTablePage page(TableQuery q, {int total = 5, int limit = 2, List<Map<String, dynamic>>? rows}) => AdminTablePage({
      'table': q.table,
      'columns': [
        {'name': 'id', 'type': 'integer', 'key': true, 'hidden': false},
        {'name': 'note', 'type': 'text', 'key': false, 'hidden': false},
        {'name': 'api_token', 'type': 'text', 'key': false, 'hidden': true},
        {'name': 'created_at', 'type': 'timestamp with time zone', 'key': false, 'hidden': false},
      ],
      'rows': rows ??
          [
            {
              'id': q.offset + 1,
              'note': 'alpha',
              'api_token': '••••',
              'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toUtc().toIso8601String()
            },
            {'id': q.offset + 2, 'note': 'beta', 'api_token': '••••', 'created_at': null},
          ],
      'total': total,
      'limit': limit,
      'offset': q.offset,
      'ordered_by': 'created_at',
    });

void main() {
  group('the jobs', () {
    test('are read as the database lists them, one that is none is not a job', () {
      final job = AdminJob.parse({'name': 'daily-snapshot', 'what': 'Take it', 'kind': 'job', 'danger': false})!;
      expect([job.name, job.what, job.wakes, job.danger], ['daily-snapshot', 'Take it', false, false]);
      expect(AdminJob.parse({'name': 'dispatch-tp-sync', 'kind': 'wake', 'danger': true})!.wakes, isTrue);
      expect(AdminJob.parse({'name': 'x'})!.what, 'x', reason: 'its name when it says no more');
      expect(AdminJob.parse({'what': 'no name'}), isNull);
      expect(AdminJob.parse('text'), isNull);
      expect(AdminJob.parse(null), isNull);
    });

    test('have a result: it went well, or how it did not, and the number of the call for a function that was woken',
        () {
      final ok = JobResult.parse({'ok': true, 'job': 'dispatch-tp-sync', 'request_id': 77});
      expect([ok.ok, ok.requestId, ok.error], [true, 77, null]);
      final bad = JobResult.parse({'ok': false, 'error': 'boom'});
      expect([bad.ok, bad.error, bad.requestId], [false, 'boom', null]);
      expect(JobResult.parse(null).ok, isFalse, reason: 'no answer is no success');
      expect(JobResult.parse(null).error, isNotNull);
      expect(JobResult.parse({'ok': 'yes'}).ok, isFalse, reason: 'only a true is a yes');
    });
  });

  group('what a call answered', () {
    test('is its status and what it said, and a refusal says what it means', () {
      final ok = CallAnswer.parse({'status_code': 200, 'content': '{"read":28000}', 'timed_out': false})!;
      expect([ok.ok, ok.summary, ok.content], [true, '200', '{"read":28000}']);
      final refused = CallAnswer.parse({'status_code': 401, 'content': 'unauthorized'})!;
      expect(refused.ok, isFalse);
      expect(refused.summary, contains('401'));
      expect(refused.summary, contains('secret'));
      expect(CallAnswer.parse({'status_code': 500, 'content': 'x'})!.summary, '500');
      expect(CallAnswer.parse({'status_code': null, 'timed_out': true})!.summary, 'Timed out');
      expect(CallAnswer.parse({'status_code': null, 'error': 'refused'})!.summary, 'Failed: refused');
      expect(CallAnswer.parse({'status_code': null})!.summary, 'No status');
      expect(CallAnswer.parse(null), isNull, reason: 'no answer yet');
      expect(CallAnswer.parse({'status_code': 299})!.ok, isTrue);
      expect(CallAnswer.parse({'status_code': 300})!.ok, isFalse);
    });

    test('is waited for, a number of times, until it comes', () async {
      var asked = 0;
      final answer = await waitForAnswer(
          () async => ++asked < 3 ? null : const CallAnswer(statusCode: 200, content: 'x', timedOut: false),
          every: Duration.zero);
      expect(answer!.statusCode, 200);
      expect(asked, 3);
    });

    test('is none when it never comes, after as many tries as there are', () async {
      var asked = 0;
      expect(await waitForAnswer(() async => ++asked > 0 ? null : null, tries: 4, every: Duration.zero), isNull);
      expect(asked, 4);
    });

    test('is asked for once when it is there at once, and not waited for', () async {
      var asked = 0;
      await waitForAnswer(() async {
        asked++;
        return const CallAnswer(statusCode: 200, content: '', timedOut: false);
      }, every: const Duration(hours: 1));
      expect(asked, 1);
    });
  });

  group('a page of a table', () {
    test('has its columns, its rows and where it is', () {
      final p = page((table: 't', offset: 0, filter: ''));
      expect(p.table, 't');
      expect(p.columns.map((c) => c.name), ['id', 'note', 'api_token', 'created_at']);
      expect(p.columns.first.key, isTrue);
      expect(p.columns[2].hidden, isTrue);
      expect(p.rows.length, 2);
      expect([p.total, p.limit, p.offset, p.orderedBy], [5, 2, 0, 'created_at']);
      expect([p.hasPrevious, p.hasNext], [false, true]);
    });

    test('has a place before it and after it where there are rows', () {
      final middle = page((table: 't', offset: 2, filter: ''));
      expect([middle.hasPrevious, middle.hasNext], [true, true]);
      final last = page((
        table: 't',
        offset: 4,
        filter: ''
      ), rows: [
        {'id': 5}
      ]);
      expect([last.hasPrevious, last.hasNext], [true, false]);
      expect(const AdminTablePage({}).rows, isEmpty);
      expect(const AdminTablePage({}).limit, 50, reason: 'fifty when it says none');
    });

    test('says which rows it is, as a person says it', () {
      expect(rowsLabel(0, 50, 1234), '1–50 of 1,234');
      expect(rowsLabel(50, 10, 60), '51–60 of 60');
      expect(rowsLabel(0, 0, 0), '0 of 0');
      expect(rowsLabel(0, 0, 12), '0 of 12');
    });

    test('has its values written as a person reads them', () {
      expect(cellText(null), 'null');
      expect(cellText('text'), 'text');
      expect(cellText(5), '5');
      expect(cellText(true), 'true');
      expect(cellText({'a': 1}), '{"a":1}');
      expect(cellText([1, 'x']), '[1,"x"]');
    });

    test('has rows that are called by their key, else by their first columns, and never by a secret', () {
      final columns = page((table: 't', offset: 0, filter: '')).columns;
      expect(rowTitle(columns, {'id': 7, 'note': 'x'}), 'id: 7');
      final noKey = [
        const TableColumn('name', 'text', false, false),
        const TableColumn('kind', 'text', false, false),
        const TableColumn('size', 'int', false, false)
      ];
      expect(rowTitle(noKey, {'name': 'a', 'kind': 'b', 'size': 3}), 'name: a, kind: b');
      expect(rowTitle(noKey, {'name': 'a', 'kind': 'b'}, parts: 3), 'name: a, kind: b, size: null');
      final secret = [const TableColumn('token', 'text', true, true), const TableColumn('note', 'text', false, false)];
      expect(rowTitle(secret, {'token': '••••', 'note': 'hello'}), 'note: hello',
          reason: 'a key that is a secret is not told');
      expect(rowTitle(const [], {}), '(row)');
    });

    test('is a row that can be copied, written out', () {
      expect(rowJson({'id': 1, 'note': 'a'}), '{\n  "id": 1,\n  "note": "a"\n}');
    });
  });

  group('running by hand', () {
    Future<FakeBackend> show(WidgetTester tester, FakeBackend backend) async {
      tester.view.physicalSize = const Size(1800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          adminBackendProvider.overrideWithValue(backend),
          adminPollEveryProvider.overrideWithValue(Duration.zero),
          adminSystemProvider.overrideWith((ref) async => AdminSystem({
                'generated_at': DateTime.now().toUtc().toIso8601String(),
                'tables': [
                  {'name': 'tp_latest', 'rows': 28000, 'bytes': 3000000, 'newest': null},
                ],
              })),
          adminDashboardProvider.overrideWith((ref) async => AdminDashboard({})),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.6)),
            child: child!,
          ),
          home: const Scaffold(body: AdminSystemTab()),
        ),
      ));
      await tester.pumpAndSettle();
      return backend;
    }

    testWidgets(
        'lists the jobs with what each does and its name, and the ones that let go of data say so on their button',
        (tester) async {
      await show(tester, FakeBackend());
      expect(find.text('Read all of the trading post now'), findsOneWidget);
      expect(find.text('dispatch-tp-sync'), findsOneWidget);
      expect(find.text('Take the daily snapshot of the numbers'), findsOneWidget);
      expect(find.text('Run'), findsNWidgets(2));
      expect(find.text('Run…'), findsOneWidget);
    });

    testWidgets('runs a job of the database at once and says it is done', (tester) async {
      final backend = await show(tester, FakeBackend());
      await tester.tap(find.text('Run').last);
      await tester.pumpAndSettle();
      expect(backend.ran, ['daily-snapshot']);
      expect(find.text('daily-snapshot: done'), findsOneWidget);
    });

    testWidgets('asks before it lets go of data, and does nothing when it is said no', (tester) async {
      final backend = await show(tester, FakeBackend());
      await tester.tap(find.text('Run…'));
      await tester.pumpAndSettle();
      expect(find.text('Run forget-old-open-events?'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(backend.ran, isEmpty);
      await tester.tap(find.text('Run…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run it'));
      await tester.pumpAndSettle();
      expect(backend.ran, ['forget-old-open-events']);
    });

    testWidgets('wakes a function and tells what it answered, waiting for it as long as it takes', (tester) async {
      final backend = await show(
        tester,
        FakeBackend(
          results: {'dispatch-tp-sync': const JobResult(ok: true, requestId: 77)},
          answers: [null, null, const CallAnswer(statusCode: 200, content: '{"read":28000}', timedOut: false)],
        ),
      );
      await tester.tap(find.text('Run').first);
      await tester.pumpAndSettle();
      expect(backend.asked, 3, reason: 'asked until it answered');
      expect(find.text('Answered 200'), findsOneWidget);
      expect(find.text('{"read":28000}'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Answered 200'), findsNothing);
    });

    testWidgets('tells a refusal as one, with what it means', (tester) async {
      await show(
        tester,
        FakeBackend(
          results: {'dispatch-tp-sync': const JobResult(ok: true, requestId: 5)},
          answers: [const CallAnswer(statusCode: 401, content: 'unauthorized', timedOut: false)],
        ),
      );
      await tester.tap(find.text('Run').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Answered 401'), findsOneWidget);
      expect(find.textContaining('secret'), findsOneWidget);
      expect(find.text('unauthorized'), findsOneWidget);
    });

    testWidgets('says so when a function has not answered after all its tries', (tester) async {
      final backend =
          await show(tester, FakeBackend(results: {'dispatch-tp-sync': const JobResult(ok: true, requestId: 5)}));
      await tester.tap(find.text('Run').first);
      await tester.pumpAndSettle();
      expect(backend.asked, 15);
      expect(find.text('No answer yet'), findsOneWidget);
      expect(find.textContaining('fifteen seconds'), findsOneWidget);
    });

    testWidgets('says how a job went wrong, and that it did', (tester) async {
      await show(tester, FakeBackend(results: {'daily-snapshot': const JobResult(ok: false, error: 'boom')}));
      await tester.tap(find.text('Run').last);
      await tester.pumpAndSettle();
      expect(find.text('It failed'), findsOneWidget);
      expect(find.text('boom'), findsOneWidget);
    });

    testWidgets('says so when the database cannot be reached', (tester) async {
      await show(tester, FakeBackend(failWith: Exception('no network')));
      await tester.tap(find.text('Run').last);
      await tester.pumpAndSettle();
      expect(find.text('It failed'), findsOneWidget);
      expect(find.textContaining('no network'), findsOneWidget);
    });

    testWidgets('opens a table from the list of tables', (tester) async {
      final backend = await show(tester, FakeBackend(pageOf: (q) => page(q)));
      await tester.scrollUntilVisible(find.text('tp_latest'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('tp_latest'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminTableScreen), findsOneWidget);
      expect(backend.queries.single, (table: 'tp_latest', offset: 0, filter: ''));
    });
  });

  group('a table', () {
    Future<FakeBackend> open(WidgetTester tester, FakeBackend backend) async {
      tester.view.physicalSize = const Size(1400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs), adminBackendProvider.overrideWithValue(backend)],
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.6)),
            child: child!,
          ),
          home: const AdminTableScreen(table: 'zz_admin_test'),
        ),
      ));
      await tester.pumpAndSettle();
      return backend;
    }

    testWidgets('has its name, which rows these are, its columns and what it is in the order of', (tester) async {
      await open(tester, FakeBackend(pageOf: (q) => page(q)));
      expect(find.text('zz_admin_test'), findsOneWidget);
      expect(find.text('1–2 of 5'), findsOneWidget);
      expect(find.text('4 columns'), findsOneWidget);
      expect(find.text('Newest first, by created_at'), findsOneWidget);
      expect(find.text('id: 1'), findsOneWidget);
      expect(find.text('id: 2'), findsOneWidget);
      expect(find.text('5 min ago'), findsOneWidget, reason: 'when the row was made');
    });

    testWidgets('opens a row to all of its columns, and a secret is hidden', (tester) async {
      await open(tester, FakeBackend(pageOf: (q) => page(q)));
      expect(find.text('alpha'), findsNothing, reason: 'shut');
      await tester.tap(find.text('id: 1'));
      await tester.pumpAndSettle();
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('••••'), findsOneWidget);
      expect(find.text('api_token'), findsOneWidget);
      expect(find.text('Copy as JSON'), findsOneWidget);
    });

    testWidgets('copies a row as JSON', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester, FakeBackend(pageOf: (q) => page(q)));
      await tester.tap(find.text('id: 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy as JSON'));
      await tester.pumpAndSettle();
      expect(copied, contains('"note": "alpha"'));
      expect(find.text('Row copied'), findsOneWidget);
    });

    testWidgets('goes to the next page and back, and neither where there is none', (tester) async {
      final backend = await open(tester, FakeBackend(pageOf: (q) => page(q)));
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull,
          reason: 'none before the first');
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(backend.queries.last.offset, 2);
      expect(find.text('3–4 of 5'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(backend.queries.last.offset, 0);
    });

    testWidgets('has no next page after the last rows', (tester) async {
      await open(tester, FakeBackend(pageOf: (q) => page(q, total: 2)));
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
    });

    testWidgets('searches the rows for what is typed, from the first page, and clears the search', (tester) async {
      final backend = await open(tester, FakeBackend(pageOf: (q) => page(q)));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(backend.queries.last.offset, 2);
      await tester.enterText(find.byType(TextField), '  alpha ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(backend.queries.last, (table: 'zz_admin_test', offset: 0, filter: 'alpha'),
          reason: 'trimmed, and from the first page');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(backend.queries.last, (table: 'zz_admin_test', offset: 0, filter: ''));
      expect(find.byIcon(Icons.close), findsNothing, reason: 'nothing to clear');
    });

    testWidgets('says so when no row has the text', (tester) async {
      await open(tester, FakeBackend(pageOf: (q) => page(q, total: 0, rows: const [])));
      expect(find.text('No row has that.'), findsOneWidget);
      expect(find.text('0 of 0'), findsOneWidget);
    });

    testWidgets('lists the columns with their types when they are asked for', (tester) async {
      await open(tester, FakeBackend(pageOf: (q) => page(q)));
      await tester.tap(find.text('4 columns'));
      await tester.pumpAndSettle();
      expect(find.text('timestamp with time zone'), findsOneWidget);
      expect(find.text('integer'), findsOneWidget);
      expect(find.byIcon(Icons.key), findsOneWidget, reason: 'the key');
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget, reason: 'the secret');
    });
  });
}
