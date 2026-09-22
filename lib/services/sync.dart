import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gw2_api.dart';
import '../state/api.dart';
import '../util.dart';

/// one account endpoint, keyed exactly the way Gw2Api.cachedGet keys it, so
/// warming it here is what the normal api methods read back later
class _Endpoint {
  const _Endpoint(this.path, [this.query]);

  final String path;
  final Map<String, String>? query;
}

/// everything the account screens read. static game data is left out, it
/// already lives on disk for a month
const _endpoints = <_Endpoint>[
  _Endpoint('/account'),
  _Endpoint('/characters', {'ids': 'all'}),
  _Endpoint('/account/wallet'),
  _Endpoint('/account/materials'),
  _Endpoint('/account/bank'),
  _Endpoint('/account/achievements'),
  _Endpoint('/account/masteries'),
  _Endpoint('/account/mastery/points'),
  _Endpoint('/account/legendaryarmory'),
  _Endpoint('/account/buildstorage'),
  _Endpoint('/account/raids'),
  _Endpoint('/account/dungeons'),
  _Endpoint('/account/dailycrafting'),
  _Endpoint('/account/mapchests'),
  _Endpoint('/account/worldbosses'),
  _Endpoint('/account/wizardsvault/daily'),
  _Endpoint('/account/wizardsvault/weekly'),
  _Endpoint('/account/wizardsvault/special'),
  _Endpoint('/pvp/stats'),
];

/// how many requests are in flight at once. the api allows far more, this is
/// just enough to finish quickly without a burst
const _lanes = 4;

class SyncState {
  const SyncState({
    this.done = 0,
    this.total = 0,
    this.failed = 0,
    this.running = false,
    this.finishedAt,
  });

  final int done;
  final int total;

  /// endpoints that errored. a partial sync is still useful, the screens
  /// fall back to the api for whatever is missing
  final int failed;
  final bool running;
  final DateTime? finishedAt;

  double get ratio => total == 0 ? 0 : done / total;
  bool get everRan => finishedAt != null;
}

/// pulls the whole account down in one go and leaves it on disk, so opening
/// a section reads from the cache instead of waiting on the api
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  Future<void> run() async {
    if (state.running) return;
    final api = ref.read(gw2ApiProvider);
    if ((api.apiKey ?? '').isEmpty) return;

    final queue = [..._endpoints];
    var done = 0;
    var failed = 0;
    state = SyncState(running: true, total: queue.length);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final next = queue.removeAt(0);
        try {
          await api.cachedGet(next.path, query: next.query, force: true);
        } catch (_) {
          failed++;
        }
        done++;
        state = SyncState(running: true, total: state.total, done: done, failed: failed);
      }
    }

    await Future.wait([for (var i = 0; i < _lanes; i++) worker()]);

    // guilds are only known once the account came back
    final guilds = await _guildIds(api);
    if (guilds.isNotEmpty) {
      final extra = [
        for (final id in guilds) ...[
          _Endpoint('/guild/$id'),
          _Endpoint('/guild/$id/treasury'),
          _Endpoint('/guild/$id/stash'),
          _Endpoint('/guild/$id/log'),
        ],
      ];
      state = SyncState(
        running: true,
        total: state.total + extra.length,
        done: done,
        failed: failed,
      );
      for (final e in extra) {
        try {
          await api.cachedGet(e.path, query: e.query, force: true);
        } catch (_) {
          // guild detail needs the account to lead the guild, a refusal here
          // is normal and not worth counting as a failure
        }
        done++;
        state = SyncState(running: true, total: state.total, done: done, failed: failed);
      }
    }

    state = SyncState(
      total: state.total,
      done: done,
      failed: failed,
      finishedAt: DateTime.now(),
    );
  }

  Future<List<String>> _guildIds(Gw2Api api) async {
    try {
      final account = await api.cachedGet('/account') as Json;
      return [for (final g in (account['guilds'] as List?) ?? const []) '$g'];
    } catch (_) {
      return const [];
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
