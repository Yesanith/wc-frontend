import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/admin.dart';

void main() {
  group('what a feed\'s last failure means', () {
    test('is said for the codes the sync function records, with what to do and the code itself', () {
      final permissions = feedProblemText('missing_permissions');
      expect(permissions, contains('View Channel, Send Messages and Embed Links'));
      expect(permissions, endsWith('(missing_permissions)'), reason: 'the code stays, to be looked up');
      expect(feedProblemText('channel_gone'), contains('channel of this feed is gone'));
      expect(feedProblemText('rate_limited'), contains('limiting how fast'));
      expect(feedProblemText('source_unreachable'), contains('did not answer'));
      expect(feedProblemText('roles_failed'), contains('roles'));
      expect(feedProblemText('threads_failed'), contains('thread'));
      expect(feedProblemText('events_failed'), contains('Discord event'));
    });

    test('is the code as it is when it is none of those, so that nothing is lost', () {
      expect(feedProblemText('something_new'), 'something_new');
      expect(feedProblemText(''), '');
    });
  });
}
