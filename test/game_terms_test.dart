import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/widgets/common.dart';

/// the terms the api gives in english are shown in the language of the app, and one without words keeps its own
void main() {
  test('rarities, weapons and the guild log are said in the language of the app', () {
    expect(rarityLabel(const S(AppLang.tr), 'Exotic'), 'Egzotik');
    expect(rarityLabel(const S(AppLang.de), 'Legendary'), 'Legendär');
    expect(weaponLabel(const S(AppLang.fr), 'LongBow'), 'Arc long', reason: 'the item type of a longbow is LongBow');
    expect(weaponLabel(const S(AppLang.de), 'Harpoon'), 'Speer', reason: 'and a spear is a Harpoon');
    expect(guildLogLabel(const S(AppLang.tr), 'rank_change'), 'Rütbe değişti');
    expect(guildUpgradeTypeLabel(const S(AppLang.es), 'GuildHall'), 'Sala del gremio');
  });

  test('a term without words is spelled as the api spells it, with spaces', () {
    expect(weaponLabel(const S(AppLang.en), 'HelmAquatic'), 'Helm Aquatic');
    expect(guildLogLabel(const S(AppLang.en), 'something_new'), 'Something new');
    expect(guildUpgradeTypeLabel(const S(AppLang.en), 'NewKind'), 'New Kind');
  });
}
