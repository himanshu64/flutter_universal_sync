/// Real-time server-push channel for the `flutter_universal_sync` family.
///
/// [RealtimeChannel] keeps a transport-agnostic event subscription alive
/// (reconnecting with backoff) and applies incoming [RealtimeEvent]s to a local
/// store or a custom handler — complementing the engine's poll/pull sync with
/// live updates.
library;

export 'src/realtime_channel.dart';
export 'src/realtime_event.dart';
