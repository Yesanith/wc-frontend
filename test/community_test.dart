import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/services/push.dart';
import 'package:tyria_codex/state/community.dart';

void main() {
  test('a build without the backend values keeps the community account off', () async {
    // tests run without --dart-define, like a local or forked build
    expect(communityConfigured, isFalse);
    await initCommunity();
    expect(communityReady, isFalse);
  });

  test('the sign in callback is a valid custom scheme', () {
    final uri = Uri.parse(authRedirect);
    // custom schemes may not contain underscores
    expect(RegExp(r'^[a-z][a-z0-9+.-]*$').hasMatch(uri.scheme), isTrue);
    expect(uri.host, 'login-callback');
  });

  test('subtokens expire ten minutes later, in whole utc seconds', () {
    expect(subtokenExpiry(DateTime.utc(2026, 9, 28, 20, 5, 30, 123)), '2026-09-28T20:15:30Z');
    expect(subtokenExpiry(DateTime.utc(2026, 12, 31, 23, 55)), '2027-01-01T00:05:00Z');
  });

  test('a build without firebase values keeps notifications off', () async {
    expect(pushConfigured, isFalse);
    await initPush();
    expect(pushReady, isFalse);
    // turning them on quietly does nothing rather than failing
    expect(await enablePush('en'), isFalse);
  });
}
