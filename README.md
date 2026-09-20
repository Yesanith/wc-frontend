# Tyria Codex

An unofficial Guild Wars 2 companion app for Android, built with Flutter.

## Features

- Side drawer navigation across every section
- Account overview with wallet, Wizard's Vault dailies, bank and material storage
- Character list and details: equipment, active build, bags and crafting
- World boss timers in your local time, with pinning
- Trading Post section: gem rate, delivery box, watchlist, open orders and 90 days of history
- Goals for legendaries or any big craft, tracked against everything your account owns
- Shareable hero cards for your characters
- Wiki search in the official Guild Wars 2 Wiki, opened in an in-app browser
- English, German, French and Turkish UI. Item names and the wiki follow the selected
  language where the API and wiki support it (Turkish falls back to English data)

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
  state/      Riverpod providers and persisted settings
  widgets/    shared widgets
```

## Disclaimer

Tyria Codex is a fan project and is not affiliated with ArenaNet or NCSOFT. Guild Wars 2,
ArenaNet and NCSOFT are trademarks of their respective owners. Wiki content belongs to the
Guild Wars 2 Wiki and is used under its license.
