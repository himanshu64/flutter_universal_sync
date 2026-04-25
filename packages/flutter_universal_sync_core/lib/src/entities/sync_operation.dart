/// The kind of mutation a queued sync entry represents.
///
/// The string [name] is persisted in the local sync queue and must remain
/// stable across versions — changing an existing value is a breaking change.
enum SyncOperation {
  /// Insert a new remote entity locally.
  insert,

  /// Update an existing remote entity locally.
  update,

  /// Delete an existing remote entity locally.
  delete,
}
