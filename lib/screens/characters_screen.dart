import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/characters.dart';
import '../state/professions.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../services/icon_cache.dart';
import '../util.dart';
import '../widgets/class_icon.dart';
import '../widgets/birthday.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'character_detail_screen.dart';

class CharactersScreen extends ConsumerStatefulWidget {
  const CharactersScreen({super.key});

  @override
  ConsumerState<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends ConsumerState<CharactersScreen> {
  String _query = '';

  bool _matches(Json c) {
    if (_query.isEmpty) return true;
    final info = ref.read(professionsProvider).valueOrNull?[c['profession']];
    final race = ref.read(racesProvider).valueOrNull?['${c['race']}'] ?? '';
    final hay = '${c['name']} ${c['profession']} ${c['race']} ${info?.name ?? ''} $race'.toLowerCase();
    return hay.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final open = ref.watch(openCharacterProvider);
    if (open != null && SiteScope.of(context)) {
      return CharacterSitePage(name: open, onBack: () => ref.read(openCharacterProvider.notifier).state = null);
    }
    final chars = ref.watch(charactersProvider);
    final count = chars.valueOrNull?.length;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [charactersProvider]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (count != null)
                Text(s.t('n_characters', {'n': count}),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: fieldDecoration(
              s.t('search_characters'),
              prefixIcon: Icon(Icons.search, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final sort in CharacterSort.values) ...[
                  ChoiceChip(
                    label: Text(s.t('sort_${sort.name}')),
                    selected: ref.watch(characterSortProvider) == sort,
                    onSelected: (_) => ref.read(characterSortProvider.notifier).set(sort),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          AsyncView<List<Json>>(
            value: chars,
            onRetry: () => ref.invalidate(charactersProvider),
            builder: (list) {
              final favorites = ref.watch(favoriteCharactersProvider);
              final sort = ref.watch(characterSortProvider);
              final filtered = list.where(_matches).toList();
              filtered.sort((a, b) {
                // favourites always float to the top
                final favA = favorites.contains('${a['name']}');
                final favB = favorites.contains('${b['name']}');
                if (favA != favB) return favA ? -1 : 1;
                switch (sort) {
                  case CharacterSort.name:
                    return '${a['name']}'.compareTo('${b['name']}');
                  case CharacterSort.level:
                    return asInt(b['level']).compareTo(asInt(a['level']));
                  case CharacterSort.playtime:
                    return asInt(b['age']).compareTo(asInt(a['age']));
                  case CharacterSort.lastPlayed:
                    return '${b['last_modified'] ?? ''}'.compareTo('${a['last_modified'] ?? ''}');
                }
              });
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyNote(s.t('no_match')),
                );
              }
              // one under the other on a phone, side by side where there is room
              // on a site the characters are a gallery: each has the art of its elite line over it, where a phone has a row
              if (SiteScope.of(context)) {
                return CardWrap(minWidth: 280, gap: 18, children: [for (final c in filtered) _GalleryCard(c)]);
              }
              return CardWrap(children: [for (final c in filtered) _CharacterCard(c)]);
            },
          ),
        ],
      ),
    );
  }
}

