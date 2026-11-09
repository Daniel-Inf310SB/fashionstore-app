class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.event,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.entityType,
    this.entityId,
    this.actionUrl,
  });

  final int id;
  final String type;
  final String event;
  final String title;
  final String message;
  final String? entityType;
  final int? entityId;
  final String? actionUrl;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppNotification(
      id: json['id'] as int,
      type: json['type']?.toString() ?? 'SYSTEM',
      event: json['event']?.toString() ?? '',
      title: json['title']?.toString() ?? 'FashionStore',
      message: json['message']?.toString() ?? '',
      entityType: json['entity_type']?.toString(),
      entityId: json['entity_id'] as int?,
      actionUrl: json['action_url']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.unreadCount,
    required this.total,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final int total;
}
