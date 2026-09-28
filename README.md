# Tyria Codex

An unofficial Guild Wars 2 companion app for Android, built with Flutter.

## Features

- Side drawer navigation across every section
- A home page for the day: reset countdowns, Wizard's Vault objectives, the metas you can still join, the daily checklist and the wallet
- Progression: achievements in progress, mastery tracks and points, raid wings and dungeon
  paths with this week's and today's clears, PvP record per profession and WvW rank
- Trading stats: 90 days of profit and loss with the best selling items
- Guilds: treasury progress, stash tabs and the guild log
- Home instance cats and nodes alongside the other collections
- Legendary armory and saved build templates, with full build details: the whole trait grid,
  skill facts, underwater skills, pets, revenant legends, toolbelt and chained skills,
  weapon skill bars and a generated chat code
- Daily craft and map chest progress next to the boss timers
- Collections: mounts, gliders, minis, dyes, outfits, novelties, finishers, mail carriers,
  titles, emotes and wardrobe progress, with unlocked/missing filters
- Account overview with wallet, bank and material storage
- Wizard's Vault daily, weekly and special objectives
- Gem calculator in both directions, and a month of the gem exchange rate as a chart
- Character list with sorting and favourites
- Character list and details: equipment templates with runes, sigils and infusions, the full
  build, bags and crafting
- Item pages with attributes, upgrades, what you own and the current trading post price
- World boss and meta timers on a scrollable timeline with a line for now, or as a list, in your local time, with pinning, release filters and a marker for the bosses already looted today
- Trading Post section: gem rate, delivery box, watchlist, open orders, 90 days of history and a
  list of every tradable item with filters
- News: the official guildwars2.com news and the wiki's game update notes, with a note on the home
  page when something new is out
- Side by side character comparison
- Recipes: every crafting and Mystic Forge recipe in one place, filterable by discipline,
  with a calculator that shows the tree, what your account already covers, the cost of the
  missing materials and whether buying is cheaper
- Shareable hero cards for your characters
- Maps drawn from the official tile service, with a pin on every waypoint and
  landmark, and chat codes ready to copy
- Wiki search in the official Guild Wars 2 Wiki, opened in an in-app browser
- Backup: export and import the watchlist, price history, pinned bosses and achievements and
  language as json
- Game data (items, colors, collection entries) is cached on disk for a month
- English, German, Spanish, French, Turkish, Portuguese, Russian, Japanese and Chinese UI. Item names and the wiki follow the
  selected language where the API and wiki support it. Chinese item names come from the API, Turkish,
  Portuguese, Russian and Japanese fall back to English data

- World vs World: live matchup scores, objectives per map with owner and upgrade tier, rank and abilities
- Wizard's Vault reward shop with the season, your Astral Acclaim and what you already bought
- Character progress: hero challenges, training trees, story journal per season, Super Adventure Box and biography
- Guild members, ranks, teams, built upgrades, hall storage and rendered guild emblems
- More collections: mount skins, homestead decorations and glyphs, jade bots, skiffs and PvP heroes
- Stat combination names on gear, material storage by category, trading post order book,
  learned recipe markers, luck and fractal augmentations
