class InvitationInviter {
  const InvitationInviter({required this.id, this.name, this.email});

  final String id;
  final String? name;
  final String? email;

  factory InvitationInviter.fromJson(Map<String, dynamic> json) {
    return InvitationInviter(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

class TenantInvitation {
  const TenantInvitation({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.direction,
    required this.tenantId,
    required this.tenantName,
    required this.expiresAt,
    required this.invitedAt,
    required this.invitedBy,
    this.inviteLink,
    this.token,
  });

  final String id;
  final String email;
  final String role;
  final String status;
  final String direction;
  final String tenantId;
  final String tenantName;
  final DateTime expiresAt;
  final DateTime invitedAt;
  final InvitationInviter invitedBy;
  final String? inviteLink;
  final String? token;

  bool get isExpired =>
      status == 'expired' || expiresAt.isBefore(DateTime.now());

  bool get isIncoming => direction == 'incoming';

  bool get isOutgoing => direction == 'outgoing';

  bool get isPending => status == 'pending';

  bool get isAccepted => status == 'accepted';

  bool get isDeclined =>
      status == 'declined' || status == 'rejected' || status == 'cancelled';

  String get statusLabel {
    if (isAccepted) return 'Đã chấp nhận';
    if (isDeclined) return 'Đã từ chối';
    if (isExpired) return 'Hết hạn';
    return isIncoming ? 'Từ tổ chức khác' : 'Đã gửi đi';
  }

  TenantInvitation copyWith({String? status}) {
    return TenantInvitation(
      id: id,
      email: email,
      role: role,
      status: status ?? this.status,
      direction: direction,
      tenantId: tenantId,
      tenantName: tenantName,
      expiresAt: expiresAt,
      invitedAt: invitedAt,
      invitedBy: invitedBy,
      inviteLink: inviteLink,
      token: token,
    );
  }

  String? get acceptedToken {
    if (token != null && token!.trim().isNotEmpty) return token!.trim();
    final link = inviteLink?.trim();
    if (link == null || link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    final queryToken = uri?.queryParameters['token'];
    if (queryToken != null && queryToken.trim().isNotEmpty) {
      return queryToken.trim();
    }
    return null;
  }

  bool get canAccept => isIncoming && !isExpired && isPending;
  bool get canDecline => isIncoming && !isExpired && isPending;

  factory TenantInvitation.fromJson(Map<String, dynamic> json) {
    final inviter = json['invitedBy'];
    return TenantInvitation(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      direction: (json['direction'] ?? 'outgoing').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      tenantName: (json['tenantName'] ?? '').toString(),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      invitedAt:
          DateTime.tryParse(json['invitedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      invitedBy: inviter is Map<String, dynamic>
          ? InvitationInviter.fromJson(inviter)
          : inviter is Map
          ? InvitationInviter.fromJson(Map<String, dynamic>.from(inviter))
          : const InvitationInviter(id: ''),
      inviteLink: json['inviteLink']?.toString(),
      token: json['token']?.toString(),
    );
  }
}

class TenantInvitationPageResult {
  const TenantInvitationPageResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<TenantInvitation> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory TenantInvitationPageResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final items = <TenantInvitation>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          items.add(TenantInvitation.fromJson(item));
        } else if (item is Map) {
          items.add(TenantInvitation.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final pagination = json['pagination'];
    final paginationMap = pagination is Map<String, dynamic>
        ? pagination
        : pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};

    return TenantInvitationPageResult(
      items: items,
      page: (paginationMap['page'] as num?)?.toInt() ?? 1,
      limit: (paginationMap['limit'] as num?)?.toInt() ?? items.length,
      total: (paginationMap['total'] as num?)?.toInt() ?? items.length,
      totalPages: (paginationMap['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class CreateInvitationResult {
  const CreateInvitationResult({
    required this.id,
    required this.email,
    required this.role,
    this.inviteLink,
  });

  final String id;
  final String email;
  final String role;
  final String? inviteLink;

  factory CreateInvitationResult.fromJson(Map<String, dynamic> json) {
    return CreateInvitationResult(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      inviteLink: json['inviteLink']?.toString(),
    );
  }
}

class AcceptInvitationResult {
  const AcceptInvitationResult({required this.tenantId, required this.role});

  final String tenantId;
  final String role;

  factory AcceptInvitationResult.fromJson(Map<String, dynamic> json) {
    return AcceptInvitationResult(
      tenantId: (json['tenantId'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
    );
  }
}

class DeclineInvitationResult {
  const DeclineInvitationResult({
    required this.tenantId,
    required this.invitationId,
  });

  final String tenantId;
  final String invitationId;

  factory DeclineInvitationResult.fromJson(Map<String, dynamic> json) {
    return DeclineInvitationResult(
      tenantId: (json['tenantId'] ?? '').toString(),
      invitationId: (json['invitationId'] ?? '').toString(),
    );
  }
}
