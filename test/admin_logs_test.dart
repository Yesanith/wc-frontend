import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyria_codex/screens/admin/logs_screen.dart';
import 'package:tyria_codex/screens/admin/system_tab.dart';
import 'package:tyria_codex/state/admin.dart';
import 'package:tyria_codex/state/admin_actions.dart';
import 'package:tyria_codex/state/admin_logs.dart';
import 'package:tyria_codex/state/admin_system.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/theme.dart';

import 'admin_actions_test.dart' show FakeBackend;

String _at(int minutesAgo) => DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)).toIso8601String();

Map<String, dynamic> _line(int id, String fn, String level, String message, {int minutesAgo = 5, Map<String, dynamic>? detail}) =>
    {'id': id, 'at': _at(minutesAgo), 'fn': fn, 'level': level, 'message': message, 'detail': detail};

FunctionLogsPage _page(List<Map<String, dynamic>> rows, {int total = 0, List<Map<String, dynamic>>? functions}) =>
    FunctionLogsPage.parse({
      'rows': rows,
      'functions': functions ??
          [
            {'fn': 'push-sync', 'errors': 0, 'warnings': 1, 'notes': 0, 'last_at': _at(30)},
            {'fn': 'tp-sync', 'errors': 2, 'warnings': 0, 'notes': 1, 'last_at': _at(5)},
          ],
      'total': total == 0 ? rows.length : total,
    });

