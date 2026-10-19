# Wondrous Compass

An unofficial Guild Wars 2 companion for Android and the browser, built with Flutter. It reads your
account through the official Guild Wars 2 API and puts the day, your characters, the trading post and the
world's timers in one place. It is free, has no ads and does not track you.

> Wondrous Compass is a fan project. It is not made, endorsed or supported by ArenaNet or NCSOFT.

- **Android:** `wondrous-compass.apk` from the [latest release](https://github.com/Yesanith/wc-frontend/releases/latest)
- **Browser:** [yesanith.github.io/wc-frontend/app](https://yesanith.github.io/wc-frontend/app/)
- **Site, FAQ and privacy policy:** [yesanith.github.io/wc-frontend](https://yesanith.github.io/wc-frontend/)

## Getting started

1. Install the APK (Android asks once to allow installs from your browser or file manager), or open the
   browser version.
2. Create an API key at [account.arena.net/applications](https://account.arena.net/applications) and paste
   it into the app. The app checks the key and shows what it may read before saving it.

| Permission | Needed for |
| --- | --- |
| `account`, `characters`, `inventories`, `wallet` | required: the account, characters, bags, bank, materials and wallet |
| `progression` | achievements, masteries, raids, dungeons, the Wizard's Vault and daily progress |
| `unlocks` | collections, the wardrobe and learned recipes |
| `builds` | equipment and build templates |
| `tradingpost` | your buy and sell orders, the delivery box and trading history |
| `pvp` | PvP stats and match history |
| `guilds` | guild treasury, stash, log, members and ranks (the game shows some of it to leaders only) |
| `wvw` | World vs World ranks, abilities and your guilds' match statistics |

Keys are read only: they cannot spend, trade or change anything in the game. They are stored encrypted on
the device (in the browser for the browser version), sent only to the official API, and several can be
kept and switched for alt accounts.

Signing in with Discord is optional. It is only needed for guild events, public events, guild recruitment
pages and price alerts sent by the server, and even then the app sends a ten minute read only token, never
your API key. The [privacy policy](https://yesanith.github.io/wc-frontend/privacy.html) lists exactly
what is kept, where and for how long, and the account can be deleted from Settings or the
[delete account page](https://yesanith.github.io/wc-frontend/delete-account.html).

## Features

**The day**
- A home page with the reset countdowns, the Wizard's Vault objectives, the metas you can still join, the
  daily checklist (time gated crafts, map chests, world bosses) and the wallet
- World boss and meta timers on a timeline with a line for now, or as a list, in your local time, with
  pinning, release filters and a mark for the bosses already looted today
- Reminders for pinned events that keep working with the app closed
- Daily and weekly sections, and the news of guildwars2.com with the wiki's game update notes

**Your account**
- Characters with sorting and favourites, equipment templates with runes, sigils and infusions, full builds
  (traits, skills, pets, legends, chat codes), bags, crafting, birthdays and a side by side comparison
- Character progress: hero challenges, training, the story journal, Super Adventure Box and biography
- Wallet, bank, material storage by category, the legendary armory and shareable hero cards
- Progression: achievements (with pins on the home page), masteries, raids and dungeons, luck and fractal
  augmentations
- Collections: mounts and their skins, gliders, minis, dyes, outfits, novelties, finishers, mail carriers,
  titles, emotes, homestead decorations and glyphs, jade bots, skiffs, PvP heroes and the whole wardrobe
- Guilds: treasury, stash, log, members, ranks and permissions, built upgrades, hall storage and emblems
- PvP and WvW: stats per profession, leaderboards, live matchups with objectives, ranks and abilities

**Trading and crafting**
- Item pages with stats, upgrades, where every stack you own is, prices for 1, 10 or 250 with supply,
  demand and the flip profit after fees, what the item is used in, and a price history
- A list of every tradable item with filters and sorting, a watchlist with price alerts, your orders, the
  delivery box and 90 days of trading history and profit
- The gem exchange with a calculator and a month of the rate as a chart
- Every crafting and Mystic Forge recipe, a calculator that shows the tree, what your account already
  covers and whether buying is cheaper, crafting goals, and recipes ranked by profit

**Together** (with the optional account)
- Guild events with sign ups and roles, posted to the guild's Discord server by the bot
- Public events any player can make and join, per region, with their own channels on the official server
- Guild recruitment pages

**Everywhere**
- The world map from the official tiles with every waypoint and landmark and their chat codes
- Professions with every specialization, trait and weapon
- Wiki search in the official Guild Wars 2 Wiki
- English, German, Spanish, French, Turkish, Portuguese, Russian, Japanese and Chinese. Item names follow
  the language where the API has it (Chinese does, Turkish, Portuguese, Russian and Japanese use English)
- Backup of the watchlist, price history, pins and settings as json, never the API key
- Game data cached on disk, and updates checked against the GitHub releases from Settings

## Support

Wondrous Compass is free and has no ads. If it helps you, you can
[buy me a coffee](https://buymeacoffee.com/yesanith). Questions, bugs and ideas go to the
[issues](https://github.com/Yesanith/wc-frontend/issues).

## Building locally

The `android/` folder is generated rather than committed:

```sh
flutter create --platforms=android --org com.yesanith --project-name wondrous_compass .
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

Release builds are signed with a key that lives only in the repository's secrets, so every build has
the same signature and APKs install over each other, and nobody who reads the code can sign an app as
this one. The secrets are `RELEASE_KEYSTORE_BASE64` (the keystore file, base64), `RELEASE_KEYSTORE_PASSWORD`,
`RELEASE_KEY_ALIAS` and `RELEASE_KEY_PASSWORD`. A fork has none of them and cannot build a release.
To make a new key: `keytool -genkeypair -v -keystore release.keystore -alias wondrouscompass -keyalg RSA -keysize 4096 -validity 10000`,
then `base64 -w0 release.keystore | gh secret set RELEASE_KEYSTORE_BASE64`. A phone that has the app
signed with an older key has to uninstall it once before it takes the new one.

`ci/sign.py` rewires the generated gradle project to use that key, because the flutter
template signs release builds with the public android debug key, which scanners flag.

## Releases

Builds are made by hand: run `Build APK` from the Actions tab. It asks for the version and for whether
to publish it. Ticked, the workflow creates the `v` tag and the release with the APK. Left unticked it only
builds and checks; the APK of an unticked run is not kept. Pushing a tag starts nothing.

The version comes from the prompt, never from `pubspec.yaml`, so the version there is not worth keeping
in step.

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
tools/        scripts run by CI: the recipe, world map and site builders, the gem recorder, the icon maker
tools/site_content/   the texts of the website, one file per language
site/         the website's stylesheet and static files
ci/           release helpers: launcher icons, the signing key
e2e/          end to end checks of the browser build
design/       static UI concept mock-ups, not shipped
assets/       bundled map tiles and data
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

## License

The code is under the [MIT License](LICENSE). Game data, icons, map tiles and names come from
ArenaNet's Guild Wars 2 API and belong to ArenaNet; wiki text belongs to the Guild Wars 2 Wiki. Neither
is covered by this license.

## Disclaimer

Wondrous Compass is a fan project and is not affiliated with ArenaNet or NCSOFT. Guild Wars 2,
ArenaNet and NCSOFT are trademarks of their respective owners. Wiki content belongs to the
Guild Wars 2 Wiki and is used under its license.

## The site

The pages of the site (home, FAQ, privacy policy, terms of service, delete account) are made in nine
languages from the texts in `tools/site_content/<language>.json`, one file for each language, the way the
app's texts are. English is at the root of the site, the others in a folder of their own (`de/privacy.html`),
and a language picker sits in the top corner of every page.

The pages themselves are not kept in the repository. `tools/build_site.py` makes them when the site is
published, and `python3 tools/build_site.py` makes them into `site/` to look at, where git ignores them. To
change a text, change it in English and in the other files. `python3 -m unittest test_build_site` in `tools/`
checks that every language has everything English has, that a translation keeps every link, command and
emphasis of the English text, and that every link leads somewhere. The translations say that the English
version applies where they differ. The app in the browser (`site/app/`) is built when the site is published and
is not part of this.

## Smoke tests in a browser

`e2e/` has tests that open the site in a real browser (Playwright): that a link to it shows its name and picture, that a visitor is shown what the app is, that a guest gets the app with the bar of a site, that
the pages have addresses and the back button goes between them, that the search finds a page, and that the page throws no error. Flutter draws on a canvas, so the tests switch its accessibility tree on to read it.
They run in the workflow Smoke, which is not part of the deploy: after the site has been deployed, every morning and on request (`BASE_URL` takes the address of a build served anywhere else). When a test fails, what the browser
saw is kept in Supabase, as the next section says.

## What a run keeps

No workflow keeps anything as an artifact of GitHub, whose small storage fills and then stops every run that uploads
one. What is worth keeping goes to the private bucket `ci` of the Supabase project through `ci/keep.sh`, the newest ten
of each kind: what a failed check (`check/`), build (`build/`) or smoke test (`smoke/`, with the screenshots) said, and
the browser build of a feature branch (`preview/`). The run's summary names the file; it is under Storage in the
Supabase dashboard. The data jobs hand their files on through the cache of the run, and the site's artifact, which
GitHub Pages cannot do without, is deleted as soon as the site is deployed.

It needs an S3 access key of the project (Supabase dashboard, Storage, S3 configuration), which opens storage and not
the database, in these repository secrets: `SUPABASE_S3_KEY_ID`, `SUPABASE_S3_SECRET` and `SUPABASE_S3_REGION`, next
to the `SUPABASE_URL` the app has. Without them a run still runs, and only keeps nothing.
