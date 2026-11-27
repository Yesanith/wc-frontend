import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';
import 'account.dart';
import 'community.dart';
import 'trading.dart';
import 'vault.dart';
import 'wealth.dart';

/// the span a recap is about: the calendar year, or the running season of the wizard's vault
enum RecapSpan { year, season }

/// what the guild events of the span came to, as the server keeps them
class GuildRecap {
  const GuildRecap(this.events, this.hours, this.guilds, this.topActivity, this.hosted);

  final int events;
  final double hours;
  final int guilds;
  final String? topActivity;
  final int hosted;
}

GuildRecap? parseGuildRecap(dynamic raw) {
  if (raw is! Map) return null;
  final hours = raw['hours'];
  return GuildRecap(
    asInt(raw['events']),
    hours is num ? hours.toDouble() : double.tryParse('$hours') ?? 0,
    asInt(raw['guilds']),
    raw['top_activity'] == null ? null : '${raw['top_activity']}',
    asInt(raw['hosted']),
  );
}

/// the first and the last snapshot of the span. the first is the last one taken before the span began, or the first one in it when
/// the history is younger than the span, and [whole] says which
class WealthSpan {
  const WealthSpan(this.first, this.last, {required this.whole});

  final WealthPoint first;
  final WealthPoint last;
  final bool whole;
}

/// null without two snapshots in the span
WealthSpan? wealthSpan(List<WealthPoint> points, DateTime from, DateTime to) {
  final start = dayKey(from), end = dayKey(to);
  WealthPoint? before, first, last;
  for (final p in points) {
    if (p.day.compareTo(start) <= 0) {
      before = p;
    } else if (p.day.compareTo(end) < 0) {
      first ??= p;
    }
    if (p.day.compareTo(end) < 0) last = p;
  }
  final base = before ?? first;
  if (base == null || last == null || identical(base, last)) return null;
  return WealthSpan(base, last, whole: before != null);
}

/// what the trading post sold or bought in the span, at the price of each sale
class TradeRecap {
  const TradeRecap(this.sold, this.soldCoins, this.bought, this.boughtCoins);

  final int sold;
  final int soldCoins;
  final int bought;
  final int boughtCoins;
}

TradeRecap tradeRecap(List<Json> sells, List<Json> buys, DateTime from, DateTime to) {
  (int, int) sum(List<Json> txs) {
    var n = 0, coins = 0;
    for (final t in txs) {
      final at = DateTime.tryParse('${t['purchased'] ?? ''}');
      if (at == null || at.isBefore(from) || !at.isBefore(to)) continue;
      final q = asInt(t['quantity']);
      n += q;
      coins += asInt(t['price']) * q;
    }
    return (n, coins);
  }

  final (sold, soldCoins) = sum(sells);
  final (bought, boughtCoins) = sum(buys);
  return TradeRecap(sold, soldCoins, bought, boughtCoins);
}

/// the game keeps the trading post's history of the last 90 days
const tradeHistoryDays = 90;

class Recap {
  const Recap({
    required this.span,
    required this.from,
    required this.to,
    this.title,
    this.account,
    this.wealth,
    this.play,
    this.trade,
    this.tradePartial = false,
    this.guild,
    this.signedIn = false,
    this.specialDone,
    this.specialTotal,
  });

  final RecapSpan span;
  final DateTime from;
  final DateTime to;

  /// the season's name, for a season
  final String? title;
  final String? account;

  /// the wallet's first and last snapshot of the span
  final WealthSpan? wealth;

  /// the same for the hours played, from the snapshots that have them
  final WealthSpan? play;
  final TradeRecap? trade;

  /// the span began before the trading post's history does
  final bool tradePartial;
  final GuildRecap? guild;

  /// the guild events are counted only for who is signed in
  final bool signedIn;

  /// the season's special objectives done, for a season
  final int? specialDone;
  final int? specialTotal;

  int? get coins => wealth == null ? null : wealth!.last.coins - wealth!.first.coins;
  int? get karma => wealth == null ? null : wealth!.last.karma - wealth!.first.karma;
  int? get playHours => play == null ? null : (play!.last.age - play!.first.age) ~/ 3600;
}

/// the span of a recap: the calendar year, or the season as the game gives its dates
(DateTime, DateTime)? recapDates(RecapSpan span, DateTime now, Json? season) {
  if (span == RecapSpan.year) return (DateTime(now.year), DateTime(now.year + 1));
  final from = DateTime.tryParse('${season?['start'] ?? ''}')?.toLocal();
  final to = DateTime.tryParse('${season?['end'] ?? ''}')?.toLocal();
  if (from == null || to == null || !to.isAfter(from)) return null;
  return (from, to);
}

/// the recap of the account, each part left out when what it needs could not be read
final recapProvider = FutureProvider.autoDispose.family<Recap?, RecapSpan>((ref, span) async {
  final now = DateTime.now();
  final season = span == RecapSpan.season ? await ref.watch(vaultSeasonProvider.future) : null;
  final dates = recapDates(span, now, season);
  if (dates == null) return null;
  final (from, to) = dates;
  final account = await ref.watch(accountProvider.future).then<Json?>((a) => a, onError: (_) => null);
  final name = account?['name'] == null ? null : '${account!['name']}';
  final points = name == null ? const <WealthPoint>[] : ref.watch(wealthProvider)[name] ?? const <WealthPoint>[];

  TradeRecap? trade;
  try {
    final sells = await ref.watch(transactionsProvider('history/sells').future);
    final buys = await ref.watch(transactionsProvider('history/buys').future);
    trade = tradeRecap([for (final r in sells) r.tx], [for (final r in buys) r.tx], from, to);
  } catch (_) {}

  GuildRecap? guild;
  final signedIn = communityReady && Supabase.instance.client.auth.currentUser != null;
  if (signedIn) {
    try {
      guild = parseGuildRecap(await Supabase.instance.client.rpc('my_recap', params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      }));
    } catch (_) {}
  }

  int? done, total;
  if (span == RecapSpan.season) {
    try {
      final special = await ref.watch(vaultTrackProvider('special').future);
      final objectives = [
        for (final o in (special['objectives'] as List?) ?? const [])
          if (o is Map) o
      ];
      total = objectives.length;
      done = objectives
          .where(
              (o) => asInt(o['progress_complete']) > 0 && asInt(o['progress_current']) >= asInt(o['progress_complete']))
          .length;
    } catch (_) {}
  }

  return Recap(
    span: span,
    from: from,
    to: to,
    title: season?['title'] == null ? null : '${season!['title']}',
    account: name,
    wealth: wealthSpan(points, from, to),
    play: wealthSpan([
      for (final p in points)
        if (p.age > 0) p
    ], from, to),
    trade: trade,
    tradePartial: from.isBefore(now.subtract(const Duration(days: tradeHistoryDays))),
    guild: guild,
    signedIn: signedIn,
    specialDone: done,
    specialTotal: total,
  );
});
