import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/widgets/map_tiles.dart';

void main() {
  // Queensdale on continent 1, whose tile pyramid tops out at zoom 8.
  // These numbers were checked against the live tile service: at zoom 6 the
  // covering block really is tiles x 41..45, y 27..29 and all 15 exist.
  const queensdale = [42624.0, 28032.0, 46208.0, 30464.0];

  group('layoutFor', () {
    test('picks the highest zoom that stays inside the tile budget', () {
      final layout = layoutFor(queensdale, 8);
      expect(layout.zoom, 6);
      expect(layout.column, 41);
      expect(layout.row, 27);
      expect(layout.columns, 5);
      expect(layout.rows, 3);
      expect(layout.count, 15);
    });

    test('zoom 7 would exceed the budget, which is why 6 wins', () {
      // 8 x 6 = 48 tiles, over the default 40
      expect(layoutFor(queensdale, 8, budget: 48).zoom, 7);
      expect(layoutFor(queensdale, 8, budget: 47).zoom, 6);
    });

    test('a generous budget reaches full zoom', () {
      final layout = layoutFor(queensdale, 8, budget: 1000);
      expect(layout.zoom, 8);
      expect(layout.scale, 1);
    });

    test('scale halves with every step down from the top', () {
      expect(layoutFor(queensdale, 8, budget: 1000).scale, 1);
      expect(layoutFor(queensdale, 8).scale, 4);
    });

    test('never goes below zoom 1, even with no budget at all', () {
      expect(layoutFor(queensdale, 8, budget: 0).zoom, 1);
    });

    test('block is wide enough to contain the whole map', () {
      final layout = layoutFor(queensdale, 8);
      final left = layout.column * 256 * layout.scale;
      final top = layout.row * 256 * layout.scale;
      expect(left, lessThanOrEqualTo(queensdale[0]));
      expect(top, lessThanOrEqualTo(queensdale[1]));
      expect(left + layout.width * layout.scale, greaterThanOrEqualTo(queensdale[2]));
      expect(top + layout.height * layout.scale, greaterThanOrEqualTo(queensdale[3]));
    });
  });

  group('offsetOf', () {
    test('places a point of interest where the tile service draws it', () {
      // Eda's Orchard, continent coords straight from the floor endpoint
      final at = layoutFor(queensdale, 8).offsetOf(42830.7, 28406.7);
      expect(at.dx, closeTo(211.7, 0.1));
      expect(at.dy, closeTo(189.7, 0.1));
    });

    test('the map corner lands inside the block, not at its origin', () {
      final layout = layoutFor(queensdale, 8);
      final corner = layout.offsetOf(queensdale[0], queensdale[1]);
      expect(corner.dx, inInclusiveRange(0, 256));
      expect(corner.dy, inInclusiveRange(0, 256));
    });

    test('a point further right maps further right', () {
      final layout = layoutFor(queensdale, 8);
      final a = layout.offsetOf(42830.7, 28406.7);
      final b = layout.offsetOf(45000.0, 28406.7);
      expect(b.dx, greaterThan(a.dx));
      expect(b.dy, closeTo(a.dy, 0.001));
    });
  });
}
