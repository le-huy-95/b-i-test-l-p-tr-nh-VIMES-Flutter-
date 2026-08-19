class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.tenantId,
    this.readAt,
    required this.createdAt,
    this.actorUserId,
    this.actorName,
    this.targetType,
    this.targetId,
    this.routeName,
    this.routeParams,
    this.deeplink,
    this.sourceType,
    this.sourceId,
    this.data,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? tenantId;
  final DateTime? readAt;
  final DateTime createdAt;
  final String? actorUserId;
  final String? actorName;
  final String? targetType;
  final String? targetId;
  final String? routeName;
  final Map<String, String>? routeParams;
  final String? deeplink;
  final String? sourceType;
  final String? sourceId;
  final Map<String, dynamic>? data;

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      tenantId: _parseString(json['tenantId']),
      readAt: _parseDateTime(json['readAt']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      actorUserId: _parseString(json['actorUserId']),
      actorName: _parseString(json['actorName']),
      targetType: _parseString(json['targetType']),
      targetId: _parseString(json['targetId']),
      routeName: _parseString(json['routeName']),
      routeParams: _parseStringMap(json['routeParams']),
      deeplink: _parseString(json['deeplink']),
      sourceType: _parseString(json['sourceType']),
      sourceId: _parseString(json['sourceId']),
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }

  NotificationItem copyWith({DateTime? readAt}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      tenantId: tenantId,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      actorUserId: actorUserId,
      actorName: actorName,
      targetType: targetType,
      targetId: targetId,
      routeName: routeName,
      routeParams: routeParams,
      deeplink: deeplink,
      sourceType: sourceType,
      sourceId: sourceId,
      data: data,
    );
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static Map<String, String>? _parseStringMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }
}

class NotificationListResult {
  const NotificationListResult({
    required this.items,
    this.nextCursor,
  });

  final List<NotificationItem> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

class MarkReadResult {
  const MarkReadResult({required this.updated, required this.unreadCount});

  final int updated;
  final int unreadCount;
}
