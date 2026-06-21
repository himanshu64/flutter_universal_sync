import 'package:flutter_universal_sync_crdt/flutter_universal_sync_crdt.dart';
import 'package:test/test.dart';

void main() {
  const r = LwwMapResolver();

  Map<String, dynamic> values(Map<String, dynamic> row) =>
      {...row}..remove('_lww');

  test('keeps both edits when different fields changed (the CRDT win)', () {
    // local changed name at t2; remote changed email at t2.
    final local = {
      'id': '1',
      'name': 'Alice', // newer
      'email': 'old@x',
      '_lww': {'name': 2000, 'email': 1000},
    };
    final remote = {
      'id': '1',
      'name': 'alice',
      'email': 'new@y', // newer
      '_lww': {'name': 1000, 'email': 2000},
    };
    final merged = r.resolve(local, remote);
    expect(merged['name'], 'Alice');
    expect(merged['email'], 'new@y');
  });

  test('keeps fields present on only one side', () {
    final local = {
      'id': '1',
      'onlyLocal': 'L',
      '_lww': {'onlyLocal': 1000}
    };
    final remote = {
      'id': '1',
      'onlyRemote': 'R',
      '_lww': {'onlyRemote': 1000}
    };
    final merged = r.resolve(local, remote);
    expect(merged['onlyLocal'], 'L');
    expect(merged['onlyRemote'], 'R');
  });

  test('same-field conflict resolves to the higher timestamp', () {
    final local = {
      'id': '1',
      'v': 'old',
      '_lww': {'v': 1000}
    };
    final remote = {
      'id': '1',
      'v': 'new',
      '_lww': {'v': 2000}
    };
    expect(r.resolve(local, remote)['v'], 'new');
  });

  test('falls back to updated_at when there is no per-field clock', () {
    final local = {'id': '1', 'v': 'old', 'updated_at': 1000};
    final remote = {'id': '1', 'v': 'new', 'updated_at': 2000};
    expect(r.resolve(local, remote)['v'], 'new');
  });

  test('is commutative: resolve(a,b) and resolve(b,a) converge', () {
    final a = {
      'id': '1',
      'name': 'A',
      'email': 'a@x',
      '_lww': {'name': 3000, 'email': 1000},
    };
    final b = {
      'id': '1',
      'name': 'b',
      'email': 'b@y',
      '_lww': {'name': 2000, 'email': 5000},
    };
    expect(values(r.resolve(a, b)), values(r.resolve(b, a)));
  });

  test('is idempotent: resolve(a,a) == a', () {
    final a = {
      'id': '1',
      'name': 'x',
      '_lww': {'name': 1000}
    };
    expect(values(r.resolve(a, a)), values(a));
  });

  test('equal timestamps break ties deterministically (order-independent)', () {
    final a = {
      'id': '1',
      'v': 'apple',
      '_lww': {'v': 1000}
    };
    final b = {
      'id': '1',
      'v': 'banana',
      '_lww': {'v': 1000}
    };
    expect(r.resolve(a, b)['v'], r.resolve(b, a)['v']);
  });

  test('stamp sets a per-field clock and skips id/clock fields', () {
    final stamped = r.stamp(
      {'id': '1', 'name': 'x', 'qty': 3},
      DateTime.utc(2026, 1, 1),
    );
    final clock = stamped['_lww'] as Map;
    final ms = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    expect(clock['name'], ms);
    expect(clock['qty'], ms);
    expect(clock.containsKey('id'), isFalse);
  });

  test('merged clock is the per-field max (associativity-friendly)', () {
    final local = {
      'id': '1',
      'v': 'l',
      '_lww': {'v': 1000}
    };
    final remote = {
      'id': '1',
      'v': 'r',
      '_lww': {'v': 2000}
    };
    final merged = r.resolve(local, remote);
    expect((merged['_lww'] as Map)['v'], 2000);
  });
}
