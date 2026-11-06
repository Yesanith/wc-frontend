import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wondrous_compass/state/open_events.dart';
import 'package:wondrous_compass/state/settings.dart';

Future<ProviderContainer> _container([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hidden organizers', () {
    test('start empty', () async {
      final c = await _container();
      expect(c.read(hiddenOrganizersProvider), isEmpty);
    });

    test('are remembered between visits', () async {
      final c = await _container();
      c.read(hiddenOrganizersProvider.notifier).hide('Leo.1234');
      c.read(hiddenOrganizersProvider.notifier).hide('Ria.5678');
      expect(c.read(hiddenOrganizersProvider), {'Leo.1234', 'Ria.5678'});

      final prefs = c.read(prefsProvider);
      final again = await _container({'oe_hidden_organizers': prefs.getStringList('oe_hidden_organizers')!});
      expect(again.read(hiddenOrganizersProvider), {'Leo.1234', 'Ria.5678'});
    });

    test('can be shown again', () async {
      final c = await _container({
        'oe_hidden_organizers': ['Leo.1234', 'Ria.5678']
      });
      c.read(hiddenOrganizersProvider.notifier).show('Leo.1234');
      expect(c.read(hiddenOrganizersProvider), {'Ria.5678'});
      expect(c.read(prefsProvider).getStringList('oe_hidden_organizers'), ['Ria.5678']);
    });

    test('hiding the same organizer twice keeps one', () async {
      final c = await _container();
      c.read(hiddenOrganizersProvider.notifier).hide('Leo.1234');
      c.read(hiddenOrganizersProvider.notifier).hide('Leo.1234');
      expect(c.read(prefsProvider).getStringList('oe_hidden_organizers'), ['Leo.1234']);
    });
  });
}
