import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session, User;
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/screens/admin/recruitment_reports.dart';
import 'package:tyria_codex/screens/recruitment/editor_screen.dart';
import 'package:tyria_codex/screens/recruitment/page_screen.dart';
import 'package:tyria_codex/screens/recruitment/recruiters_screen.dart';
import 'package:tyria_codex/screens/recruitment_screen.dart';
import 'package:tyria_codex/state/community.dart';
import 'package:tyria_codex/state/guild_events.dart';
import 'package:tyria_codex/state/navigation.dart';
import 'package:tyria_codex/state/recruitment.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/theme.dart';

const _id = '7c1d8e2a-3b4f-4a5c-8d6e-9f0a1b2c3d4e';

Session _session() => Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: const User(
          id: 'u1', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-10-03T00:00:00Z'),
    );

RecruitCard _card(String name,
        {String tag = '',
        bool recruiting = true,
        String headline = '',
        List<String> looking = const [],
        List<String> languages = const [],
        RecruitRegion region = RecruitRegion.any,
        String playTimes = '',
        String? id}) =>
    RecruitCard(
      guildId: id ?? '00000000-0000-0000-0000-${name.hashCode.abs().toString().padLeft(12, '0').substring(0, 12)}',
      gw2GuildId: 'g',
      name: name,
      tag: tag,
      headline: headline,
      lookingFor: looking,
      languages: languages,
      region: region,
      recruiting: recruiting,
      playTimes: playTimes,
    );

RecruitPage _thePage({
  bool canEdit = false,
  bool isLeader = false,
  bool published = true,
  bool hidden = false,
  bool stale = false,
  String? invite = 'https://discord.gg/abc123',
  String contact = 'Whisper Leo.1',
  String? hiddenReason,
  RecruitRegion region = RecruitRegion.eu,
}) =>
    RecruitPage(
      guildId: _id,
      gw2GuildId: 'g',
      name: 'Mistwalkers',
      tag: 'MIST',
      headline: 'Raids on Thursdays',
      description: 'A friendly raiding guild that plays in the evenings.',
      requirements: 'Level 80',
      playTimes: 'EU evenings',
      lookingFor: const ['raids', 'fractals'],
      languages: const ['en'],
      region: region,
      discordInvite: invite,
      contact: contact,
      canEdit: canEdit,
      isLeader: isLeader,
      published: published,
      hidden: hidden,
      stale: stale,
      hiddenReason: hiddenReason,
    );

MyRecruitGuild _mine(
        {bool leader = true,
        bool hasPage = true,
        bool published = true,
        bool hidden = false,
        bool stale = false,
        String id = _id,
        String name = 'Mistwalkers',
        String tag = 'MIST'}) =>
    MyRecruitGuild(
        guildId: id,
        gw2GuildId: 'g',
        name: name,
        tag: tag,
        isLeader: leader,
        hasPage: hasPage,
        published: published,
        hidden: hidden,
        stale: stale);

/// the database, pretending: what it has, and what it was asked
class FakeRecruit implements RecruitBackend {
  FakeRecruit(
      {this.cards = const [], this.total, this.current, this.myGuilds = const [], this.allowed = const [], this.fail});

  List<RecruitCard> cards;
  int? total;

  /// the page of the guild, null while there is none
  RecruitPage? current;

  /// the guilds the player may manage the page of
  List<MyRecruitGuild> myGuilds;

  /// who the leader allowed
  List<RecruiterEntry> allowed;

  /// thrown by what changes something
  Object? fail;

  final filters = <RecruitFilter>[];
  final saves = <RecruitDraft>[];
  final publishes = <bool>[];
  final grants = <String>[];
  final revokes = <String>[];
  final reports = <String>[];

  /// what was done to the page, in the order it was done
  final calls = <String>[];

  /// the pages that were reported or are hidden, for the administrator, and what was done to them
  List<RecruitReport> reported = const [];
  final hides = <(String, bool, String?)>[];
  var deletes = 0;
  var mineCalls = 0;

  @override
  Future<RecruitList> list(RecruitFilter filter) async {
    filters.add(filter);
    return RecruitList(rows: cards.skip(filter.offset).take(recruitPageSize).toList(), total: total ?? cards.length);
  }

  @override
  Future<RecruitPage?> page(String guildId) async => current;

  @override
  Future<List<MyRecruitGuild>> mine() async {
    mineCalls++;
    return myGuilds;
  }

  RecruitPage _with(RecruitPage? p, RecruitDraft d, {required bool published}) => RecruitPage(
        guildId: _id,
        gw2GuildId: 'g',
        name: 'Mistwalkers',
        tag: 'MIST',
        headline: d.headline.trim(),
        description: d.description.trim(),
        requirements: d.requirements.trim(),
        playTimes: d.playTimes.trim(),
        lookingFor: d.lookingFor.toList(),
        languages: d.languages.toList(),
        region: d.region,
        recruiting: d.recruiting,
        discordInvite: d.discordInvite.trim().isEmpty ? null : d.discordInvite.trim(),
        contact: d.contact.trim(),
        canEdit: true,
        isLeader: true,
        published: published,
      );

  @override
  Future<RecruitPage?> save(String guildId, RecruitDraft draft) async {
    if (fail != null) throw fail!;
    saves.add(draft);
    calls.add('save');
    current = _with(current, draft, published: current?.published ?? false);
    return current;
  }

  @override
  Future<RecruitPage?> setPublished(String guildId, bool published) async {
    if (fail != null) throw fail!;
    publishes.add(published);
    calls.add('publish:$published');
    current = _with(current, RecruitDraft.fromPage(current!), published: published);
    return current;
  }

  @override
  Future<void> delete(String guildId) async {
    if (fail != null) throw fail!;
    deletes++;
    current = null;
  }

  @override
  Future<List<RecruiterEntry>> recruiters(String guildId) async => allowed;

  @override
  Future<void> grant(String guildId, String userId) async {
    if (fail != null) throw fail!;
    grants.add(userId);
    allowed = [...allowed, RecruiterEntry(userId: userId, accountName: 'granted-$userId')];
  }

  @override
  Future<void> revoke(String guildId, String userId) async {
    if (fail != null) throw fail!;
    revokes.add(userId);
    allowed = [
      for (final r in allowed)
        if (r.userId != userId) r,
    ];
  }

  @override
  Future<void> report(String guildId, String reason) async {
    if (fail != null) throw fail!;
    reports.add(reason);
  }

  @override
  Future<List<RecruitReport>> adminReports() async => reported;

