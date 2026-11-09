import 'dart:convert';

import '../models/app_notification.dart';
import 'api_service.dart';

class NotificationService {
  static Future<NotificationPage> getNotifications() async {
    final response = await ApiService.get(
      '/notifications?page=1&page_size=50',
      requiresAuth: true,
    );

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'No se pudieron cargar las notificaciones',
      );
    }

    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (item) => AppNotification.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <AppNotification>[];

    return NotificationPage(
      items: items,
      unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
      total: (data['total'] as num?)?.toInt() ?? items.length,
    );
  }

  static Future<void> markAsRead(int notificationId) async {
    final response = await ApiService.patch(
      '/notifications/$notificationId/read',
      requiresAuth: true,
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);

      throw Exception(
        data is Map
            ? data['detail'] ?? 'No se pudo marcar como leída'
            : 'No se pudo marcar como leída',
      );
    }
  }

  static Future<void> markAllAsRead() async {
    final response = await ApiService.patch(
      '/notifications/read-all',
      requiresAuth: true,
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);

      throw Exception(
        data is Map
            ? data['detail'] ?? 'No se pudieron actualizar las notificaciones'
            : 'No se pudieron actualizar las notificaciones',
      );
    }
  }
}
