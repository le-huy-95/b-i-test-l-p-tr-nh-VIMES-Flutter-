class User {
  const User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.isPlatformAdmin = false,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final bool emailVerified;
  final bool phoneVerified;
  final bool isPlatformAdmin;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['fullName'] ?? 'User').toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      emailVerified: json['emailVerified'] as bool? ?? false,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      isPlatformAdmin: json['isPlatformAdmin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'emailVerified': emailVerified,
        'phoneVerified': phoneVerified,
        'isPlatformAdmin': isPlatformAdmin,
      };
}
