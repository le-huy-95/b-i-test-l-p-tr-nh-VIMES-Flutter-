class TenantMember {
  const TenantMember({
    required this.id,
    required this.userId,
    required this.role,
    required this.isActive,
    required this.joinedAt,
    this.name,
    this.email,
    this.phone,
  });

  final String id;
  final String userId;
  final String? name;
  final String? email;
  final String? phone;
  final String role;
  final bool isActive;
  final DateTime joinedAt;

  factory TenantMember.fromJson(Map<String, dynamic> json) {
    return TenantMember(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: (json['role'] ?? '').toString(),
      isActive: json['isActive'] == true,
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CreateTenantUserResult {
  const CreateTenantUserResult({
    required this.id,
    required this.role,
    this.email,
    this.phone,
  });

  final String id;
  final String? email;
  final String? phone;
  final String role;

  factory CreateTenantUserResult.fromJson(Map<String, dynamic> json) {
    return CreateTenantUserResult(
      id: (json['id'] ?? '').toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: (json['role'] ?? '').toString(),
    );
  }
}

class TenantMemberPageResult {
  const TenantMemberPageResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<TenantMember> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory TenantMemberPageResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final items = <TenantMember>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          items.add(TenantMember.fromJson(item));
        } else if (item is Map) {
          items.add(TenantMember.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final pagination = json['pagination'];
    final paginationMap = pagination is Map<String, dynamic>
        ? pagination
        : pagination is Map
            ? Map<String, dynamic>.from(pagination)
            : const <String, dynamic>{};

    return TenantMemberPageResult(
      items: items,
      page: (paginationMap['page'] as num?)?.toInt() ?? 1,
      limit: (paginationMap['limit'] as num?)?.toInt() ?? items.length,
      total: (paginationMap['total'] as num?)?.toInt() ?? items.length,
      totalPages: (paginationMap['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}