class _CharacterCard extends ConsumerWidget {
  const _CharacterCard(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final name = '${c['name'] ?? ''}';
    final prof = '${c['profession'] ?? ''}';
    final color = professionColor(prof);
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final info = ref.watch(professionsProvider).valueOrNull?[prof];
    // names in the app's language once the reference data is in
    final profName = info?.name ?? prof;
    final eliteName = activeElite(c, info)?['name'] as String?;
    final race = ref.watch(racesProvider).valueOrNull?['${c['race']}'] ?? '${c['race'] ?? ''}';

    return AppCard(
      // on the site the character opens in place, under the bar of the site, as a page of a site does; the app opens a page
      onTap: () => SiteScope.of(context)
          ? ref.read(openCharacterProvider.notifier).state = name
          : Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => CharacterDetailScreen(name: name)),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: AppRadius.card,
      child: Row(
        children: [
          ClassIcon(character: c, size: 50, fallback: Text(initial, style: display(22, color: color))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(eliteName ?? profName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                const SizedBox(height: 2),
                Text('$race · ${fmtHours(c['age'], s.t('hours_short'))}',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 2),
                BirthdayLine(created: c['created'] as String?),
              ],
            ),
          ),
          Column(
            children: [
              Text(s.t('level_short'),
                  style:
                      TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.muted)),
              Text('${asInt(c['level'])}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: s.t('favorite'),
            onPressed: () => ref.read(favoriteCharactersProvider.notifier).toggle(name),
            icon: Icon(
              ref.watch(favoriteCharactersProvider).contains(name) ? Icons.star : Icons.star_border,
              size: 20,
              color: ref.watch(favoriteCharactersProvider).contains(name) ? AppColors.gold : AppColors.chevron,
            ),
          ),
        ],
      ),
    );
  }
}

/// a character as a card of a gallery: the art of the elite line it plays (or the colour of its profession) over the top, the big
/// profession mark, its name and level over that, and its numbers under it. the game has no portrait of a character to show
class _GalleryCard extends ConsumerWidget {
  const _GalleryCard(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final name = '${c['name'] ?? ''}';
    final prof = '${c['profession'] ?? ''}';
    final color = professionColor(prof);
    final info = ref.watch(professionsProvider).valueOrNull?[prof];
    final elite = activeElite(c, info);
    final art = elite?['background'] as String?;
    final mark = classIcon(c, info, big: true);
    final race = ref.watch(racesProvider).valueOrNull?['${c['race']}'] ?? '${c['race'] ?? ''}';
    final favorite = ref.watch(favoriteCharactersProvider).contains(name);
    const white = Colors.white;
    Widget stat(String label, String value) => Expanded(
          child: Column(children: [
            Text(label.caps,
                maxLines: 1,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        );
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 16,
      onTap: () => ref.read(openCharacterProvider.notifier).state = name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 168,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(color, Colors.black, 0.2)!, Color.lerp(color, Colors.black, 0.75)!],
                    ),
                  ),
                ),
                // the art is a wide strip that is dark at its right: it fills the header from its left, where the art is
                if (art != null && art.isNotEmpty)
                  Positioned.fill(
                    child: ClipRect(
                      // the strip has a dark band along its top: the picture is drawn larger from its foot to leave it out
                      child: Transform.scale(
                        scale: 1.4,
                        alignment: Alignment.bottomLeft,
                        child: Image.network(art,
                            fit: BoxFit.cover,
                            alignment: Alignment.centerLeft,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ),
                    ),
                  ),
                // the foot is darker, so that the name can be read over any art
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                if (mark != null)
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Opacity(
                        opacity: 0.92,
                        child: SizedBox(width: 64, height: 64, child: CachedIcon(url: mark, fit: BoxFit.contain))),
                  ),
                Positioned(
                  left: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: s.t('favorite'),
                    onPressed: () => ref.read(favoriteCharactersProvider.notifier).toggle(name),
                    icon: Icon(favorite ? Icons.star : Icons.star_border,
                        size: 22, color: favorite ? AppColors.gold : white),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: display(22, color: white)
                                    .copyWith(shadows: const [Shadow(blurRadius: 6, color: Colors.black54)])),
                            Text(elite?['name'] as String? ?? info?.name ?? prof,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: white)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: Text('${s.t('level_short')} ${asInt(c['level'])}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              Expanded(child: Text(race, style: TextStyle(fontSize: 13, color: AppColors.muted))),
              // the line is long in some languages: it has the rest of the row to itself
              Flexible(
                  flex: 2,
                  child:
                      Align(alignment: Alignment.centerRight, child: BirthdayLine(created: c['created'] as String?))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: Row(children: [
              stat(s.t('played'), fmtHours(c['age'], s.t('hours_short'))),
              stat(s.t('deaths'), fmtInt(asInt(c['deaths']))),
            ]),
          ),
        ],
      ),
    );
  }
}
