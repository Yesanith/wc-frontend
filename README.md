# Tyria Codex

An unofficial Guild Wars 2 companion app for Android, built with Flutter.

## Features

- Side drawer navigation across every section
- Progression: achievements in progress, mastery tracks and points, raid wings and dungeon
  paths with this week's and today's clears, PvP record per profession and WvW rank
- Trading stats: 90 days of profit and loss with the best selling items
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
- Crafting calculator: recipe tree for any craftable item, what your account already covers,
  the cost of the missing materials and whether buying the item outright is cheaper
- Recipe browser: Mystic Forge trees for legendary gear and gifts, with base materials
  compared against your account and one tap to turn a recipe into a goal
- Shareable hero cards for your characters
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
Every push to `main` also builds an APK, available under the workflow run's artifacts.

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

Push a tag starting with `v` (for example `v0.2.0`) and the workflow attaches the APK to a
GitHub release.

## Project layout

```
lib/
  api/        GW2 API and wiki clients
  data/       static data such as the world boss schedule
  l10n/       UI strings for every language
  screens/    one file per screen
  services/   disk cache, backup import/export and the recipe library
tools/        scripts run by CI, currently the recipe extractor
  state/      Riverpod providers and persisted settings
  widgets/    shared widgets
```

## Recipe data

Mystic Forge recipes are not exposed by `/v2/recipes`, but every gift describes its own
ingredients in game. `tools/build_recipes.py` walks those descriptions, resolves the names
to item ids and writes `assets/data/legendary_recipes.json`. The `Build recipe data`
workflow regenerates it monthly and commits the result, so nothing is maintained by hand.

## Disclaimer

Tyria Codex is a fan project and is not affiliated with ArenaNet or NCSOFT. Guild Wars 2,
ArenaNet and NCSOFT are trademarks of their respective owners. Wiki content belongs to the
Guild Wars 2 Wiki and is used under its license.
