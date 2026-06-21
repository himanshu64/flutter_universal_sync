import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:hive/hive.dart';

/// A Hive-backed [LocalDatabaseAdapter].
///
/// Hive is schemaless, so this adapter mirrors the in-memory reference
/// implementation: each domain table, the sync queue, and the engine
/// `_sync_meta` KV are Hive boxes of JSON-encoded values. Because Hive has
/// no transactions, [transaction] snapshots the touched boxes and restores
/// them if the action throws.
///
/// Schema is tracked in memory (Hive can't introspect "columns"); call
/// [registerTable] for each domain table before [validateSchema], the same
/// way the shared contract suite does.
class HiveSyncAdapter implements LocalDatabaseAdapter {
  /// Creates an adapter whose Hive data lives under [directory].
  ///
  /// Pass a 32-byte [encryptionKey] to store every box (domain rows, the sync
  /// queue, and meta) AES-256 encrypted at rest. Keep that key in secure
  /// storage (Keychain / Keystore via `flutter_secure_storage`), never in code.
  HiveSyncAdapter({required this.directory, List<int>? encryptionKey})
      : _cipher = encryptionKey == null ? null : HiveAesCipher(encryptionKey);

  /// Filesystem directory Hive initialises against.
  final String directory;

  final HiveCipher? _cipher;

  static const _queueBox = '__sync_queue';
  static const _metaBox = '__sync_meta';

  final Map<String, Box<String>> _boxes = {};
  final Map<String, Set<String>> _schemas = {};
  late Box<String> _queue;
  late Box<String> _meta;
  bool _inTxn = false;
  // Monotonic insertion sequence — Hive box iteration order is not stable,
  // so queue order is reconstructed by sorting on this. Reloaded on init.
  int _seq = 0;

  /// Registers [columns] as the schema for [table] (used by
  /// [validateSchema]). The contract suite calls this before validating.
  void registerTable(String table, Iterable<String> columns) {
    _schemas[table] = columns.toSet();
  }

  @override
  Future<void> init() async {
    Hive.init(directory);
    _queue = await Hive.openBox<String>(_queueBox, encryptionCipher: _cipher);
    _meta = await Hive.openBox<String>(_metaBox, encryptionCipher: _cipher);
    _boxes[_queueBox] = _queue;
    _boxes[_metaBox] = _meta;
    // Resume the sequence past anything already persisted.
    var maxSeq = -1;
    for (final s in _queue.values) {
      final seq = _decode(s)['_seq'] as int;
      if (seq > maxSeq) maxSeq = seq;
    }
    _seq = maxSeq + 1;
  }

  @override
  Future<void> close() async {
    await Hive.close();
    _boxes.clear();
  }

  Future<Box<String>> _domainBox(String table) async {
    final name = 'dom_$table';
    final existing = _boxes[name];
    if (existing != null) return existing;
    final box = await Hive.openBox<String>(name, encryptionCipher: _cipher);
    _boxes[name] = box;
    return box;
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    final box = await _domainBox(table);
    final id = data[SyncColumns.id] as String;
    if (box.containsKey(id)) {
      throw StateError('Row $id already exists in $table');
    }
    await box.put(id, jsonEncode(data));
  }

  @override
  Future<void> update(
      String table, String id, Map<String, dynamic> data) async {
    final box = await _domainBox(table);
    final cur = box.get(id);
    if (cur == null) throw StateError('Row $id not found in $table');
    final row = _decode(cur)..addAll(data);
    await box.put(id, jsonEncode(row));
  }

  @override
  Future<void> delete(String table, String id) async {
    final box = await _domainBox(table);
    final cur = box.get(id);
    if (cur == null) throw StateError('Row $id not found in $table');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final row = _decode(cur)
      ..[SyncColumns.deletedAt] = now
      ..[SyncColumns.updatedAt] = now
      ..[SyncColumns.isSynced] = 0
      ..[SyncColumns.syncStatus] = 'pending';
    await box.put(id, jsonEncode(row));
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final box = await _domainBox(table);
    final id = data[SyncColumns.id] as String;
    final cur = box.get(id);
    if (cur == null) {
      await box.put(id, jsonEncode(data));
    } else {
      final row = _decode(cur)..addAll(data);
      await box.put(id, jsonEncode(row));
    }
  }

