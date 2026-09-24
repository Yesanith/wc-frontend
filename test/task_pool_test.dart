import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/util.dart';

void main() {
  test('never runs more than its size at once', () async {
    final pool = TaskPool(3);
    var running = 0;
    var peak = 0;

    Future<int> task(int i) async {
      running++;
      if (running > peak) peak = running;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      running--;
      return i;
    }

    final results = await Future.wait([for (var i = 0; i < 20; i++) pool.run(() => task(i))]);

    expect(peak, 3);
    expect(results, [for (var i = 0; i < 20; i++) i]);
  });

  test('a failing task frees its slot', () async {
    final pool = TaskPool(1);
    await expectLater(pool.run<void>(() async => throw StateError('boom')), throwsStateError);
    expect(await pool.run(() async => 42), 42);
  });
}
