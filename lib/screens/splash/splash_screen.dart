import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fashionstore/screens/auth/complete_profile_screen.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../main_navigation_screen.dart';

/// Presentación editorial de FashionStore. La navegación y los tiempos de
/// comprobación de sesión se conservan respecto a la versión anterior.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _black = Color(0xFF151515);
  static const _white = Color(0xFFFFFFFF);
  static const _muted = Color(0xFF777777);

  Timer? _timer;
  late final AnimationController _controller;
  late final Animation<double> _markScale;
  late final Animation<double> _markOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subOpacity;
  late final Animation<double> _lineWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _markScale = Tween<double>(begin: .82, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, .50, curve: Curves.easeOutBack)),
    );
    _markOpacity = CurvedAnimation(
      parent: _controller, curve: const Interval(0, .28, curve: Curves.easeOut),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller, curve: const Interval(.20, .60, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, .25), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller, curve: const Interval(.20, .65, curve: Curves.easeOutCubic),
    ));
    _subOpacity = CurvedAnimation(
      parent: _controller, curve: const Interval(.48, .88, curve: Curves.easeOut),
    );
    _lineWidth = CurvedAnimation(
      parent: _controller, curve: const Interval(.48, 1, curve: Curves.easeInOutCubic),
    );
    _controller.forward();
    _timer = Timer(const Duration(seconds: 3), _checkSession);
  }

  Future<void> _checkSession() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final profileCompleted = await AuthService.isProfileCompleted();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => profileCompleted
            ? const MainNavigationScreen()
            : const CompleteProfileScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _markOpacity,
                          child: ScaleTransition(
                            scale: _markScale,
                            child: Container(
                              height: 88,
                              width: 88,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _white,
                                border: Border.all(color: _black, width: 1.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.checkroom_outlined,
                                size: 45,
                                color: _black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        FadeTransition(
                          opacity: _titleOpacity,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'FASHIONSTORE',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.1,
                                  color: _black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeTransition(
                          opacity: _subOpacity,
                          child: const Text(
                            'TU ESTILO. TU MOMENTO.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AnimatedBuilder(
                          animation: _lineWidth,
                          builder: (context, child) => SizedBox(
                            width: 72 * _lineWidth.value,
                            height: 2,
                            child: const ColoredBox(color: _black),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 26,
                  child: FadeTransition(
                    opacity: _subOpacity,
                    child: const Text(
                      'MODA PARA CADA DÍA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
