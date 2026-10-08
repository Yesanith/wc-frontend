import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session, User;
import 'package:tyria_codex/screens/open_event_screen.dart';
import 'package:tyria_codex/state/community.dart';
import 'package:tyria_codex/state/navigation.dart';
import 'package:tyria_codex/state/open_events.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/theme.dart';

const _id = '3f2a9c1e-5b7d-4e8a-9c6b-0d1e2f3a4b5c';

Session _session() => Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: const User(
          id: 'u1', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-10-03T00:00:00Z'),
    );

void main() {
  group('whether the page of an event can be shown', () {
    test('is not when the community backend is not there, whatever the session is', () {
      expect(eventAccess(ready: false, session: const AsyncData<Object?>('x')), EventAccess.unavailable);
      expect(eventAccess(ready: false, session: null), EventAccess.unavailable);
      expect(eventAccess(ready: true, session: null), EventAccess.unavailable,
          reason: 'no session to ask about is none to ask with');
    });

    test('is once there is a session', () {
      expect(eventAccess(ready: true, session: const AsyncData<Object?>('x')), EventAccess.open);
    });

    test('waits while the session is being read, and says to sign in when it was read and there is none', () {
      expect(eventAccess(ready: true, session: const AsyncLoading<Object?>()), EventAccess.waiting);
      expect(eventAccess(ready: true, session: const AsyncData<Object?>(null)), EventAccess.signInNeeded);
      expect(eventAccess(ready: true, session: const AsyncError<Object?>('x', StackTrace.empty)),
          EventAccess.signInNeeded);
    });

    test('is open while a session is there even if it is being read again', () {
      expect(
          eventAccess(
              ready: true, session: const AsyncLoading<Object?>().copyWithPrevious(const AsyncData<Object?>('x'))),
          EventAccess.open);
    });
  });

  group('the page of an event', () {
    late List<String> asked;
    late List<String> copied;

    setUp(() {
      asked = [];
      copied = [];
      debugSetCommunityReady(true);
    });

    tearDown(() => debugSetCommunityReady(false));

    Future<ProviderContainer> show(
      WidgetTester tester, {
      required Stream<Session?> session,
      OpenEvent? event,
      String eventId = _id,
    }) async {
      tester.view.physicalSize = const Size(1000, 1800);
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
        sessionProvider.overrideWith((ref) => session),
        openEventProvider.overrideWith((ref, id) async {
          asked.add(id);
          return event;
        }),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(), home: OpenEventScreen(eventId: eventId)),
      ));
      return container;
    }

    testWidgets('says that events are not here when the community backend is not, and asks the database nothing',
        (tester) async {
      debugSetCommunityReady(false);
      await show(tester, session: Stream.value(null));
      await tester.pumpAndSettle();
      expect(find.text('Public events are not available in this build.'), findsOneWidget);
      expect(asked, isEmpty);
    });

    testWidgets(
        'tells a guest who followed a link to sign in, with the way to the settings, and asks the database nothing',
        (tester) async {
      await show(tester, session: Stream.value(null));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Discord in Settings to see public events and make your own.'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(asked, isEmpty, reason: 'what the database would refuse (42501) is not asked of it');
      expect(find.textContaining('OpenEventFailure'), findsNothing, reason: 'and no raw failure is shown');
      expect(find.textContaining('went wrong'), findsNothing);
    });

    testWidgets('closes the page and opens the settings from the guest\'s button', (tester) async {
      final container = await show(tester, session: Stream.value(null));
      await tester.pumpAndSettle();
      expect(container.read(sectionProvider), isNot(AppSection.settings));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(container.read(sectionProvider), AppSection.settings);
    });

    testWidgets(
        'waits while the session is read, and neither asks the database nor tells the player to sign in meanwhile',
        (tester) async {
      final never = StreamController<Session?>();
      addTearDown(never.close);
      await show(tester, session: never.stream);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Sign in'), findsNothing);
      expect(asked, isEmpty);
    });

    testWidgets('goes on to the event when the session arrives after a wait', (tester) async {
      final delayed = StreamController<Session?>();
      addTearDown(delayed.close);
      await show(tester, session: delayed.stream);
      await tester.pump();
      expect(asked, isEmpty);
      delayed.add(_session());
      await tester.pumpAndSettle();
      expect(asked, [_id]);
      expect(find.text('That event is not there any more.'), findsOneWidget);
    });

    testWidgets('asks the database for the event once there is a session, and says when it is not there any more',
        (tester) async {
      await show(tester, session: Stream.value(_session()));
      await tester.pumpAndSettle();
      expect(asked, [_id]);
      expect(find.text('That event is not there any more.'), findsOneWidget);
      expect(find.textContaining('Sign in'), findsNothing);
    });

    testWidgets('has the button that copies the address of the event, for an event that has one', (tester) async {
      await show(tester, session: Stream.value(null));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Copy link to this page'), findsOneWidget,
          reason: 'also for a guest: the address is what is shared');
      await tester.tap(find.byTooltip('Copy link to this page'));
      await tester.pump();
      expect(copied, ['https://yesanith.github.io/tyria-companion/app/#/event/$_id']);
      // the notice that it was copied goes away by itself after a few seconds: let it, a timer that is pending is a test that did not end
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('has no such button for a number that is no event\'s, so that no address is made of it',
        (tester) async {
      await show(tester, session: Stream.value(null), eventId: 'not-an-event');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Copy link to this page'), findsNothing);
    });
  });
}