  @override
  Future<void> adminSetHidden(String guildId, bool hidden, String? reason) async {
    if (fail != null) throw fail!;
    hides.add((guildId, hidden, reason));
    reported = [
      for (final r in reported)
        if (r.guildId == guildId)
          RecruitReport(
              guildId: r.guildId,
              name: r.name,
              tag: r.tag,
              headline: r.headline,
              reports: r.reports,
              reasons: r.reasons,
              hidden: hidden,
              published: r.published,
              hiddenReason: reason)
        else
          r,
    ];
  }
}

/// the notice goes by itself after a few seconds: let it, a timer that is pending is a test that did not end
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// what is shown, and the database it is shown with
class Shown {
  Shown(this.container, this.fake);

  final ProviderContainer container;
  final FakeRecruit fake;
}

void main() {
  late List<String> copied;

  setUp(() {
    copied = [];
    debugSetCommunityReady(true);
  });

  tearDown(() => debugSetCommunityReady(false));

  Future<Shown> show(
    WidgetTester tester,
    FakeRecruit fake, {
    required Widget home,
    Stream<Session?>? session,
    double height = 3000,
    List<RosterMember> roster = const [],
  }) async {
    tester.view.physicalSize = Size(1000, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      sessionProvider.overrideWith((ref) => session ?? Stream.value(_session())),
      recruitBackendProvider.overrideWithValue(fake),
      guildRosterProvider.overrideWith((ref, id) async => roster),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(), home: Scaffold(body: home)),
    ));
    await tester.pumpAndSettle();
    return Shown(container, fake);
  }

  /// a screen that is opened over another, as the app does, so that it can be closed
  Widget opening(Widget Function(BuildContext) screen) => Builder(
        builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: screen)),
            child: const Text('go')),
      );

  Future<void> tapOn(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('the list of guilds that are recruiting', () {
    final two = [
      _card('Mistwalkers',
          tag: 'MIST',
          headline: 'Raids on Thursdays',
          looking: const ['raids', 'fractals'],
          languages: const ['en'],
          region: RecruitRegion.eu,
          playTimes: 'EU evenings',
          id: _id),
      _card('Dawnbreakers',
          tag: 'DAWN',
          recruiting: false,
          headline: 'Casual fractals',
          looking: const ['casual'],
          languages: const ['en']),
    ];

    testWidgets('says it is not in this build when the community backend is not there, and asks the database nothing',
        (tester) async {
      debugSetCommunityReady(false);
      final fake = FakeRecruit(cards: two);
      await show(tester, fake, home: const RecruitmentScreen());
      expect(find.text('Recruitment pages are not available in this build.'), findsOneWidget);
      expect(fake.filters, isEmpty);
    });

    testWidgets(
        'asks for the first page with no filter, and shows the guilds with their name, headline and when they play',
        (tester) async {
      final fake = FakeRecruit(cards: two);
      await show(tester, fake, home: const RecruitmentScreen());
      expect(fake.filters.first, noRecruitFilter);
      expect(find.text('Mistwalkers [MIST]'), findsOneWidget);
      expect(find.text('Raids on Thursdays'), findsOneWidget);
      expect(find.text('EU evenings'), findsOneWidget);
      expect(find.text('Dawnbreakers [DAWN]'), findsOneWidget);
    });

    testWidgets('says of each whether it is recruiting, and keeps the order the database gave', (tester) async {
      await show(tester, FakeRecruit(cards: two), home: const RecruitmentScreen());
      expect(find.text('Recruiting'), findsOneWidget);
      expect(find.text('Not recruiting now'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Mistwalkers [MIST]')).dy,
          lessThan(tester.getTopLeft(find.text('Dawnbreakers [DAWN]')).dy));
    });

    testWidgets('shows what each looks for, the languages and the region, in its own card', (tester) async {
      await show(tester, FakeRecruit(cards: two), home: const RecruitmentScreen());
      Finder inCard(String title, String text) => find.descendant(
          of: find.ancestor(of: find.text(title), matching: find.byType(InkWell)), matching: find.text(text));
      for (final t in ['Raids', 'Fractals', 'English', 'Europe']) {
        expect(inCard('Mistwalkers [MIST]', t), findsOneWidget, reason: t);
      }
      expect(inCard('Dawnbreakers [DAWN]', 'Casual'), findsOneWidget);
      expect(inCard('Dawnbreakers [DAWN]', 'English'), findsOneWidget);
      expect(inCard('Dawnbreakers [DAWN]', 'Raids'), findsNothing, reason: 'what the other looks for');
      expect(inCard('Dawnbreakers [DAWN]', 'Europe'), findsNothing,
          reason: 'a guild of any region has no region to show');
    });

    testWidgets('says so when no guild matches', (tester) async {
      await show(tester, FakeRecruit(), home: const RecruitmentScreen());
      expect(find.text('No guild matches. Try fewer filters.'), findsOneWidget);
    });

    testWidgets(
        'has a chip for each of the seven languages that the forum has a tag for, and none for Japanese or Chinese',
        (tester) async {
      await show(tester, FakeRecruit(), home: const RecruitmentScreen());
      for (final code in recruitLanguages) {
        expect(find.widgetWithText(ChoiceChip, recruitLanguageLabel(code)), findsOneWidget, reason: code);
      }
      expect(find.widgetWithText(ChoiceChip, '日本語'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '中文'), findsNothing);
    });

    testWidgets('asks again for each filter that is chosen, and for the first page', (tester) async {
      final fake = FakeRecruit();
      await show(tester, fake, home: const RecruitmentScreen());

      await tapOn(tester, find.widgetWithText(ChoiceChip, 'Deutsch'));
      expect(fake.filters.last.language, 'de');
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'Raids'));
      expect(fake.filters.last.lookingFor, 'raids');
      expect(fake.filters.last.language, 'de', reason: 'and the other is kept');
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'Europe'));
      expect(fake.filters.last.region, RecruitRegion.eu);
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'North America'));
      expect(fake.filters.last.region, RecruitRegion.na);
      await tapOn(tester, find.widgetWithText(FilterChip, 'Recruiting now'));
      expect(fake.filters.last.openOnly, isTrue);
      expect(fake.filters.last.offset, 0);

      // and each is taken off again
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'Any region'));
      expect(fake.filters.last.region, isNull);
      await tapOn(tester, find.widgetWithText(FilterChip, 'Recruiting now'));
      expect(fake.filters.last.openOnly, isFalse);
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'All').first);
      expect(fake.filters.last.language, isNull);
      expect(fake.filters.last.lookingFor, 'raids');
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'All').last);
      expect(fake.filters.last, noRecruitFilter);
    });

    testWidgets('searches for a text, trimmed, and clears the search', (tester) async {
      final fake = FakeRecruit();
      await show(tester, fake, home: const RecruitmentScreen());
      await tester.enterText(find.byKey(const Key('rec-search')), '  mist  ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(fake.filters.last.search, 'mist');
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.filters.last.search, '');
      expect(find.byTooltip('Cancel'), findsNothing);
    });

    testWidgets(
        'has a button for the next page when the page is full and there are more, and the next page is added under it',
        (tester) async {
      final many = [
        for (var i = 0; i < 45; i++) _card('G$i', id: '00000000-0000-0000-0000-${i.toString().padLeft(12, '0')}')
      ];
      final fake = FakeRecruit(cards: many);
      await show(tester, fake, home: const RecruitmentScreen(), height: 9000);
      expect(find.text('G0'), findsOneWidget);
      expect(find.text('G29'), findsOneWidget);
      expect(find.text('G30'), findsNothing);
      await tapOn(tester, find.text('Show more'));
      expect(fake.filters.last.offset, 30);
      expect(find.text('G44'), findsOneWidget);
      expect(find.text('G0'), findsOneWidget, reason: 'the first page is still there');
      expect(find.text('Show more'), findsNothing, reason: 'there are no more');
      // a filter begins again at the first page
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'Deutsch'));
      expect(find.text('G44'), findsNothing);
      expect(fake.filters.last.offset, 0);
    });

    testWidgets('has no button for more when everything is in the page', (tester) async {
      await show(tester, FakeRecruit(cards: [for (var i = 0; i < 30; i++) _card('G$i')], total: 30),
          home: const RecruitmentScreen(), height: 9000);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('opens the page of a guild from its card, and comes back', (tester) async {
      final fake = FakeRecruit(cards: two, current: _thePage());
      await show(tester, fake, home: const RecruitmentScreen());
      await tester.tap(find.text('Mistwalkers [MIST]'));
      await tester.pumpAndSettle();
      expect(find.text('A friendly raiding guild that plays in the evenings.'), findsOneWidget);
      expect(find.text('Join their Discord'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Dawnbreakers [DAWN]'), findsOneWidget);
    });

    testWidgets('says it has no list, and says how to try again, when the database cannot be asked', (tester) async {
      final fake = _FailingList();
      await show(tester, fake, home: const RecruitmentScreen());
      expect(find.text('Something went wrong. Try again in a moment.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('RecruitFailure'), findsNothing, reason: 'no raw failure');
    });
  });

  group('the pages of the guilds the player may manage, above the list', () {
    testWidgets('are not there for a visitor, who is told once how to sign in, with the way to the settings',
        (tester) async {
      final fake = FakeRecruit(myGuilds: [_mine()]);
      final shown = await show(tester, fake, home: const RecruitmentScreen(), session: Stream.value(null));
      expect(find.text("Sign in with Discord in Settings to make or edit your guild's page."), findsOneWidget);
      expect(find.text("Your guilds' pages"), findsNothing);
      expect(fake.mineCalls, 0, reason: 'what a visitor may not do is not asked of the database');
      expect(shown.container.read(sectionProvider), isNot(AppSection.settings));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(shown.container.read(sectionProvider), AppSection.settings);
    });

    testWidgets('are not there for a player who manages none, and the list is as for anybody', (tester) async {
      final fake = FakeRecruit(cards: [_card('Mistwalkers', tag: 'MIST')]);
      await show(tester, fake, home: const RecruitmentScreen());
      expect(find.text("Your guilds' pages"), findsNothing);
      expect(find.text("Sign in with Discord in Settings to make or edit your guild's page."), findsNothing);
      expect(find.text('Mistwalkers [MIST]'), findsOneWidget);
    });

    testWidgets('say where each page is, and have the buttons that fit: only the leader says who else may edit',
        (tester) async {
      final fake = FakeRecruit(myGuilds: [
        _mine(id: 'a', name: 'None', tag: 'N', hasPage: false, published: false),
        _mine(id: 'b', name: 'Draft', tag: 'D', published: false, leader: false),
        _mine(id: 'c', name: 'Live', tag: 'L'),
        _mine(id: 'd', name: 'Old', tag: 'O', stale: true),
        _mine(id: 'e', name: 'Hidden', tag: 'H', hidden: true),
      ]);
      await show(tester, fake, home: const RecruitmentScreen());
      expect(find.text("Your guilds' pages"), findsOneWidget);
      expect(find.text('No page yet'), findsOneWidget);
      expect(find.text('Draft, only you see it'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Published, but out of the list: not updated for 60 days'), findsOneWidget);
      expect(find.text('Hidden by a moderator'), findsOneWidget);
      expect(find.text('Create the page'), findsOneWidget, reason: 'only for the guild that has none');
      expect(find.text('Edit'), findsNWidgets(4));
      expect(find.text('View'), findsNWidgets(4), reason: 'and a page is seen only where there is one');
      expect(find.text('Who may edit'), findsNWidgets(4), reason: 'all but the one the player does not lead');
    });

    testWidgets('open the editor, and ask again for what the player manages when it is closed', (tester) async {
      final fake = FakeRecruit(myGuilds: [_mine(hasPage: false, published: false)]);
      await show(tester, fake, home: const RecruitmentScreen());
      expect(fake.mineCalls, 1);
      await tester.tap(find.text('Create the page'));
      await tester.pumpAndSettle();
      expect(find.text('Recruitment page · Mistwalkers [MIST]'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(fake.mineCalls, 2, reason: 'what was done there changes what is here');
    });

    testWidgets('open the page to see it, and the leader\'s list of who may edit', (tester) async {
      final fake = FakeRecruit(myGuilds: [_mine()], current: _thePage(canEdit: true, isLeader: true));
      await show(tester, fake, home: const RecruitmentScreen());
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('Join their Discord'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Who may edit'));
      await tester.pumpAndSettle();
      expect(find.text('Who may edit the page · Mistwalkers [MIST]'), findsOneWidget);
    });
  });
  group('the page of a guild', () {
    Future<Shown> page(WidgetTester tester, FakeRecruit fake, {Stream<Session?>? session, String id = _id}) =>
        show(tester, fake, home: RecruitPageScreen(guildId: id), session: session);

    testWidgets('says it is not in this build when the community backend is not there', (tester) async {
      debugSetCommunityReady(false);
      await page(tester, FakeRecruit(current: _thePage()));
      expect(find.text('Recruitment pages are not available in this build.'), findsOneWidget);
    });

    testWidgets('shows what the guild says of itself and how to reach it', (tester) async {
      await page(tester, FakeRecruit(current: _thePage()));
      expect(find.text('Mistwalkers [MIST]'), findsWidgets);
      expect(find.text('Raids on Thursdays'), findsOneWidget);
      expect(find.text('A friendly raiding guild that plays in the evenings.'), findsOneWidget);
      expect(find.text('Recruiting'), findsOneWidget);
      expect(find.text('RAIDS'), findsNothing);
      for (final t in ['Raids', 'Fractals', 'English']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Level 80'), findsOneWidget);
      expect(find.text('EU evenings'), findsOneWidget);
      expect(find.text('Europe'), findsOneWidget);
      expect(find.text('Join their Discord'), findsOneWidget);
      expect(find.text('Whisper Leo.1'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('says a guild is not recruiting when it says it is not', (tester) async {
      final p = _thePage();
      final closed = RecruitPage(
          guildId: p.guildId,
          gw2GuildId: p.gw2GuildId,
          name: p.name,
          tag: p.tag,
          headline: p.headline,
          description: p.description,
          recruiting: false,
          contact: 'x');
      await page(tester, FakeRecruit(current: closed));
      expect(find.text('Not recruiting now'), findsOneWidget);
    });

    testWidgets('leaves out what the guild did not say, and the region when it takes players of any', (tester) async {
      const p = RecruitPage(
          guildId: _id,
          gw2GuildId: 'g',
          name: 'Plain',
          tag: '',
          headline: 'Hi',
          description: 'A description that is long enough.',
          contact: 'Whisper me');
      await page(tester, FakeRecruit(current: p));
      expect(find.text('LOOKING FOR'), findsNothing);
      expect(find.text('REQUIREMENTS'), findsNothing);
      expect(find.text('WHEN THEY PLAY'), findsNothing);
      expect(find.text('LANGUAGES'), findsNothing);
      expect(find.text('REGION'), findsNothing);
      expect(find.text('Join their Discord'), findsNothing, reason: 'there is no invite');
      expect(find.text('Whisper me'), findsOneWidget);
      expect(find.text('Plain'), findsWidgets, reason: 'and a guild with no tag has no brackets');
    });

    testWidgets('has no way to reach the guild when it has given none', (tester) async {
      await page(tester, FakeRecruit(current: _thePage(invite: null, contact: '')));
      expect(find.text('HOW TO REACH THEM'), findsNothing);
      expect(find.text('Join their Discord'), findsNothing);
    });

    testWidgets('does not make a button of an invite that is not Discord\'s', (tester) async {
      await page(tester, FakeRecruit(current: _thePage(invite: 'https://example.com/evil', contact: '')));
      expect(find.text('Join their Discord'), findsNothing);
    });

    testWidgets('copies the name to whisper', (tester) async {
      await page(tester, FakeRecruit(current: _thePage(invite: null)));
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();
      expect(copied.last, 'Whisper Leo.1');
      await settle(tester);
    });

    testWidgets('says that it was not updated for a while, only when it is shown to everybody', (tester) async {
      await page(tester, FakeRecruit(current: _thePage(stale: true)));
      expect(find.text('This page has not been updated for a while. The guild may not be recruiting any more.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await page(tester, FakeRecruit(current: _thePage(stale: true, published: false)));
      expect(find.text('This page has not been updated for a while. The guild may not be recruiting any more.'),
          findsNothing);
      expect(find.text('This is a draft. Only those who manage it can see it.'), findsOneWidget);
    });

    testWidgets('says that a moderator hid it, and why, to those who manage it', (tester) async {
      await page(tester, FakeRecruit(current: _thePage(canEdit: true, hidden: true, hiddenReason: 'Spam')));
      expect(find.textContaining('A moderator hid this page. Only those who manage it can see it.'), findsOneWidget);
      expect(find.textContaining('Spam'), findsOneWidget);
    });

    testWidgets('says that the page is not there when there is none for whoever asks', (tester) async {
      await page(tester, FakeRecruit());
      expect(find.text("That guild's page is not there any more."), findsOneWidget);
    });

    testWidgets('copies its address, which opens the app at it', (tester) async {
      await page(tester, FakeRecruit(current: _thePage()));
      await tester.tap(find.byTooltip('Copy link to this page'));
      await tester.pump();
      expect(copied.last, 'https://yesanith.github.io/tyria-companion/app/#/recruit/$_id');
      expect(find.text('Copied.'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('has no address to copy when the number is not a guild\'s', (tester) async {
      await page(tester, FakeRecruit(current: _thePage()), id: 'nope');
      expect(find.byTooltip('Copy link to this page'), findsNothing);
    });

    testWidgets('can be reported by a player who is signed in and who does not manage it, who says why',
        (tester) async {
      final fake = FakeRecruit(current: _thePage());
      await page(tester, fake);
      expect(find.byTooltip('Edit'), findsNothing);
      await tester.tap(find.byTooltip('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Why do you report this page?'), findsOneWidget);
      final send = find.widgetWithText(FilledButton, 'Report');
      expect(tester.widget<FilledButton>(send).onPressed, isNull, reason: 'it must say why');
      await tester.enterText(find.byKey(const Key('report-reason')), '  It is spam  ');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(fake.reports, ['It is spam']);
      expect(find.text('Thank you. It was reported.'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('is not reported when the dialog is closed', (tester) async {
      final fake = FakeRecruit(current: _thePage());
      await page(tester, fake);
      await tester.tap(find.byTooltip('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.reports, isEmpty);
    });

    testWidgets('tells the player why a report was refused', (tester) async {
      final fake = FakeRecruit(current: _thePage(), fail: const RecruitFailure('too_many'));
      await page(tester, fake);
      await tester.tap(find.byTooltip('Report'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report-reason')), 'spam');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Report'));
      await tester.pumpAndSettle();
      expect(find.text('You have reported many pages today. Try again tomorrow.'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('cannot be reported by a visitor, who is not asked to', (tester) async {
      await page(tester, FakeRecruit(current: _thePage()), session: Stream.value(null));
      expect(find.byTooltip('Report'), findsNothing);
      expect(find.text('Join their Discord'), findsOneWidget, reason: 'and reads all of it');
    });

    testWidgets('is edited by whoever manages it, and not reported', (tester) async {
      await page(tester, FakeRecruit(current: _thePage(canEdit: true, isLeader: true)));
      expect(find.byTooltip('Report'), findsNothing);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Recruitment page · Mistwalkers [MIST]'), findsOneWidget);
      expect(find.byKey(const Key('rec-headline')), findsOneWidget);
    });
  });

  group('the editor of a page', () {
    Future<FakeRecruit> editor(WidgetTester tester, FakeRecruit fake, {MyRecruitGuild? guild}) async {
      await show(tester, fake, home: opening((_) => RecruitEditorScreen(guild: guild ?? _mine())), height: 4000);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return fake;
    }

    String text(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

    Future<void> fill(WidgetTester tester,
        {String headline = 'Mistwalkers want you',
        String description = 'A friendly raiding guild that plays in the evenings.',
        String contact = 'Whisper Leo.1'}) async {
      await tester.enterText(find.byKey(const Key('rec-headline')), headline);
      await tester.enterText(find.byKey(const Key('rec-description')), description);
      await tester.enterText(find.byKey(const Key('rec-contact')), contact);
      await tester.pump();
    }

    testWidgets('begins empty for a guild that has no page, with recruiting on, and nothing to delete or keep',
        (tester) async {
      await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      expect(text(tester, 'rec-headline'), '');
      expect(text(tester, 'rec-description'), '');
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('rec-recruiting'))).value, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('rec-published'))).value, isFalse);
      expect(find.text('Delete the page'), findsNothing);
    });

    testWidgets('begins as the page is, in every field', (tester) async {
      await editor(tester, FakeRecruit(current: _thePage(canEdit: true, isLeader: true)));
      expect(text(tester, 'rec-headline'), 'Raids on Thursdays');
      expect(text(tester, 'rec-description'), 'A friendly raiding guild that plays in the evenings.');
      expect(text(tester, 'rec-requirements'), 'Level 80');
      expect(text(tester, 'rec-play-times'), 'EU evenings');
      expect(text(tester, 'rec-discord'), 'https://discord.gg/abc123');
      expect(text(tester, 'rec-contact'), 'Whisper Leo.1');
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('rec-published'))).value, isTrue);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Raids')).selected, isTrue);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Social')).selected, isFalse);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'English')).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Deutsch')).selected, isFalse);
    });

    testWidgets('saves the page as it is on the screen, and says so', (tester) async {
      final fake = await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      await fill(tester);
      await tester.enterText(find.byKey(const Key('rec-requirements')), 'Level 80');
      await tester.enterText(find.byKey(const Key('rec-play-times')), 'EU evenings');
      await tester.enterText(find.byKey(const Key('rec-discord')), 'https://discord.gg/abc123');
      await tapOn(tester, find.widgetWithText(FilterChip, 'Raids'));
      await tapOn(tester, find.widgetWithText(FilterChip, 'Social'));
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'Türkçe'));
      await tapOn(tester, find.text('Europe'));
      await tapOn(tester, find.byKey(const Key('rec-recruiting')));
      await tapOn(tester, find.text('Save'));
      final sent = fake.saves.single;
      expect(sent.headline, 'Mistwalkers want you');
      expect(sent.description, startsWith('A friendly raiding'));
      expect(sent.requirements, 'Level 80');
      expect(sent.playTimes, 'EU evenings');
      expect(sent.discordInvite, 'https://discord.gg/abc123');
      expect(sent.contact, 'Whisper Leo.1');
      expect(sent.lookingFor, {'raids', 'social'});
      expect(sent.languages, {'tr'});
      expect(sent.region, RecruitRegion.eu);
      expect(sent.recruiting, isFalse);
      expect(fake.publishes, isEmpty, reason: 'it stays a draft');
      expect(find.text('Saved.'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('does not send a page that is not valid, and says why: an invite that is not Discord\'s',
        (tester) async {
      final fake = await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      await tester.enterText(find.byKey(const Key('rec-discord')), 'https://example.com/x');
      await tester.pump();
      const why =
          'Something on the page is not valid: a text that is too long, or an invite that is not a Discord invite.';
      expect(find.text(why), findsOneWidget, reason: 'said when it is typed');
      await tapOn(tester, find.text('Save'));
      expect(fake.saves, isEmpty);
      expect(find.text(why), findsNWidgets(2), reason: 'and when it is sent');
      await settle(tester);
    });

    testWidgets('has an invite that is empty as no invite, and no complaint', (tester) async {
      final fake = await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      await tester.enterText(find.byKey(const Key('rec-discord')), '   ');
      await tester.pump();
      expect(find.textContaining('not a Discord invite'), findsNothing);
      await tapOn(tester, find.text('Save'));
      expect(fake.saves.single.discordInvite.trim(), isEmpty);
      await settle(tester);
    });

    testWidgets(
        'lets a guild look for four things and play in one language, and the fifth thing waits until one is taken off',
        (tester) async {
      await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      const s = S(AppLang.en);
      Finder tag(int i) => find.widgetWithText(FilterChip, recruitTagLabel(s, recruitTags[i]));
      Finder lang(int i) => find.widgetWithText(ChoiceChip, recruitLanguageLabel(recruitLanguages[i]));
      for (final i in [0, 1, 2, 3]) {
        await tapOn(tester, tag(i));
      }
      // four things looked for: no other can be chosen, but the language still can, for it has its place
      for (final i in [4, 12]) {
        await tester.ensureVisible(tag(i));
        expect(tester.widget<FilterChip>(tag(i)).onSelected, isNull);
      }
      await tapOn(tester, lang(0));
      expect(tester.widget<ChoiceChip>(lang(0)).selected, isTrue);
      // one language: another takes the first off
      await tapOn(tester, lang(1));
      expect(tester.widget<ChoiceChip>(lang(0)).selected, isFalse);
      expect(tester.widget<ChoiceChip>(lang(1)).selected, isTrue);
      // and what is taken off gives the place back
      await tapOn(tester, tag(3));
      expect(tester.widget<FilterChip>(tag(4)).onSelected, isNotNull);
    });

    testWidgets('lets the language be taken off again, which is no language', (tester) async {
      final fake = await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      await fill(tester);
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'English'));
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'English'));
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'English')).selected, isFalse);
      await tapOn(tester, find.text('Save'));
      expect(fake.saves.single.languages, isEmpty);
      await settle(tester);
    });

    testWidgets('says how many tags are chosen of the five, and what they are for', (tester) async {
      await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      String hint(int n) =>
          'The page is posted in the forum of the official Discord server with these as its tags, and a post has 5 at the most: choose one language and up to 4 things you look for. $n of 5 chosen.';
      expect(find.text(hint(0)), findsOneWidget);
      await tapOn(tester, find.widgetWithText(FilterChip, 'Raids'));
      expect(find.text(hint(1)), findsOneWidget);
      await tapOn(tester, find.widgetWithText(ChoiceChip, 'English'));
      expect(find.text(hint(2)), findsOneWidget);
      await tapOn(tester, find.widgetWithText(FilterChip, 'Raids'));
      expect(find.text(hint(1)), findsOneWidget, reason: 'it counts what is taken off');
    });

    testWidgets(
        'has no choice of Japanese or Chinese, which the forum has no tag for, and the languages are the seven of its tags',
        (tester) async {
      await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      expect(find.widgetWithText(ChoiceChip, '日本語'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '中文'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Русский'), findsOneWidget, reason: 'the last of the seven');
      expect(find.widgetWithText(ChoiceChip, 'English'), findsOneWidget);
    });

    testWidgets(
        'keeps what a page chose before: Japanese is a chip that is on, to be taken off, and the page is not sent until it is',
        (tester) async {
      const old = RecruitPage(
        guildId: _id,
        gw2GuildId: 'g',
        name: 'M',
        tag: 'M',
        headline: 'H',
        description: 'A description that is long enough to be one.',
        contact: 'Whisper me',
        lookingFor: ['raids', 'fractals', 'strikes', 'dungeons', 'wvw', 'pvp', 'farming', 'casual'],
        languages: ['en', 'ja'],
        canEdit: true,
      );
      final fake = await editor(tester, FakeRecruit(current: old));
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '日本語')).selected, isTrue);
      await tapOn(tester, find.text('Save'));
      expect(fake.saves, isEmpty, reason: 'ten tags and a language that is no tag');
      expect(
          find.text(
              'The page is posted in the forum of the official Discord server with these as its tags, and a post has 5 at the most: choose one language and up to 4 things you look for. 10 of 5 chosen.'),
          findsWidgets);
      await settle(tester);
      // taken off: the language that is no tag, and enough of what it looks for
      await tapOn(tester, find.widgetWithText(ChoiceChip, '日本語'));
      for (final tag in ['Dungeons', 'WvW', 'PvP', 'Farming']) {
        await tapOn(tester, find.widgetWithText(FilterChip, tag));
      }
      await tapOn(tester, find.text('Save'));
      expect(fake.saves.length, 1);
      expect(fake.saves.single.lookingFor, {'raids', 'fractals', 'strikes', 'casual'});
      expect(fake.saves.single.languages, {'en'});
      await settle(tester);
    });

    testWidgets('keeps a language the app has no choice for, so that it can be taken off', (tester) async {
      const p = RecruitPage(guildId: _id, gw2GuildId: 'g', name: 'M', tag: 'M', languages: ['it'], canEdit: true);
      await editor(tester, FakeRecruit(current: p));
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'IT')).selected, isTrue);
    });

    testWidgets(
        'cannot be shown to everybody until it has a headline, a description and a way to be reached, and says what it takes',
        (tester) async {
      await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      final published = find.byKey(const Key('rec-published'));
      expect(tester.widget<SwitchListTile>(published).onChanged, isNull);
      expect(
          find.text(
              'To show it to everybody it needs a headline, a description of at least 20 characters and a way to reach you.'),
          findsOneWidget);
      await fill(tester, description: 'too short');
      expect(tester.widget<SwitchListTile>(published).onChanged, isNull);
      await fill(tester);
      expect(tester.widget<SwitchListTile>(published).onChanged, isNotNull);
      expect(find.textContaining('To show it to everybody'), findsNothing, reason: 'nothing more is asked of it');
    });

    testWidgets(
        'says that a page that is shown to everybody is also posted in the forum of the official server, and not while it still lacks what it takes',
        (tester) async {
      await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      const hint =
          'It is also posted in the guild-recruitment forum of the official Discord server. Turned off, its post there is taken down.';
      expect(find.text(hint), findsNothing, reason: 'what it takes comes first');
      await fill(tester);
      expect(find.text(hint), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await editor(tester, FakeRecruit(current: _thePage(canEdit: true, isLeader: true)));
      expect(find.text(hint), findsOneWidget, reason: 'and for a page that is shown already');
    });

    testWidgets(
        'says that the post in the forum is locked while the guild is not recruiting, which is what that switch does and the one that shows the page does not',
        (tester) async {
      await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      const lock =
          'Turned off, the post of this page in the forum of the official Discord server is locked: nobody can answer it.';
      expect(find.text(lock), findsOneWidget,
          reason: 'under the switch of recruiting, always: it is there before the page is whole');
      final recruiting = find.byKey(const Key('rec-recruiting'));
      expect(find.descendant(of: recruiting, matching: find.text(lock)), findsOneWidget,
          reason: 'and it is under that switch and not under the other');
      final published = find.byKey(const Key('rec-published'));
      expect(find.descendant(of: published, matching: find.text(lock)), findsNothing);
    });

    testWidgets('is shown to everybody when the switch is on and it is saved', (tester) async {
      final fake = await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      await fill(tester);
      await tapOn(tester, find.byKey(const Key('rec-published')));
      await tapOn(tester, find.text('Save'));
      expect(fake.saves.length, 1);
      expect(fake.publishes, [true]);
      expect(fake.calls, ['save', 'publish:true'], reason: 'it is shown once it has been saved whole');
      expect(fake.current!.published, isTrue);
      await settle(tester);
    });

    testWidgets('is taken back to a draft when the switch is turned off, which can always be done', (tester) async {
      final fake = await editor(tester, FakeRecruit(current: _thePage(canEdit: true, isLeader: true)));
      await fill(tester, headline: '');
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('rec-published'))).onChanged, isNotNull,
          reason: 'though it is not whole');
      await tapOn(tester, find.byKey(const Key('rec-published')));
      await tapOn(tester, find.text('Save'));
      expect(fake.publishes, [false]);
      expect(fake.saves.length, 1);
      expect(fake.calls, ['publish:false', 'save'],
          reason:
              'taken back first: the database refuses to save a page that is shown to everybody with a headline missing');
      await settle(tester);
    });

    testWidgets('is saved without being shown again or taken back when it stays as it was, shown or not',
        (tester) async {
      final shown = await editor(tester, FakeRecruit(current: _thePage(canEdit: true, isLeader: true)));
      await tapOn(tester, find.text('Save'));
      expect(shown.calls, ['save']);
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
      final draft =
          await editor(tester, FakeRecruit(current: _thePage(canEdit: true, isLeader: true, published: false)));
      await tapOn(tester, find.text('Save'));
      expect(draft.calls, ['save']);
      await settle(tester);
    });

    testWidgets('is not sent when it is shown to everybody and no longer whole', (tester) async {
      final fake = await editor(tester, FakeRecruit(current: _thePage(canEdit: true, isLeader: true)));
      await fill(tester, headline: '');
      await tapOn(tester, find.text('Save'));
      expect(fake.saves, isEmpty);
      expect(
          find.text(
              'To show it to everybody it needs a headline, a description of at least 20 characters and a way to reach you.'),
          findsOneWidget);
      await settle(tester);
    });

    testWidgets('tells why the database refused it', (tester) async {
      final fake = await editor(tester, FakeRecruit(fail: const RecruitFailure('not_allowed')),
          guild: _mine(hasPage: false, published: false));
      await fill(tester);
      await tapOn(tester, find.text('Save'));
      expect(find.text('You may not do that for this guild.'), findsOneWidget);
      expect(fake.saves, isEmpty);
      await settle(tester);
    });

    testWidgets(
        'has no button of its own to say that the guild is still looking: saving is what keeps the page in the list',
        (tester) async {
      final fake = await editor(tester, FakeRecruit(current: _thePage(canEdit: true, isLeader: true)));
      expect(find.text('Still looking'), findsNothing);
      expect(find.text('Saving keeps the page in the list. It leaves the list after 60 days without being saved.'),
          findsOneWidget);
      await tapOn(tester, find.text('Save'));
      expect(fake.saves.length, 1, reason: 'a page that is saved as it is is saved, which is what renews it');
      expect(find.text('Saved.'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('says how a page is kept in the list, for a page that has not been made yet too', (tester) async {
      await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      expect(find.text('Saving keeps the page in the list. It leaves the list after 60 days without being saved.'),
          findsOneWidget);
    });

    testWidgets('is deleted by the leader, who is asked first', (tester) async {
      final fake = await editor(tester, FakeRecruit(current: _thePage(canEdit: true, isLeader: true)));
      await tapOn(tester, find.text('Delete the page'));
      expect(find.text("Delete this guild's recruitment page?"), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.deletes, 0);
      await tapOn(tester, find.text('Delete the page'));
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete the page')));
      await tester.pumpAndSettle();
      expect(fake.deletes, 1);
      expect(find.byKey(const Key('rec-headline')), findsNothing, reason: 'the editor is closed');
    });

    testWidgets('is not deleted by one who only manages it: there is no button', (tester) async {
      await editor(tester, FakeRecruit(current: _thePage(canEdit: true)), guild: _mine(leader: false));
      expect(find.text('Delete the page'), findsNothing);
      expect(find.text('Save'), findsOneWidget, reason: 'though they may save it, which keeps it in the list');
    });

    testWidgets('says that a moderator hid the page', (tester) async {
      await editor(tester, FakeRecruit(current: _thePage(canEdit: true, hidden: true)));
      expect(find.text('A moderator hid this page. Only those who manage it can see it.'), findsOneWidget);
    });

    testWidgets('has the region as a choice of three, and sends the one that is chosen', (tester) async {
      final fake = await editor(tester, FakeRecruit(), guild: _mine(hasPage: false, published: false));
      await tapOn(tester, find.text('North America'));
      await tapOn(tester, find.text('Save'));
      expect(fake.saves.single.region, RecruitRegion.na);
      await settle(tester);
    });
  });

  group('who may edit the page', () {
    final roster = [
      const RosterMember('u-leader', 'Leo.1', 'leader'),
      const RosterMember('u2', 'Mira.2', 'member'),
      const RosterMember('u3', 'Kai.3', 'officer'),
      const RosterMember('u4', 'Zed.4', 'member'),
    ];

    Future<FakeRecruit> open(WidgetTester tester, FakeRecruit fake) async {
      await show(tester, fake, home: RecruitersScreen(guild: _mine()), roster: roster);
      return fake;
    }

    testWidgets('says that the leader decides, and that it is not the officer\'s permission', (tester) async {
      await open(tester, FakeRecruit());
      expect(find.text('Who may edit the page · Mistwalkers [MIST]'), findsOneWidget);
      expect(find.textContaining('This is not the same as being an officer.'), findsOneWidget);
    });

    testWidgets('says that nobody has been allowed, when nobody has', (tester) async {
      await open(tester, FakeRecruit());
      expect(find.text('Nobody besides you.'), findsOneWidget);
    });

    testWidgets('lists those who were allowed, by the account they play, each with a way to take it back',
        (tester) async {
      await open(tester, FakeRecruit(allowed: [const RecruiterEntry(userId: 'u2', accountName: 'Mira.2')]));
      expect(find.text('Mira.2'), findsOneWidget);
      expect(find.text('Take it back'), findsOneWidget);
      expect(find.text('Nobody besides you.'), findsNothing);
    });

    testWidgets('takes it back, and the list is without them', (tester) async {
      final fake =
          await open(tester, FakeRecruit(allowed: [const RecruiterEntry(userId: 'u2', accountName: 'Mira.2')]));
      await tester.tap(find.text('Take it back'));
      await tester.pumpAndSettle();
      expect(fake.revokes, ['u2']);
      expect(find.text('Mira.2'), findsNothing);
      expect(find.text('Nobody besides you.'), findsOneWidget);
    });

    testWidgets('offers the members of the guild who are not its leader and were not allowed already', (tester) async {
      await open(tester, FakeRecruit(allowed: [const RecruiterEntry(userId: 'u2', accountName: 'Mira.2')]));
      await tester.tap(find.text('Allow a member'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a member'), findsOneWidget);
      expect(find.widgetWithText(SimpleDialogOption, 'Kai.3'), findsOneWidget,
          reason: 'an officer may be allowed too: it is another permission');
      expect(find.widgetWithText(SimpleDialogOption, 'Zed.4'), findsOneWidget);
      expect(find.widgetWithText(SimpleDialogOption, 'Leo.1'), findsNothing, reason: 'the leader needs no allowing');
      expect(find.widgetWithText(SimpleDialogOption, 'Mira.2'), findsNothing, reason: 'nor one who is allowed');
    });

    testWidgets('allows the member who is chosen, and the list has them', (tester) async {
      final fake = await open(tester, FakeRecruit());
      await tester.tap(find.text('Allow a member'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Zed.4'));
      await tester.pumpAndSettle();
      expect(fake.grants, ['u4']);
      expect(find.text('granted-u4'), findsOneWidget);
    });

    testWidgets('allows nobody when the dialog is closed without a choice', (tester) async {
      final fake = await open(tester, FakeRecruit());
      await tester.tap(find.text('Allow a member'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(fake.grants, isEmpty);
    });

    testWidgets('says that nobody is left to be allowed when everybody is, or is the leader', (tester) async {
      await open(
          tester,
          FakeRecruit(allowed: [
            const RecruiterEntry(userId: 'u2', accountName: 'Mira.2'),
            const RecruiterEntry(userId: 'u3', accountName: 'Kai.3'),
            const RecruiterEntry(userId: 'u4', accountName: 'Zed.4'),
          ]));
      await tester.tap(find.text('Allow a member'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SimpleDialogOption, 'Leo.1'), findsNothing);
      expect(
          find.descendant(of: find.byType(SimpleDialog), matching: find.text('Nobody besides you.')), findsOneWidget);
    });

    testWidgets('tells why the database refused to allow or to take back', (tester) async {
      final fake = FakeRecruit(
          allowed: [const RecruiterEntry(userId: 'u2', accountName: 'Mira.2')],
          fail: const RecruitFailure('not_member'));
      await open(tester, fake);
      await tester.tap(find.text('Take it back'));
      await tester.pumpAndSettle();
      expect(find.text('That player is not a member of this guild.'), findsOneWidget);
      expect(find.text('Mira.2'), findsOneWidget, reason: 'and the list is as it was');
      await settle(tester);
    });
  });

  group('the recruitment pages that were reported, for the administrator', () {
    RecruitReport report(
            {bool hidden = false,
            bool published = true,
            int reports = 2,
            String? hiddenReason,
            List<String> reasons = const ['It is spam', 'Rude']}) =>
        RecruitReport(
            guildId: _id,
            name: 'Mistwalkers',
            tag: 'MIST',
            headline: 'Raids on Thursdays',
            reports: reports,
            reasons: reasons,
            hidden: hidden,
            published: published,
            hiddenReason: hiddenReason);

    Future<FakeRecruit> panel(WidgetTester tester, FakeRecruit fake) async {
      await show(tester, fake, home: const SingleChildScrollView(child: AdminRecruitReports()));
      return fake;
    }

    testWidgets('says so when none was reported and none is hidden', (tester) async {
      await panel(tester, FakeRecruit());
      expect(find.text('No recruitment page was reported, and none is hidden.'), findsOneWidget);
    });

    testWidgets('says calmly that they could not be read, and tries again when asked', (tester) async {
      final fake = _FailingReports();
      await panel(tester, fake);
      expect(find.text('The recruitment pages could not be read.'), findsOneWidget);
      expect(find.textContaining('RecruitFailure'), findsNothing);
      final before = fake.askedReports;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(fake.askedReports, greaterThan(before));
    });

    testWidgets('shows each page with how many reported it and what they said', (tester) async {
      await panel(
          tester,
          FakeRecruit()
            ..reported = [
              report(),
              report(reports: 1, reasons: const ['Spam']).copy(name: 'Other')
            ]);
      expect(find.text('Mistwalkers [MIST]'), findsOneWidget);
      expect(find.text('Raids on Thursdays'), findsNWidgets(2));
      expect(find.text('Reported by 2 players'), findsOneWidget);
      expect(find.text('Reported by 1 player'), findsOneWidget);
      expect(find.text('“It is spam”'), findsOneWidget);
      expect(find.text('“Rude”'), findsOneWidget);
      expect(find.text('Shown'), findsNWidgets(2));
    });

    testWidgets('says that a page is a draft, and that one is hidden, and why', (tester) async {
      await panel(
          tester,
          FakeRecruit()
            ..reported = [
              report(published: false, reports: 1),
              report(hidden: true, hiddenReason: 'Spam', reports: 0, reasons: const [])
            ]);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Hidden'), findsOneWidget);
      expect(find.text('Hidden because: Spam'), findsOneWidget);
      expect(find.text('Show again'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget, reason: 'only a page that is shown can be hidden');
    });

    testWidgets('hides a page, with the reason that the guild is shown', (tester) async {
      final fake = await panel(tester, FakeRecruit()..reported = [report()]);
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(find.text('Hide this page'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('hide-reason')), '  Spam  ');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Hide')));
      await tester.pumpAndSettle();
      expect(fake.hides, [(_id, true, 'Spam')]);
      expect(find.text('Show again'), findsOneWidget, reason: 'the list is asked for again and has it hidden');
      expect(find.text('Hidden because: Spam'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('hides nothing when the dialog is closed', (tester) async {
      final fake = await panel(tester, FakeRecruit()..reported = [report()]);
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.hides, isEmpty);
    });

    testWidgets('shows a page again, with no reason', (tester) async {
      final fake = await panel(tester, FakeRecruit()..reported = [report(hidden: true, hiddenReason: 'Spam')]);
      await tester.tap(find.text('Show again'));
      await tester.pumpAndSettle();
      expect(fake.hides, [(_id, false, null)]);
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Hidden because: Spam'), findsNothing);
      await settle(tester);
    });

    testWidgets('says when it did not work', (tester) async {
      final fake = FakeRecruit(fail: const RecruitFailure('not_admin'))..reported = [report(hidden: true)];
      await panel(tester, fake);
      await tester.tap(find.text('Show again'));
      await tester.pumpAndSettle();
      expect(find.text('That did not work'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('opens the page to look at it', (tester) async {
      final fake = FakeRecruit(current: _thePage(canEdit: true, hidden: true))..reported = [report(hidden: true)];
      await panel(tester, fake);
      await tester.tap(find.text('Look'));
      await tester.pumpAndSettle();
      expect(find.text('Join their Discord'), findsOneWidget);
    });
  });
}

extension on RecruitReport {
  RecruitReport copy({String? name}) => RecruitReport(
      guildId: guildId,
      name: name ?? this.name,
      tag: tag,
      headline: headline,
      reports: reports,
      reasons: reasons,
      hidden: hidden,
      published: published,
      hiddenReason: hiddenReason);
}

/// a database whose reports cannot be read
class _FailingReports extends FakeRecruit {
  int askedReports = 0;

  @override
  Future<List<RecruitReport>> adminReports() async {
    askedReports++;
    throw const RecruitFailure('boom');
  }
}

/// a database whose list cannot be asked
class _FailingList extends FakeRecruit {
  @override
  Future<RecruitList> list(RecruitFilter filter) async => throw const RecruitFailure('boom');
}
