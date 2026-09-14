import 'package:flutter/material.dart';
import 'package:fashionstore/screens/auth/forgot_password_screen.dart';

import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../main_navigation_screen.dart';
import 'complete_profile_screen.dart';
import 'register_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}


class _LoginScreenState
    extends State<LoginScreen> {
  final _formKey =
      GlobalKey<FormState>();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  bool _obscurePassword = true;

  bool _isLoading = false;
  bool _isGoogleLoading = false;


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }


  // =========================
  // LOGIN NORMAL
  // =========================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result =
          await AuthService.login(
        email:
            _emailController.text,

        password:
            _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      await _handleLoginResult(
        result,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        _cleanErrorMessage(
          error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  // =========================
  // GOOGLE
  // =========================

  Future<void> _loginWithGoogle() async {
    if (_isGoogleLoading ||
        _isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final result =
          await AuthService
              .signInWithGoogle();

      if (!mounted) {
        return;
      }

      await _handleLoginResult(
        result,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        _cleanErrorMessage(
          error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }


  // =========================
  // DESTINO
  // =========================

  Future<void> _handleLoginResult(
    Map<String, dynamic> result,
  ) async {
    final rawUser =
        result['user'];

    if (rawUser is! Map) {
      throw Exception(
        'El backend no devolvió los datos del usuario',
      );
    }

    final user =
        Map<String, dynamic>.from(
      rawUser,
    );

    final profileCompleted =
        user['profile_completed'] ==
            true;

    if (!mounted) {
      return;
    }

    if (!profileCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  CompleteProfileScreen(
            user: user,
          ),
        ),
      );

      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                const MainNavigationScreen(),
      ),
    );
  }


  // =========================
  // REGISTRO
  // =========================

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                const RegisterScreen(),
      ),
    );
  }


  // =========================
  // ERRORES
  // =========================

  String _cleanErrorMessage(
    Object error,
  ) {
    String message =
        error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      message =
          message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }


  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),

        backgroundColor:
            AppColors.error,
      ),
    );
  }


  // =========================
  // UI
  // =========================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.background,

      body:
          SafeArea(
        child:
            Center(
          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 28,
            ),

            child:
                Form(
              key:
                  _formKey,

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,

                children: [
                  Center(
  child: Container(
    width: 118,
    height: 118,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: AppColors.primary,
        width: 1.5,
      ),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/login.gif',
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),

        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(
              alpha: 0.35,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: AppColors.textPrimary,
            size: 48,
          ),
        ),
      ],
    ),
  ),
),
                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'FashionStore',

                    textAlign:
                        TextAlign.center,

                    style:
                        TextStyle(
                      color:
                          AppColors.textPrimary,

                      fontSize: 34,

                      fontWeight:
                          FontWeight.w900,

                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  const Text(
                    'Tu estilo. Tu espacio.',

                    textAlign:
                        TextAlign.center,

                    style:
                        TextStyle(
                      color:
                          AppColors.textSecondary,

                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(
                    height: 34,
                  ),

                  Container(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.surface,

                      borderRadius:
                          BorderRadius.circular(
                        24,
                      ),
                    ),

                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,

                      children: [
                        const Text(
                          'Bienvenido a FashionStore',

                          style:
                              TextStyle(
                            color:
                                AppColors.textPrimary,

                            fontSize: 25,

                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        const Text(
                          'Inicia sesión para descubrir tu estilo.',

                          style:
                              TextStyle(
                            color:
                                AppColors.textSecondary,

                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(
                          height: 24,
                        ),

                        SizedBox(
                          height: 54,

                          child:
                              OutlinedButton(
                            onPressed:
                                _isLoading ||
                                        _isGoogleLoading
                                    ? null
                                    : _loginWithGoogle,

                            style:
                                OutlinedButton.styleFrom(
                              backgroundColor:
                                  Colors.white,

                              foregroundColor:
                                  Colors.black,

                              side:
                                  const BorderSide(
                                color:
                                    Color(
                                  0xFFE2E2E2,
                                ),
                              ),

                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  16,
                                ),
                              ),
                            ),

                            child:
                                _isGoogleLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,

                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2.3,

                                          color:
                                              Colors.black,
                                        ),
                                      )
                                    : Stack(
                                        alignment:
                                            Alignment.center,

                                        children: [
                                          Align(
                                            alignment:
                                                Alignment.centerLeft,

                                            child:
                                                Image.asset(
                                              'assets/icons/google.png',

                                              width: 35,
                                              height: 35,
                                            ),
                                          ),

                                          const Text(
                                            'Continuar con Google',

                                            style:
                                                TextStyle(
                                              fontSize: 15,

                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),

                        const SizedBox(
                          height: 22,
                        ),

                        const Row(
                          children: [
                            Expanded(
                              child:
                                  Divider(
                                color:
                                    AppColors.divider,
                              ),
                            ),

                            Padding(
                              padding:
                                  EdgeInsets.symmetric(
                                horizontal: 14,
                              ),

                              child:
                                  Text(
                                'o continúa con correo',

                                style:
                                    TextStyle(
                                  color:
                                      AppColors.textSecondary,

                                  fontSize: 12,
                                ),
                              ),
                            ),

                            Expanded(
                              child:
                                  Divider(
                                color:
                                    AppColors.divider,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 22,
                        ),

                        TextFormField(
                          controller:
                              _emailController,

                          keyboardType:
                              TextInputType.emailAddress,

                          textInputAction:
                              TextInputAction.next,

                          style:
                              const TextStyle(
                            color:
                                AppColors.textPrimary,
                          ),

                          validator:
                              (value) {
                            final email =
                                value
                                        ?.trim() ??
                                    '';

                            if (email.isEmpty) {
                              return 'Ingresa tu correo';
                            }

                            if (!email.contains(
                                  '@',
                                ) ||
                                !email.contains(
                                  '.',
                                )) {
                              return 'Ingresa un correo válido';
                            }

                            return null;
                          },

                          decoration:
                              _inputDecoration(
                            hint:
                                'Correo electrónico',

                            icon:
                                Icons
                                    .mail_outline_rounded,
                          ),
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        TextFormField(
                          controller:
                              _passwordController,

                          obscureText:
                              _obscurePassword,

                          textInputAction:
                              TextInputAction.done,

                          onFieldSubmitted:
                              (_) =>
                                  _login(),

                          style:
                              const TextStyle(
                            color:
                                AppColors.textPrimary,
                          ),

                          validator:
                              (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Ingresa tu contraseña';
                            }

                            return null;
                          },

                          decoration:
                              _inputDecoration(
                            hint:
                                'Contraseña',

                            icon:
                                Icons
                                    .lock_outline_rounded,

                            suffixIcon:
                                IconButton(
                              onPressed:
                                  () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },

                              icon:
                                  Icon(
                                _obscurePassword
                                    ? Icons
                                        .visibility_off_outlined
                                    : Icons
                                        .visibility_outlined,

                                color:
                                    AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        Align(
                          alignment:
                              Alignment.centerRight,

                          child:
                              TextButton(
                            onPressed:
                              _isLoading ||
                                      _isGoogleLoading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) =>
                                                  const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },

                            child:
                                const Text(
                              '¿Olvidaste tu contraseña?',

                              style:
                                  TextStyle(
                                color:
                                    AppColors.primary,

                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        SizedBox(
                          height: 54,

                          child:
                              ElevatedButton(
                            onPressed:
                                _isLoading ||
                                        _isGoogleLoading
                                    ? null
                                    : _login,

                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppColors.primary,

                              foregroundColor:
                                  Colors.white,

                              elevation: 0,

                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  16,
                                ),
                              ),
                            ),

                            child:
                                _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,

                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2.4,

                                          color:
                                              Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Iniciar sesión',

                                        style:
                                            TextStyle(
                                          fontSize: 16,

                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [
                      const Text(
                        '¿Aún no tienes cuenta?',

                        style:
                            TextStyle(
                          color:
                              AppColors.textSecondary,
                        ),
                      ),

                      TextButton(
                        onPressed:
                            _isLoading ||
                                    _isGoogleLoading
                                ? null
                                : _goToRegister,

                        child:
                            const Text(
                          'Crear cuenta',

                          style:
                              TextStyle(
                            color:
                                AppColors.primary,

                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText:
          hint,

      hintStyle:
          const TextStyle(
        color:
            AppColors.textSecondary,
      ),

      prefixIcon:
          Icon(
        icon,

        color:
            AppColors.textSecondary,
      ),

      suffixIcon:
          suffixIcon,

      filled:
          true,

      fillColor:
          AppColors.background,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            BorderSide.none,
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            const BorderSide(
          color:
              AppColors.primary,

          width: 1.4,
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            const BorderSide(
          color:
              AppColors.error,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            const BorderSide(
          color:
              AppColors.error,

          width: 1.4,
        ),
      ),
    );
  }
}