  @override
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final box = await _domainBox(table);
    final cur = box.get(id);
    return cur == null ? null : _decode(cur);
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    bool includeDeleted = false,
  }) async {
    final box = await _domainBox(table);
    final rows = box.values.map(_decode);
    final iter = includeDeleted
        ? rows
        : rows.where((r) => r[SyncColumns.deletedAt] == null);
    return iter.toList();
  }

  @override
  Future<void> enqueueSync(SyncQueueEntry entry) async {
    await _queue.put(entry.id, _wrap(_seq++, entry));
  }

  @override
  Future<List<SyncQueueEntry>> pendingSyncEntries({
    int? limit,
    DateTime? readyAt,
  }) async {
    bool ready(SyncQueueEntry e) {
      if (readyAt == null) return true;
      final r = e.nextRetryAt;
      return r == null || !r.isAfter(readyAt);
    }

    final ordered = _queue.values.map(_unwrap).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final pending = ordered
        .map((x) => x.entry)
        .where((e) => !e.synced && ready(e))
        .toList();
    if (limit == null || limit >= pending.length) return pending;
    return pending.sublist(0, limit);
  }

  @override
  Future<List<SyncQueueEntry>> pendingForEntity(
    String table,
    String entityId,
  ) async {
    return _queue.values
        .map((s) => _unwrap(s).entry)
        .where((e) => !e.synced && e.table == table && e.entityId == entityId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> markSynced(String queueEntryId) async {
    final cur = _queue.get(queueEntryId);
    if (cur == null) throw StateError('Queue entry $queueEntryId not found');
    final w = _unwrap(cur);
    await _queue.put(
      queueEntryId,
      _wrap(w.seq, w.entry.copyWith(synced: true, lastError: null)),
    );
  }

  @override
  Future<void> recordSyncFailure(
    String queueEntryId,
    String error, {
    DateTime? nextRetryAt,
    bool incrementRetryCount = true,
  }) async {
    final cur = _queue.get(queueEntryId);
    if (cur == null) throw StateError('Queue entry $queueEntryId not found');
    final w = _unwrap(cur);
    await _queue.put(
      queueEntryId,
      _wrap(
        w.seq,
        w.entry.copyWith(
          lastError: error,
          retryCount:
              incrementRetryCount ? w.entry.retryCount + 1 : w.entry.retryCount,
          nextRetryAt: nextRetryAt,
        ),
      ),
    );
  }

  @override
  Future<void> rewriteQueuePayload(
    String entryId,
    Map<String, dynamic> payload,
  ) async {
    final cur = _queue.get(entryId);
    if (cur == null) throw StateError('Queue entry $entryId not found');
    final w = _unwrap(cur);
    await _queue.put(
      entryId,
      _wrap(
          w.seq, w.entry.copyWith(payload: Map<String, dynamic>.from(payload))),
    );
  }

  @override
  Future<String?> getMeta(String key) async => _meta.get(key);

  @override
  Future<void> setMeta(String key, String value) async {
    await _meta.put(key, value);
  }

  @override
  Future<void> deleteMeta(String key) async {
    await _meta.delete(key);
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_inTxn) return action(); // no nesting
    _inTxn = true;
    final snapshots = <String, Map<String, String>>{
      for (final e in _boxes.entries)
        e.key: Map<String, String>.from(e.value.toMap().cast()),
    };
    try {
      final result = await action();
      _inTxn = false;
      return result;
    } catch (_) {
      // Restore every box (including any opened during the action, whose
      // pre-state was empty) to its snapshot.
      for (final e in _boxes.entries) {
        await e.value.clear();
        final snap = snapshots[e.key];
        if (snap != null) await e.value.putAll(snap);
      }
      _inTxn = false;
      rethrow;
    }
  }

  @override
  Future<void> validateSchema(List<String> tables) async {
    for (final table in tables) {
      final declared = _schemas[table] ?? const <String>{};
      final missing =
          SyncColumns.required.where((c) => !declared.contains(c)).toList();
      if (missing.isNotEmpty) {
        throw SchemaValidationException(table: table, missingColumns: missing);
      }
    }
  }

  Map<String, dynamic> _decode(String s) =>
      Map<String, dynamic>.from(jsonDecode(s) as Map);

  /// Wraps a queue entry with its insertion [seq] for stable ordering.
  String _wrap(int seq, SyncQueueEntry e) =>
      jsonEncode({'_seq': seq, 'e': e.toMap()});

  ({int seq, SyncQueueEntry entry}) _unwrap(String s) {
    final m = _decode(s);
    return (
      seq: m['_seq'] as int,
      entry: SyncQueueEntry.fromMap(Map<String, dynamic>.from(m['e'] as Map)),
    );
  }
}
