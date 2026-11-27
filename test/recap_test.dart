import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wondrous_compass/state/settings.dart';
import 'package:wondrous_compass/theme.dart';
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/screens/recap_screen.dart';
import 'package:wondrous_compass/state/recap.dart';
import 'package:wondrous_compass/state/wealth.dart';

void main() {
  final from = DateTime(2026), to = DateTime(2027);

  test('the span starts from the last snapshot before it', () {
    final w = wealthSpan([
      const WealthPoint('2025-12-30', 100, 0, 0),
      const WealthPoint('2026-03-01', 500, 0, 0),
      const WealthPoint('2026-11-27', 900, 0, 0),
      const WealthPoint('2027-01-02', 2000, 0, 0),
    ], from, to)!;
    expect(w.whole, isTrue);
    expect(w.first.coins, 100);
    expect(w.last.coins, 900);
  });

  test('a younger history starts from its first snapshot in the span', () {
    final w = wealthSpan([
      const WealthPoint('2026-06-01', 500, 0, 0),
      const WealthPoint('2026-11-27', 900, 0, 0),
    ], from, to)!;
    expect(w.whole, isFalse);
    expect(w.first.day, '2026-06-01');
  });

  test('a single snapshot is no span', () {
    expect(wealthSpan([const WealthPoint('2026-06-01', 500, 0, 0)], from, to), isNull);
    expect(wealthSpan([], from, to), isNull);
  });

  test('the trading post counts what was sold in the span', () {
    final t = tradeRecap(
      [
        {'purchased': '2026-05-01T10:00:00Z', 'price': 100, 'quantity': 3},
        {'purchased': '2025-12-01T10:00:00Z', 'price': 999, 'quantity': 1},
      ],
      [
        {'purchased': '2026-05-02T10:00:00Z', 'price': 50, 'quantity': 2},
      ],
      from.toUtc(),
      to.toUtc(),
    );
    expect(t.sold, 3);
    expect(t.soldCoins, 300);
    expect(t.bought, 2);
    expect(t.boughtCoins, 100);
  });

  test('the season takes the dates the game gives', () {
    final now = DateTime(2026, 11, 27);
    expect(recapDates(RecapSpan.year, now, null), (DateTime(2026), DateTime(2027)));
    final season = recapDates(RecapSpan.season, now, {'start': '2026-10-01T17:00:00Z', 'end': '2027-01-14T17:00:00Z'});
    expect(season, isNotNull);
    expect(recapDates(RecapSpan.season, now, {'title': 'x'}), isNull);
  });

  test('the guild part reads the server', () {
    final g = parseGuildRecap({'events': 12, 'hours': 18.5, 'guilds': 2, 'top_activity': 'raid', 'hosted': 3})!;
    expect(g.events, 12);
    expect(g.hours, 18.5);
    expect(g.topActivity, 'raid');
    expect(parseGuildRecap(null), isNull);
  });

  test('the notes say what is counted from less', () {
    const s = S(AppLang.en);
    final r = Recap(
      span: RecapSpan.year,
      from: from,
      to: to,
      wealth: const WealthSpan(WealthPoint('2026-06-01', 1, 0, 0), WealthPoint('2026-11-27', 2, 0, 0), whole: false),
    );
    final notes = recapNotes(s, r);
    expect(notes, hasLength(2));
    expect(notes.first, contains('since'));
  });

  test('the played time is kept with the snapshot, and older ones read without it', () {
    final p = WealthPoint.fromJson(const WealthPoint('2026-11-27', 1, 2, 3, age: 3600).toJson());
    expect(p.age, 3600);
    expect(WealthPoint.fromJson({'d': '2026-01-01', 'c': 1, 'k': 0, 'g': 0}).age, 0);
  });

  testWidgets('the card fits a phone with every part', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = Recap(
      span: RecapSpan.season,
      from: DateTime(2026, 10),
      to: DateTime(2027, 1, 14),
      title: 'Season of the very long and winding name of the vault',
      account: 'Leo.1234',
      wealth: const WealthSpan(
          WealthPoint('2026-10-01', 10000000, 5, 0), WealthPoint('2026-11-27', 34560000, 900000, 0),
          whole: true),
      play: const WealthSpan(
          WealthPoint('2026-10-01', 0, 0, 0, age: 3600), WealthPoint('2026-11-27', 0, 0, 0, age: 400000),
          whole: true),
      trade: const TradeRecap(1234, 98760000, 10, 100),
      guild: const GuildRecap(42, 63.5, 2, 'raid', 7),
      signedIn: true,
      specialDone: 12,
      specialTotal: 20,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: RecapCard(recap: r))),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('+2,456g'), findsOneWidget);
    expect(find.text('Most played: Raid'), findsOneWidget);
  });
}
