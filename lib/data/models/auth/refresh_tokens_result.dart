class RefreshTokensResult {
  const RefreshTokensResult({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory RefreshTokensResult.fromJson(Map<String, dynamic> json) {
    return RefreshTokensResult(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
    );
  }
}
