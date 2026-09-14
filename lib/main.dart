import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';

import 'screens/splash/splash_screen.dart';

import 'services/auth_service.dart';


Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();


  await dotenv.load(
    fileName: '.env',
  );


  await AuthService.initializeGoogle();


  runApp(
    const ProviderScope(
      child: FashionStoreApp(),
    ),
  );

}


class FashionStoreApp
    extends StatelessWidget {

  const FashionStoreApp({
    super.key,
  });


  @override
  Widget build(
    BuildContext context,
  ) {

    return MaterialApp(

      title:
          AppConstants.appName,

      debugShowCheckedModeBanner:
          false,

      theme:
          AppTheme.darkTheme,


      // =====================================================
      // HOME PRINCIPAL
      // =====================================================

      home:
          const SplashScreen(),

    );

  }

}