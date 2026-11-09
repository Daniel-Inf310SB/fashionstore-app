import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/network/connectivity_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(
    fileName: '.env',
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await AuthService.initializeGoogle();

  // Monitor independiente: no bloquea el arranque de la app.
  unawaited(ConnectivityService.instance.start());

  runApp(
    const ProviderScope(
      child: FashionStoreApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback(
    (_) {
      PushNotificationService.initialize();
    },
  );
}

class FashionStoreApp extends StatefulWidget {
  const FashionStoreApp({super.key});

  @override
  State<FashionStoreApp> createState() => _FashionStoreAppState();
}

class _FashionStoreAppState extends State<FashionStoreApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _observedOffline = false;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.status.addListener(_onConnectionChanged);
    _onConnectionChanged();
  }

  void _onConnectionChanged() {
    final value = ConnectivityService.instance.status.value;
    if (value == ConnectionStatus.offline ||
        value == ConnectionStatus.networkOnly) {
      _observedOffline = true;
    } else if (value == ConnectionStatus.apiAvailable && _observedOffline) {
      _observedOffline = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = _messengerKey.currentState;
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(const SnackBar(
          content: Text('Conexión restablecida. Actualizando información…'),
          duration: Duration(seconds: 3),
        ));
      });
    }
  }

  @override
  void dispose() {
    ConnectivityService.instance.status.removeListener(_onConnectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      navigatorKey: PushNotificationService.navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
