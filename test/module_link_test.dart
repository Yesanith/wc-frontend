import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/module_link.dart';

void main() {
  test('links are read, the ones that are not links are left out', () {
    final links = parseModuleLinks([
      {'id': 'a', 'label': ' Desk ', 'created_at': '2026-10-01T10:00:00Z', 'last_used_at': '2026-10-02T10:00:00Z'},
      {'id': 'b', 'label': '', 'created_at': '2026-10-01T10:00:00Z', 'last_used_at': null},
      {'id': '', 'created_at': '2026-10-01T10:00:00Z'},
      {'id': 'c', 'created_at': 'nonsense'},
      'text',
    ]);
    expect(links.map((l) => l.id), ['a', 'b']);
    expect(links[0].label, 'Desk');
    expect(links[0].lastUsedAt, isNotNull);
    expect(links[1].label, 'Blish HUD');
    expect(links[1].lastUsedAt, isNull);
  });

  test('anything but a list is no links', () {
    expect(parseModuleLinks(null), isEmpty);
    expect(parseModuleLinks({'a': 1}), isEmpty);
  });

  test('a code is read with when it runs out', () {
    final code = parseModuleLinkCode({'code': 'ABCD-EFGH', 'expires_at': '2026-10-01T10:10:00Z'});
    expect(code?.code, 'ABCD-EFGH');
    expect(code?.expiresAt.toUtc(), DateTime.utc(2026, 10, 1, 10, 10));
    expect(parseModuleLinkCode({'code': ''}), isNull);
    expect(parseModuleLinkCode('x'), isNull);
  });
}
