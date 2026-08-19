class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.message,
    this.expiresAt,
  });

  static const String otpSentMessage =
      'Nếu email tồn tại trong hệ thống, mã OTP đã được gửi đến hộp thư của bạn.';

  final String message;
  final DateTime? expiresAt;

  String get displayMessage =>
      message.trim().isNotEmpty ? message.trim() : otpSentMessage;

  factory ForgotPasswordResult.fromJson(Map<String, dynamic> json) {
    final rawExpires = json['expiresAt'];
    DateTime? expiresAt;
    if (rawExpires != null) {
      if (rawExpires is int) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(rawExpires);
      } else {
        expiresAt = DateTime.tryParse(rawExpires.toString());
      }
    }

    return ForgotPasswordResult(
      message: (json['message'] ?? '').toString(),
      expiresAt: expiresAt,
    );
  }
}
