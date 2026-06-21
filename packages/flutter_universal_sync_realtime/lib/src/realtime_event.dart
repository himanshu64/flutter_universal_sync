/// The kind of change a [RealtimeEvent] represents.
enum RealtimeEventType {
  /// A row was inserted or updated on the server.
  upsert,

  /// A row was deleted on the server (carry a tombstone row with `deleted_at`).
  delete,
}

/// A decoded server-push event: a row changed on the backend.
///
/// Your transport (WebSocket, SSE, Firestore listener, …) decodes its frames
/// into these; the [RealtimeChannel] applies them. A [row] may be `null` for a
/// pure signal ("something changed, go pull") handled via a custom `onEvent`.
class RealtimeEvent {
  /// Creates an event for [table] of kind [type], optionally carrying [row].
  RealtimeEvent({required this.table, required this.type, this.row});

  /// Table the changed row belongs to.
  final String table;

  /// Whether the row was upserted or deleted.
  final RealtimeEventType type;

  /// The server's view of the row (including sync metadata), or `null` for a
  /// signal-only event.
  final Map<String, dynamic>? row;
}
