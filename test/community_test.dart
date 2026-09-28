import 'package:flutter_test/flutter_test.dart';
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
}