- PvP leaderboards for every season, board (ladder, legendary, guild) and region
- Professions: every class with its specializations, traits and weapons, and class icons
  (the elite specialization's when one is slotted) on the character pages
- Wardrobe with every skin's name and icon, filterable by armour, weapon, back and slot
- "Used in" on item pages, and each character's learned recipes
- Guild rank permissions, world names in WvW and translated race names
- Trading post price history: the app records one buy and sell price per day for watched items
  and every item page opened, with a chart and the change over 7, 30 and 90 days
- Pinned achievements on the home screen, pinned from any achievement list
## Updating

Settings shows the installed version and checks the GitHub releases for a newer one. When
there is one it links straight to the apk, which installs over the current version since
every build is signed with the same key.

## Download

Grab `tyria-codex.apk` from the [latest release](https://github.com/Yesanith/tyria-companion/releases/latest).
The `Build APK` workflow can also be run by hand for a test build, which leaves an APK under
the run's artifacts.

Several API keys can be stored and switched from settings, so alt accounts work too.

You need a Guild Wars 2 API key from [account.arena.net/applications](https://account.arena.net/applications)
with at least `account`, `characters`, `inventories` and `wallet`. `builds`, `progression`,
`unlocks` and `tradingpost` are optional but unlock more screens. The key is stored encrypted on the device and
is only sent to the official API.

## Building locally

The `android/` folder is generated rather than committed:

```sh
flutter create --platforms=android --org com.yesanith --project-name tyria_codex .
flutter pub get
flutter build apk --release
```

The app needs the `INTERNET` permission in `android/app/src/main/AndroidManifest.xml` for
release builds. The CI workflow adds it automatically.

Once per clone, so commits are formatted before they leave and pulls replay local work on top
of what the workflows committed (formatting, regenerated data, the gem history):

```sh
git config core.hooksPath .githooks
git config pull.rebase true
git config rebase.autoStash true
```

## Signing

Release builds are signed with `ci/release.keystore`, checked into the repo together with its
password so every build has the same signature and APKs install over each other. It is not a
security boundary, anyone can build an apk with the same signature. If the app ever goes to a
store, move the key into repository secrets and rotate it.

`ci/sign.py` rewires the generated gradle project to use that key, because the flutter
template signs release builds with the public android debug key, which scanners flag.

## Releases

Two ways to cut a build:

- Push a tag starting with `v` (for example `v0.21.0`). The workflow builds that version and
  attaches the APK to a GitHub release.
- Run `Build APK` by hand from the Actions tab. It asks for the version and for whether to
  publish it. Left unticked you get an APK under the run's artifacts; ticked, the workflow
  creates the `v` tag and the release itself.

Either way the version comes from the tag or the prompt, never from `pubspec.yaml`, so the
version there is not worth keeping in step.

## Project layout

```
lib/
  api/        GW2 API and wiki clients
  data/       static data such as the world boss schedule
  l10n/       one table per language, plus the AppLang enum that ties them together
  screens/    one file per screen
  services/   disk cache, backup import/export and the recipe library
  state/      Riverpod providers, one file per domain, and persisted settings
  widgets/    shared widgets
test/         unit tests for the logic that runs without a device
tools/        scripts run by CI, currently the recipe extractor
```

`state/` is split by domain rather than by layer: each file holds the providers
for one area together with the small result types they return. `state/api.dart`
holds the api key storage and the clients every other file builds on.

`flutter analyze` and `flutter test` run on every push through the
`Analyze and test` workflow.

## Recipe data

Regular crafting recipes come from `/v2/recipes`. Mystic Forge recipes are not in that
endpoint, but every gift describes its own ingredients in game. `tools/build_recipes.py`
collects both, resolves the forge ingredient names to item ids and writes one recipe book to
`assets/data/recipe_book.json.gz`, together with a gzipped per language item index used for
search. The `Build recipe data` workflow regenerates both monthly and commits the result.
It runs the recipe book, each language's index and the world map as separate jobs side by
side, each fetching several batches at a time, so a full run takes a few minutes.

The recipes section browses that book by discipline and opens the crafting calculator for any
entry, so trees expand instantly without calling the api for every step.

## World map data

`tools/build_worldmap.py` writes every waypoint, point of interest, vista, heart, hero
challenge, mastery point and map label of Tyria to `assets/data/worldmap_1_<lang>.json.gz`,
and the overview tiles to `assets/tiles/`. No single floor of `/v2/continents` holds every
map (the Path of Fire and Elona maps are on neither floor 0 nor 1), so each open world map is
read from its own default floor and the results are merged. The `Build recipe data` workflow
regenerates it with the recipes.

## Support

Tyria Codex is free and has no ads. If it helps you, you can
[buy me a coffee](https://buymeacoffee.com/yesanith). The link is also under Settings in the app.

## Disclaimer

Tyria Codex is a fan project and is not affiliated with ArenaNet or NCSOFT. Guild Wars 2,
ArenaNet and NCSOFT are trademarks of their respective owners. Wiki content belongs to the
Guild Wars 2 Wiki and is used under its license.