void main() {
  group('a line of what a function said', () {
    test('is read with its function, level, words, time and what it knew', () {
      final line = FunctionLogLine.parse(_line(7, 'tp-sync', 'error', 'tp sync failed', detail: {'status': 503}))!;
      expect(line.id, 7);
      expect(line.fn, 'tp-sync');
      expect(line.level, LogLevel.error);
      expect(line.message, 'tp sync failed');
      expect(line.at, isNotNull);
      expect(line.detail, {'status': 503});
      expect(line.detailText, contains('"status": 503'), reason: 'to be read and copied');
    });

    test('says how many times it was said, which the database counts, and keeps the count out of what it knew', () {
      final line = FunctionLogLine.parse(_line(1, 'a', 'warn', 'm', detail: {'repeats': 4, 'code': 'x'}))!;
      expect(line.repeats, 4);
      expect(line.detailText, isNot(contains('repeats')));
      expect(line.detailText, contains('"code": "x"'));
      expect(FunctionLogLine.parse(_line(1, 'a', 'warn', 'm'))!.repeats, 1, reason: 'once when it is not counted');
      expect(FunctionLogLine.parse(_line(1, 'a', 'warn', 'm', detail: {'repeats': 1}))!.repeats, 1);
      expect(FunctionLogLine.parse(_line(1, 'a', 'warn', 'm', detail: {'repeats': 3}))!.detailText, isNull, reason: 'a count is not something it knew');
    });

    test('is not read when it lacks what a line must have, so that nothing is made up', () {
      expect(FunctionLogLine.parse(null), isNull);
      expect(FunctionLogLine.parse('text'), isNull);
      expect(FunctionLogLine.parse({'id': 1, 'fn': 'a', 'message': 'm'}), isNull, reason: 'no level');
      expect(FunctionLogLine.parse({'id': 1, 'fn': 'a', 'level': 'loud', 'message': 'm'}), isNull, reason: 'a level that is none');
      expect(FunctionLogLine.parse({'id': 1, 'level': 'error', 'message': 'm'}), isNull, reason: 'no function');
      expect(FunctionLogLine.parse({'id': 1, 'fn': 'a', 'level': 'error'}), isNull, reason: 'no words');
      expect(FunctionLogLine.parse({'id': 1, 'fn': 'a', 'level': 'info', 'message': 'm', 'at': 'not a time'})!.at, isNull);
    });

    test('has levels that are named as the database names them', () {
      expect(LogLevel.parse('error'), LogLevel.error);
      expect(LogLevel.parse('warn'), LogLevel.warn);
      expect(LogLevel.parse('info'), LogLevel.info);
      expect(LogLevel.parse('debug'), isNull);
      expect(LogLevel.parse(null), isNull);
      expect(LogLevel.values.map((l) => l.label), ['Errors', 'Warnings', 'Notes']);
    });
  });

  group('how a function did', () {
    FunctionStat stat(int errors, int warnings, int notes) =>
        FunctionStat.parse({'fn': 'x', 'errors': errors, 'warnings': warnings, 'notes': notes})!;

    test('is told by its errors and its warnings, or by its notes, or by nothing', () {
      expect(stat(2, 1, 5).summary, '2 errors · 1 warning');
      expect(stat(1, 0, 5).summary, '1 error');
      expect(stat(0, 3, 0).summary, '3 warnings');
      expect(stat(0, 0, 1).summary, '1 note');
      expect(stat(0, 0, 4).summary, '4 notes');
      expect(stat(0, 0, 0).summary, 'nothing');
    });

    test('is not read without a function', () {
      expect(FunctionStat.parse({'errors': 1}), isNull);
      expect(FunctionStat.parse(null), isNull);
    });
  });

  group('a page of the logs', () {
    test('has its lines newest first, how each function did and how many there are in all', () {
      final page = _page([_line(9, 'tp-sync', 'error', 'new'), _line(4, 'push-sync', 'warn', 'old')], total: 120);
      expect(page.rows.map((r) => r.message), ['new', 'old']);
      expect(page.functions.map((f) => f.fn), ['push-sync', 'tp-sync']);
      expect(page.total, 120);
      expect(page.errorsToday, 2);
      expect(page.oldestId, 4, reason: 'the older ones are asked for after it');
    });

    test('may have older lines only when it is full', () {
      expect(_page([_line(1, 'a', 'info', 'm')]).mayHaveOlder, isFalse);
      expect(_page([for (var i = 100; i > 50; i--) _line(i, 'a', 'info', 'm$i')]).mayHaveOlder, isFalse, reason: '49 lines');
      expect(_page([for (var i = 100; i > 49; i--) _line(i, 'a', 'info', 'm$i')]).mayHaveOlder, isTrue, reason: '50 lines');
    });

    test('is nothing, without failing, when the answer is not what was expected', () {
      for (final raw in [null, 'x', <dynamic>[], {'rows': 'no'}, <String, dynamic>{}]) {
        final page = FunctionLogsPage.parse(raw);
        expect(page.rows, isEmpty);
        expect(page.functions, isEmpty);
        expect(page.total, 0);
        expect(page.oldestId, isNull);
      }
    });

    test('leaves out a line that cannot be read and keeps the rest', () {
      final page = FunctionLogsPage.parse({
        'rows': [_line(2, 'a', 'error', 'ok'), {'id': 1, 'fn': 'a'}, 'junk'],
        'functions': [{'fn': 'a', 'errors': 1}, {'errors': 5}],
        'total': 3,
      });
      expect(page.rows.length, 1);
      expect(page.functions.length, 1);
    });
  });

  group('the screen of the logs', () {
    Future<FakeBackend> open(WidgetTester tester, FakeBackend backend, {String? fn}) async {
      tester.view.physicalSize = const Size(1400, 3200);
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
          home: AdminLogsScreen(fn: fn),
        ),
      ));
      await tester.pumpAndSettle();
      return backend;
    }

    final lines = [
      _line(30, 'tp-sync', 'error', 'tp sync failed', detail: {'status': 503, 'repeats': 3}),
      _line(20, 'push-sync', 'warn', 'fcm refused a message: 404'),
      _line(10, 'tp-sync', 'info', 'read 28000 prices'),
    ];

    testWidgets('shows what was said, by whom, how long ago and how often, newest first', (tester) async {
      await open(tester, FakeBackend(logsOf: (q) => _page(lines)));
      expect(find.text('Function logs'), findsOneWidget);
      expect(find.text('tp sync failed'), findsOneWidget);
      expect(find.text('fcm refused a message: 404'), findsOneWidget);
      expect(find.textContaining('×3'), findsOneWidget, reason: 'said three times in that minute');
      expect(find.textContaining('5 min ago'), findsWidgets);
      expect(find.text('3 lines kept, for two weeks'), findsOneWidget);
      expect(tester.getTopLeft(find.text('tp sync failed')).dy < tester.getTopLeft(find.text('read 28000 prices')).dy, isTrue);
    });

    testWidgets('begins with the newest page of all of them, and nothing is asked twice for it', (tester) async {
      final backend = await open(tester, FakeBackend(logsOf: (q) => _page(lines)));
      expect(backend.logQueries.first, noLogQuery);
      expect(backend.logQueries.toSet().length, 1, reason: 'the page of the lines and the page for the chips are the same page');
    });

    testWidgets('opens a line to what it knew, which can be copied', (tester) async {
      await open(tester, FakeBackend(logsOf: (q) => _page(lines)));
      expect(find.text('Tap for what it knew'), findsOneWidget, reason: 'only the line that knew something');
      expect(find.textContaining('"status": 503'), findsNothing);
      await tester.tap(find.text('tp sync failed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"status": 503'), findsOneWidget);
      expect(find.textContaining('"repeats"'), findsNothing, reason: 'the count is not something it knew');
      await tester.tap(find.text('tp sync failed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"status": 503'), findsNothing, reason: 'closed again');
    });

    testWidgets('copies a line, with when, how serious, who, what and what it knew', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester, FakeBackend(logsOf: (q) => _page(lines)));
      await tester.tap(find.byTooltip('Copy').first);
      await tester.pump();
      expect(copied, contains('error tp-sync: tp sync failed'));
      expect(copied, contains('(x3)'));
      expect(copied, contains('"status": 503'));
    });

    testWidgets('has a chip for each function that did anything, with its errors, and one for all', (tester) async {
      await open(tester, FakeBackend(logsOf: (q) => _page(lines)));
      expect(find.text('All functions'), findsOneWidget);
      expect(find.text('tp-sync · 2'), findsOneWidget, reason: 'two errors in the last day');
      expect(find.text('push-sync'), findsOneWidget, reason: 'no errors, only the name');
    });

    testWidgets('asks for the lines of one function when its chip is chosen, and for all when all is', (tester) async {
      final backend = await open(tester, FakeBackend(logsOf: (q) => _page(lines)));
      await tester.tap(find.text('tp-sync · 2'));
      await tester.pumpAndSettle();
      expect(backend.logQueries.last, (fn: 'tp-sync', level: null, search: '', before: null));
      await tester.tap(find.text('All functions'));
      await tester.pumpAndSettle();
      expect(backend.logQueries.last.fn, isNull);
    });

    testWidgets('asks for one level, and for all of them again', (tester) async {
      final backend = await open(tester, FakeBackend(logsOf: (q) => _page(lines)));
      await tester.tap(find.text('Errors'));
      await tester.pumpAndSettle();
      expect(backend.logQueries.last.level, LogLevel.error);
      await tester.tap(find.text('Warnings'));
      await tester.pumpAndSettle();
      expect(backend.logQueries.last.level, LogLevel.warn);
      await tester.tap(find.text('All levels'));
      await tester.pumpAndSettle();
      expect(backend.logQueries.last.level, isNull);
    });

    testWidgets('searches for a text, trimmed, and clears the search', (tester) async {
      final backend = await open(tester, FakeBackend(logsOf: (q) => _page(lines)));
      await tester.enterText(find.byKey(const Key('log-search')), '  fcm  ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(backend.logQueries.last.search, 'fcm');
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(backend.logQueries.last.search, '');
    });

    testWidgets('keeps the function it was opened from, and shows its chip even when it has said nothing lately', (tester) async {
      final backend = await open(tester, FakeBackend(logsOf: (q) => _page(lines, functions: [])), fn: 'quiet-one');
      expect(backend.logQueries.first.fn, 'quiet-one');
      expect(find.text('quiet-one'), findsOneWidget);
    });

    testWidgets('says so when nothing has been said, with the chips still there to get out of it', (tester) async {
      await open(tester, FakeBackend(logsOf: (q) => _page([], total: 0)));
      expect(find.text('Nothing like that has been said.'), findsOneWidget);
      expect(find.text('All levels'), findsOneWidget);
    });

    testWidgets('asks for the older lines after the oldest it has, and puts them under the newer ones', (tester) async {
      final newest = [for (var i = 200; i > 150; i--) _line(i, 'tp-sync', 'info', 'line $i')];
      final backend = await open(
        tester,
        FakeBackend(logsOf: (q) => q.before == null ? _page(newest, total: 80) : _page([_line(149, 'tp-sync', 'info', 'line 149')], total: 80)),
      );
      expect(find.text('Older'), findsOneWidget, reason: 'a full page');
      await tester.ensureVisible(find.text('Older'));
      await tester.tap(find.text('Older'));
      await tester.pumpAndSettle();
      expect(backend.logQueries.any((q) => q.before == 151), isTrue, reason: 'after the oldest of the page it has');
      expect(find.text('line 149'), findsOneWidget);
      expect(find.text('line 200'), findsOneWidget, reason: 'the newer ones are still there');
      expect(find.text('Older'), findsNothing, reason: 'the last page was not full');
    });

    testWidgets('begins again at the newest when a filter is changed', (tester) async {
      final newest = [for (var i = 200; i > 150; i--) _line(i, 'tp-sync', 'info', 'line $i')];
      final backend = await open(tester, FakeBackend(logsOf: (q) => q.before == null ? _page(newest) : _page([_line(149, 'tp-sync', 'info', 'line 149')])));
      await tester.ensureVisible(find.text('Older'));
      await tester.tap(find.text('Older'));
      await tester.pumpAndSettle();
      expect(find.text('line 149'), findsOneWidget);
      await tester.tap(find.text('Errors'));
      await tester.pumpAndSettle();
      expect(find.text('line 149'), findsNothing, reason: 'the older page belonged to the other filter');
      expect(backend.logQueries.last, (fn: null, level: LogLevel.error, search: '', before: null));
    });

    testWidgets('says when the logs cannot be read, and tries again when asked', (tester) async {
      final backend = await open(tester, FakeBackend(failWith: Exception('no network')));
      expect(find.textContaining('The logs could not be read'), findsWidgets);
      final before = backend.logQueries.length;
      await tester.tap(find.text('Try again').first);
      await tester.pumpAndSettle();
      expect(backend.logQueries.length > before, isTrue);
    });
  });

  group('the logs in the system tab', () {
    Future<FakeBackend> show(WidgetTester tester, FakeBackend backend) async {
      tester.view.physicalSize = const Size(1800, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          adminBackendProvider.overrideWithValue(backend),
          adminPollEveryProvider.overrideWithValue(Duration.zero),
          adminSystemProvider.overrideWith((ref) async => AdminSystem({'generated_at': DateTime.now().toUtc().toIso8601String()})),
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

    testWidgets('says how each function did in the last day and how many lines there are', (tester) async {
      await show(tester, FakeBackend(logsOf: (q) => _page(lines(), total: 42)));
      expect(find.text('EDGE FUNCTION LOGS'), findsOneWidget);
      expect(find.text('tp-sync'), findsOneWidget);
      expect(find.textContaining('2 errors'), findsOneWidget);
      expect(find.textContaining('1 warning'), findsOneWidget);
      expect(find.text('All logs (42)'), findsOneWidget);
    });

    testWidgets('opens the lines of a function from its line, and all of them from the button', (tester) async {
      final backend = await show(tester, FakeBackend(logsOf: (q) => _page(lines())));
      await tester.tap(find.text('tp-sync'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminLogsScreen), findsOneWidget);
      expect(backend.logQueries.last.fn, 'tp-sync');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('All logs (3)'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminLogsScreen), findsOneWidget);
      expect(backend.logQueries.last.fn, isNull);
    });

    testWidgets('says so when nothing was said in the last day', (tester) async {
      await show(tester, FakeBackend(logsOf: (q) => _page([], functions: [])));
      expect(find.text('Nothing has been said in the last day.'), findsOneWidget);
      expect(find.text('All logs (0)'), findsOneWidget);
    });

    testWidgets('says that the logs cannot be read, an old backend has none, and the rest of the tab is there all the same', (tester) async {
      await show(tester, FakeBackend(failWith: Exception('function does not exist')));
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.text('RUN BY HAND'), findsOneWidget);
    });
  });
}

List<Map<String, dynamic>> lines() => [
      _line(30, 'tp-sync', 'error', 'tp sync failed'),
      _line(20, 'push-sync', 'warn', 'fcm refused a message: 404'),
      _line(10, 'tp-sync', 'info', 'read 28000 prices'),
    ];
