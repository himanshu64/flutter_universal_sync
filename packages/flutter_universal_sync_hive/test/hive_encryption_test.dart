import 'dart:io';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_hive/flutter_universal_sync_hive.dart';
import 'package:test/test.dart';

void main() {
  final cols = [...SyncColumns.required, 'name'];

  Map<String, dynamic> row(String id, String name) => {
        SyncColumns.id: id,
        'name': name,
        SyncColumns.createdAt: 1,
        SyncColumns.updatedAt: 1,
        SyncColumns.deletedAt: null,
        SyncColumns.isSynced: 1,
        SyncColumns.syncStatus: 'synced',
      };

  test('AES-encrypts at rest and round-trips across reopen', () async {
    final dir = Directory.systemTemp.createTempSync('hive_enc').path;
    final key = List<int>.generate(32, (i) => (i * 7) % 256);

    final a = HiveSyncAdapter(directory: dir, encryptionKey: key)
      ..registerTable('things', cols);
    await a.init();
    await a.upsert('things', row('1', 'top-secret-value'));
    await a.close();

    // The on-disk box must NOT contain the plaintext.
    final bytes = await File('$dir/dom_things.hive').readAsBytes();
    expect(
      String.fromCharCodes(bytes).contains('top-secret-value'),
      isFalse,
      reason: 'plaintext leaked to disk — data is not encrypted',
    );

    // Reopening with the same key decrypts it.
    final b = HiveSyncAdapter(directory: dir, encryptionKey: key);
    await b.init();
    final read = await b.getById('things', '1');
    expect(read, isNotNull);
    expect(read!['name'], 'top-secret-value');
    await b.close();
  });
}
