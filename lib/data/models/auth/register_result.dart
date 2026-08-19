class RegisterResult {
  const RegisterResult({
    required this.id,
    this.email,
    this.phone,
    required this.requiresVerification,
  });

  final String id;
  final String? email;
  final String? phone;
  final bool requiresVerification;

  factory RegisterResult.fromJson(Map<String, dynamic> json) {
    return RegisterResult(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      requiresVerification: json['requiresVerification'] as bool? ?? true,
    );
  }
}
