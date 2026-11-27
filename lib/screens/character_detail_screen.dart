import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/characters.dart';
import '../state/crafting.dart';
import '../state/items.dart';
import '../state/professions.dart';
import '../state/pvp.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/build_view.dart';
import '../widgets/class_icon.dart';
import '../widgets/birthday.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/recipe_outputs.dart';
import 'character_progress.dart';
import 'compare_screen.dart';
import 'hero_card_screen.dart';
import 'item_detail_screen.dart';
import 'item_sheet.dart';

part 'character_detail/site_page.dart';
part 'character_detail/tabs.dart';

const _slotOrder = [
  'Helm', 'Shoulders', 'Coat', 'Gloves', 'Leggings', 'Boots', //
  'WeaponA1', 'WeaponA2', 'WeaponB1', 'WeaponB2', //
  'Backpack', 'Accessory1', 'Accessory2', 'Amulet', 'Ring1', 'Ring2', 'Relic', //
  'HelmAquatic', 'WeaponAquaticA', 'WeaponAquaticB', 'Sickle', 'Axe', 'Pick', //
  'PowerCore', 'SensoryArray', 'ServiceChip', 'FishingRod', 'FishingBait', 'FishingLure',
];

/// a slot's name in the app's language. a slot the tables do not know yet,
/// from a newer release, reads as its api name split into words
String slotLabel(S s, String slot) {
  final key = 'slot_$slot';
  final text = s.t(key);
  return text == key ? slot.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m[1]}') : text;
}

int _slotIndex(String slot) {
  final i = _slotOrder.indexOf(slot);
  return i < 0 ? 999 : i;
}

class CharacterDetailScreen extends ConsumerWidget {
  const CharacterDetailScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final chars = ref.watch(charactersProvider);
    final list = chars.valueOrNull;
    final c = list == null ? null : characterByName(list, name);

    Widget body;
    if (c != null) {
      body = Column(
        children: [
          _Hero(c),
          AppTabBar(
            scrollable: true,
            labels: [s.t('equipment'), s.t('build'), s.t('inventory'), s.t('crafting'), s.t('progress')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _EquipmentTab(c),
                _BuildTab(c),
                _InventoryTab(c),
                _CraftingTab(c),
                CharacterProgressTab(name: '${c['name']}', profession: '${c['profession'] ?? ''}'),
              ],
            ),
          ),
        ],
      );
    } else if (chars.hasError) {
      body = Padding(
        padding: const EdgeInsets.all(20),
        child: ErrorBox(error: chars.error, onRetry: () => ref.invalidate(charactersProvider)),
      );
    } else if (list != null) {
      body = Center(child: Text(s.t('character_not_found'), style: TextStyle(color: AppColors.muted)));
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        // the character's own dark header, the bar is part of it: the name is large in it, under the bar
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.header,
          foregroundColor: AppColors.onHeader,
          iconTheme: IconThemeData(color: AppColors.onHeader),
          title: c == null ? Text(name) : null,
          actions: [
            if (c != null)
              IconButton(
                tooltip: s.t('compare'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => CompareScreen(first: name)),
                ),
                icon: Icon(Icons.compare_arrows, color: AppColors.accent),
              ),
            if (c != null)
              IconButton(
                tooltip: s.t('hero_card'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => HeroCardScreen(name: name)),
                ),
                icon: Icon(Icons.ios_share, color: AppColors.accent),
              ),
          ],
        ),
        body: body,
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final prof = '${c['profession'] ?? ''}';
    final color = professionColor(prof);
    final info = ref.watch(professionsProvider).valueOrNull?[prof];
    final elite = activeElite(c, info)?['name'] as String?;
    final profName = info?.name ?? prof;
    final race = ref.watch(racesProvider).valueOrNull?['${c['race']}'] ?? '${c['race'] ?? ''}';
    final light = AppColors.onHeader;
    return Container(
      color: AppColors.header,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          ClassIcon(character: c, size: 64, fallback: Icon(Icons.shield_outlined, color: color, size: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${elite == null ? profName : '$elite · $profName'} · ${s.t('level_n', {'n': asInt(c['level'])})}'
                      .caps,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.accent),
                ),
                const SizedBox(height: 2),
                Text('${c['name'] ?? ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: display(26, color: const Color(0xFFFFF8E6))),
                const SizedBox(height: 4),
                Text(
                  [
                    race,
                    fmtHours(c['age'], s.t('hours_short')),
                    s.t('deaths_n', {'n': fmtInt(asInt(c['deaths']))}),
                  ].join(' · '),
                  style: TextStyle(fontSize: 13, color: light),
                ),
                const SizedBox(height: 2),
                DefaultTextStyle.merge(
                    style: TextStyle(color: light), child: BirthdayLine(created: c['created'] as String?)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
