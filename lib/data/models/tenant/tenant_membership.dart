class TenantMembership {
  const TenantMembership({
    required this.id,
    required this.code,
    required this.name,
    required this.role,
    this.status,
    this.logoUrl,
  });

  final String id;
  final String code;
  final String name;
  final String role;
  final String? status;
  final String? logoUrl;

  factory TenantMembership.fromJson(Map<String, dynamic> json) {
    return TenantMembership(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      status: json['status']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'role': role,
        if (status != null) 'status': status,
        if (logoUrl != null) 'logoUrl': logoUrl,
      };
}
