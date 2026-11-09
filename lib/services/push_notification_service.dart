import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../screens/notifications/notifications_screen.dart';
import 'auth_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;

  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
      (token) async {
        try {
          await AuthService.syncFcmToken(
            token: token,
          );
        } catch (error) {
          debugPrint(
            'No se pudo actualizar el FCM token: $error',
          );
        }
      },
    );

    _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    _openedSubscription?.cancel();
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (_) => openNotificationsScreen(),
    );

    final initialMessage = await messaging.getInitialMessage();

    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => openNotificationsScreen(),
      );
    }

    if (await AuthService.isLoggedIn()) {
      try {
        await AuthService.syncFcmToken();
      } catch (error) {
        debugPrint(
          'No se pudo sincronizar FCM al iniciar: $error',
        );
      }
    }
  }

  static Future<void> _handleForegroundMessage(
    RemoteMessage message,
  ) async {
    final context = navigatorKey.currentContext;

    if (context == null) {
      return;
    }

    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'FashionStore';

    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        'Tienes una nueva notificación.';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        const ink = Color(0xFF151515);
        const muted = Color(0xFF666666);
        const border = Color(0xFFE5E5E5);

        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: const BorderSide(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: ink,
                      size: 24,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(height: 1, color: border),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ink,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: ink),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('CERRAR'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          openNotificationsScreen();
                        },
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('VER NOTIFICACIONES'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void openNotificationsScreen() {
    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }
}
