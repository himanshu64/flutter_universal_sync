/// An access token (with optional refresh token and expiry) cached locally so
/// the app keeps a usable identity while offline.
class AuthToken {
  /// Creates a token. A null [expiresAt] means it does not expire.
  const AuthToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  /// Rebuilds a token from its [toJson] map.
  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                json['expiresAt'] as int,
                isUtc: true,
              ),
      );

  /// The bearer access token sent to the backend.
  final String accessToken;

  /// Token used to obtain a fresh [accessToken], if the backend issues one.
  final String? refreshToken;

  /// When [accessToken] stops being valid (UTC), or null if it never expires.
  final DateTime? expiresAt;

  /// Whether the token is expired at [now].
  bool isExpiredAt(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  /// A JSON-encodable map for persistence in a [TokenStore].
  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt?.toUtc().millisecondsSinceEpoch,
      };
}
