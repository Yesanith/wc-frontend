import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/data/metas.dart';
import 'package:wondrous_compass/state/hidden_timers.dart';

class _Hidden extends HiddenTimers {
  _Hidden(this.ids);
  final Set<String> ids;
  @override
  Future<Set<String>> build() async => ids;
}

void main() {
  test(
      'the fractal incursions are a timer of their own, the one the administrator hides when the game stops holding them',
      () {
    expect(metaMaps.where((m) => m.id == 'incursion'), hasLength(1));
  });

  test('a hidden timer is off the list and its pins have no alerts, every other one stays', () async {
    final c = ProviderContainer(overrides: [
      hiddenTimersProvider.overrideWith(() => _Hidden({'incursion'}))
    ]);
    addTearDown(c.dispose);
    await c.read(hiddenTimersProvider.future);
    final shown = c.read(shownMetaMapsProvider);
    expect(shown.any((m) => m.id == 'incursion'), isFalse);
    expect(shown, hasLength(metaMaps.length - 1));
    expect(c.read(hiddenEventKeysProvider), hasLength(4));
    expect(
        occurrences(DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 2), maps: shown)
            .any((o) => o.map.id == 'incursion'),
        isFalse);
  });

  test('with nothing hidden every timer shows', () async {
    final c = ProviderContainer(overrides: [hiddenTimersProvider.overrideWith(() => _Hidden({}))]);
    addTearDown(c.dispose);
    await c.read(hiddenTimersProvider.future);
    expect(c.read(shownMetaMapsProvider), same(metaMaps));
    expect(c.read(hiddenEventKeysProvider), isEmpty);
  });
}
