/// Connectivity classification richer than a simple online/offline bool.
///
/// Distinguishing a metered (cellular) link from an unmetered (Wi-Fi/Ethernet)
/// one lets sync defer heavy work — bulk pulls, attachment uploads — until the
/// device is on an unmetered network.
enum NetworkState {
  /// No usable connection (interface down, or a reachability probe failed).
  offline,

  /// Online over a metered link (typically cellular).
  metered,

  /// Online over an unmetered link (Wi-Fi / Ethernet).
  unmetered;

  /// Whether there is any usable connection.
  bool get isOnline => this != NetworkState.offline;

  /// Whether the connection is metered (callers may defer heavy transfers).
  bool get isMetered => this == NetworkState.metered;
}
