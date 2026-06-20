import 'package:objectbox/objectbox.dart';

/// The single generic ObjectBox entity the adapter persists everything in.
///
/// ObjectBox is strongly typed, so rather than one entity per user table we
/// model every stored fact — domain rows, queue entries, and meta KV pairs —
/// as a [SyncRecord], discriminated by [kind]:
///
/// - `row` — a domain-table row. [table] is the user table name, [key] is the
///   row id, and [dataJson] is the JSON-encoded row map.
/// - `queue` — a sync-queue entry. [table]/[entityId] mirror the entry, [key]
///   is the queue id, [dataJson] is the JSON-encoded payload, and the queue
///   bookkeeping lives in [synced]/[createdAt]/[retryCount]/[lastError]/
///   [operation]/[nextRetryAt].
/// - `meta` — an engine `_sync_meta` KV pair. [key] is the meta key and
///   [dataJson] is the raw string value.
///
/// The adapter satisfies every interface method by querying [SyncRecord]s with
/// conditions on [kind]/[table]/[key].
@Entity()
class SyncRecord {
  /// Creates a record. ObjectBox requires a default-constructible entity, so
  /// every field has a default and [obxId] stays `0` until the store assigns
  /// one on `put`.
  SyncRecord({
    this.obxId = 0,
    this.kind = '',
    this.table = '',
    this.key = '',
    this.entityId = '',
    this.dataJson = '',
    this.synced = false,
    this.createdAt = 0,
    this.retryCount = 0,
    this.lastError,
    this.operation = '',
    this.nextRetryAt,
  });

  /// ObjectBox-assigned primary key. Not a sync identifier.
  @Id()
  int obxId;

  /// Discriminator: `row`, `queue`, or `meta`.
  @Index()
  String kind;

  /// User table name (for `row`/`queue`) or empty (for `meta`).
  @Index()
  String table;

  /// Row id, queue id, or meta key depending on [kind].
  @Index()
  String key;

  /// The synced entity id a `queue` record targets. Empty otherwise.
  @Index()
  String entityId;

  /// JSON-encoded row map / queue payload, or raw meta string value.
  String dataJson;

  /// Queue-only: `true` once the push has been acknowledged.
  bool synced;

  /// Queue-only: enqueue time, millisecondsSinceEpoch UTC. Used for ordering.
  int createdAt;

  /// Queue-only: number of failed push attempts.
  int retryCount;

  /// Queue-only: last push error message, if any.
  String? lastError;

  /// Queue-only: the [SyncOperation] name (`insert`/`update`/`delete`).
  String operation;

  /// Queue-only: backoff timestamp, millisecondsSinceEpoch UTC, or `null`.
  int? nextRetryAt;
}
