# Tyria Codex

An unofficial Guild Wars 2 companion app for Android, built with Flutter.

## Features

- Side drawer navigation across every section
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
- Gem calculator in both directions
- Character list with sorting and favourites
- Character list and details: equipment templates with runes, sigils and infusions, the full
  build, bags and crafting
- Item pages with attributes, upgrades, what you own and the current trading post price
- World boss timers in your local time, with pinning and a marker for the ones you already did today
- Trading Post section: gem rate, delivery box, watchlist, open orders and 90 days of history
- Goals for legendaries or any big craft, tracked against everything your account owns
- Goals suggest what to buy first, cheapest missing piece at the top
- Side by side character comparison
- Recipes: every crafting and Mystic Forge recipe in one place, filterable by discipline,
  with a calculator that shows the tree, what your account already covers, the cost of the
  missing materials, whether buying is cheaper, and one tap to turn it into a goal
- Shareable hero cards for your characters
- Maps drawn from the official tile service, with a pin on every waypoint and
  landmark, and chat codes ready to copy
- Wiki search in the official Guild Wars 2 Wiki, opened in an in-app browser
- Backup: export and import goals, watchlist, pinned bosses and language as json
- Game data (items, colors, collection entries) is cached on disk for a month
- English, German, French and Turkish UI. Item names and the wiki follow the selected
  language where the API and wiki support it (Turkish falls back to English data)

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
  l10n/       UI strings for every language
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

The recipes section browses that book by discipline and opens the crafting calculator for any
entry, so trees expand instantly without calling the api for every step.

## Disclaimer

Tyria Codex is a fan project and is not affiliated with ArenaNet or NCSOFT. Guild Wars 2,
ArenaNet and NCSOFT are trademarks of their respective owners. Wiki content belongs to the
Guild Wars 2 Wiki and is used under its license.
