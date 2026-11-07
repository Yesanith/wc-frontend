import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/community.dart';
import 'package:wondrous_compass/widgets/account_badge.dart';

void main() {
  test('the game accounts are the first and how many more', () {
    expect(linkedAccountsLabel(const []), '');
    expect(linkedAccountsLabel(const ['Leo.1234']), 'Leo.1234');
    expect(linkedAccountsLabel(const ['Leo.1234', 'Mira.5678', 'Kai.9012']), 'Leo.1234 +2');
  });

  test('the address a sign in that went wrong came back to is told apart', () {
    expect(hasAuthError(Uri.parse('https://x.example/app/?error=invalid_request&error_code=bad_oauth_state#/settings')), isTrue);
    expect(hasAuthError(Uri.parse('https://x.example/app/#/settings')), isFalse);
    expect(hasAuthError(Uri.parse('https://x.example/app/?code=abc')), isFalse);
  });

  test('without the profile, the name and the picture Discord gave the session', () {
    expect(sessionIdentity(null), (name: null, avatar: null));
  });

  testWidgets('a build without the community backend has nothing at the top of the menu', (tester) async {
    debugSetCommunityReady(false);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: AccountBadge(onOpen: () {}))),
    ));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
  });
}
