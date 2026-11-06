import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/item_index.dart';
import '../util.dart';
import 'alerts.dart';
import 'community.dart';

/// an alert as the server keeps it: the item, what it is called in the notification, and its two prices in copper
class ServerAlert {
  const ServerAlert({required this.itemId, required this.name, this.sellBelow, this.buyAbove});

  final int itemId;
  final String name;
  final int? sellBelow;
  final int? buyAbove;

  static ServerAlert? parse(dynamic raw) {
    if (raw is! Map || raw['item_id'] == null) return null;
    return ServerAlert(
      itemId: asInt(raw['item_id']),
      name: '${raw['name'] ?? ''}',
      sellBelow: raw['sell_below'] == null ? null : asInt(raw['sell_below']),
      buyAbove: raw['buy_above'] == null ? null : asInt(raw['buy_above']),
    );
  }
}

/// which of the alerts on the device the server is to be told of: those it has not, and those it has with other prices. never the ones it has as they are,
/// since telling the server of an alert makes it ready to be sent again, and one that was sent would be sent anew. what the server has and the device has not is left,
/// it may be another device's
List<int> alertsToSend(Map<int, PriceAlert> local, List<ServerAlert> remote) {
  final known = {for (final r in remote) r.itemId: r};
  return [
    for (final e in local.entries)
      if (!e.value.isEmpty &&
          (known[e.key] == null ||
              known[e.key]!.sellBelow != e.value.sellBelow ||
              known[e.key]!.buyAbove != e.value.buyAbove))
        e.key,
  ];
}

/// what the app asks of the server for its price alerts
abstract class PriceAlertBackend {
  Future<List<ServerAlert>> fetch();

  /// makes the alert, or with none (or one with no price) takes it away
  Future<void> send(int itemId, String name, PriceAlert? alert);
}

class SupabasePriceAlertBackend implements PriceAlertBackend {
  const SupabasePriceAlertBackend();

  /// the client, when somebody is signed in
  SupabaseClient? get _client {
    try {
      final client = Supabase.instance.client;
      return client.auth.currentSession == null ? null : client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ServerAlert>> fetch() async {
    final client = _client;
    if (client == null) return const [];
    final raw = await client.rpc('my_price_alerts');
    return [
      for (final a in (raw as List? ?? const []))
        if (ServerAlert.parse(a) case final alert?) alert,
    ];
  }

  @override
  Future<void> send(int itemId, String name, PriceAlert? alert) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'set_price_alert',
      params: {'p_item': itemId, 'p_name': name, 'p_sell_below': alert?.sellBelow, 'p_buy_above': alert?.buyAbove},
    );
  }
}

final priceAlertBackendProvider = Provider<PriceAlertBackend>((ref) => const SupabasePriceAlertBackend());

/// keeps the server's alerts as the ones on the device are, so that a notification comes when the app is shut. the server is a help and never a need: what could not
/// be told is left, and the alert on the device works as it did
class PriceAlertMirror {
  const PriceAlertMirror(this.backend);

  final PriceAlertBackend backend;

  /// an alert that was set, changed or taken away on this device
  Future<void> mirror(int itemId, String name, PriceAlert? alert) async {
    try {
      await backend.send(itemId, name, alert);
    } catch (_) {
      // the server cannot be reached: the next time the app is opened it is told
    }
  }

  /// the alerts of the device that the server does not have as they are
  Future<void> syncAll(Map<int, PriceAlert> local, String Function(int itemId) nameOf) async {
    try {
      final remote = await backend.fetch();
      for (final id in alertsToSend(local, remote)) {
        await backend.send(id, nameOf(id), local[id]);
      }
    } catch (_) {
      // as above
    }
  }
}

final priceAlertMirrorProvider = Provider<PriceAlertMirror>(
  (ref) => PriceAlertMirror(ref.watch(priceAlertBackendProvider)),
);

/// the alerts of the device are told to the server once a session, when somebody is signed in. the names are those of the item index
final priceAlertSyncProvider = FutureProvider<void>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return;
  final local = ref.read(priceAlertsProvider);
  if (local.isEmpty) return;
  ItemIndex? index;
  try {
    index = await ref.read(itemIndexProvider.future);
  } catch (_) {
    // a name is only for the notification: the number of the item stands in
  }
  await ref.read(priceAlertMirrorProvider).syncAll(local, (id) => index?.nameOf(id) ?? '');
});
