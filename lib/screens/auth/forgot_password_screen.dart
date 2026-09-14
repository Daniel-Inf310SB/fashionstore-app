import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';


class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}


class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _emailController =
      TextEditingController();

  final List<TextEditingController>
      _codeControllers =
      List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _codeFocusNodes =
      List.generate(
    6,
    (_) => FocusNode(),
  );

  final _passwordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  int _step = 1;

  bool _isLoading = false;
  bool _isResending = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Timer? _resendTimer;

  int _secondsRemaining = 0;

  int? _attemptsRemaining;


  @override
  void dispose() {
    _resendTimer?.cancel();

    _emailController.dispose();

    for (final controller
        in _codeControllers) {
      controller.dispose();
    }

    for (final focusNode
        in _codeFocusNodes) {
      focusNode.dispose();
    }

    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }


  // =========================
  // TIMER REENVÍO
  // =========================

  void _startResendTimer() {
    _resendTimer?.cancel();

    setState(() {
      _secondsRemaining = 60;
    });

    _resendTimer = Timer.periodic(
      const Duration(
        seconds: 1,
      ),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsRemaining <= 1) {
          timer.cancel();

          setState(() {
            _secondsRemaining = 0;
          });

          return;
        }

        setState(() {
          _secondsRemaining--;
        });
      },
    );
  }


  // =========================
  // HELPERS
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


  void _showSuccess(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }


  bool _isValidEmail(
    String email,
  ) {
    return email.contains('@') &&
        email.contains('.');
  }


  String _getCode() {
    return _codeControllers
        .map(
          (controller) =>
              controller.text,
        )
        .join();
  }


  void _clearCode() {
    for (final controller
        in _codeControllers) {
      controller.clear();
    }

    _attemptsRemaining = null;
  }


  void _onCodeDigitChanged(
    int index,
    String value,
  ) {
    if (value.isNotEmpty) {
      if (index <
          _codeFocusNodes.length - 1) {
        _codeFocusNodes[
                index + 1]
            .requestFocus();
      } else {
        _codeFocusNodes[index]
            .unfocus();
      }
    } else if (index > 0) {
      _codeFocusNodes[
              index - 1]
          .requestFocus();
    }
  }


  int? _extractAttemptsRemaining(
    String message,
  ) {
    final match = RegExp(
      r'quedan\s+(\d+)\s+intentos?',
      caseSensitive: false,
    ).firstMatch(
      message,
    );

    if (match == null) {
      return null;
    }

    return int.tryParse(
      match.group(1) ?? '',
    );
  }


  bool _isExpiredOrBlocked(
    String message,
  ) {
    final normalized =
        message.toLowerCase();

    return normalized.contains(
          'expirado',
        ) ||
        normalized.contains(
          'expiró',
        ) ||
        normalized.contains(
          'máximo',
        ) ||
        normalized.contains(
          'superaste',
        ) ||
        normalized.contains(
          'no existe un código activo',
        );
  }


  // =========================
  // SOLICITAR CÓDIGO
  // =========================

  Future<void> _sendCode({
    bool isResend = false,
  }) async {
    if (_isLoading ||
        _isResending) {
      return;
    }

    if (isResend &&
        _secondsRemaining > 0) {
      return;
    }

    FocusScope.of(context)
        .unfocus();

    final email =
        _emailController.text
            .trim()
            .toLowerCase();

    if (email.isEmpty) {
      _showError(
        'Ingresa tu correo electrónico',
      );
      return;
    }

    if (!_isValidEmail(
      email,
    )) {
      _showError(
        'Ingresa un correo válido',
      );
      return;
    }

    setState(() {
      if (isResend) {
        _isResending = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final result =
          await AuthService.forgotPassword(
        email: email,
      );

      if (!mounted) {
        return;
      }

      _clearCode();

      setState(() {
        _step = 2;
      });

      _startResendTimer();

      _showSuccess(
        result['message']
                ?.toString() ??
            'Si existe una cuenta asociada, recibirás un código.',
      );

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (mounted) {
            _codeFocusNodes.first
                .requestFocus();
          }
        },
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
          _isResending = false;
        });
      }
    }
  }


  // =========================
  // VERIFICAR CÓDIGO
  // =========================

  Future<void> _verifyCode() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context)
        .unfocus();

    final code =
        _getCode();

    if (!RegExp(
      r'^\d{6}$',
    ).hasMatch(
      code,
    )) {
      _showError(
        'Ingresa el código de 6 dígitos',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.verifyResetCode(
        email:
            _emailController.text
                .trim()
                .toLowerCase(),

        code:
            code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _step = 3;
        _attemptsRemaining = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message =
          _cleanErrorMessage(
        error,
      );

      final attempts =
          _extractAttemptsRemaining(
        message,
      );

      setState(() {
        _attemptsRemaining =
            attempts;
      });

      _showError(
        message,
      );

      if (_isExpiredOrBlocked(
        message,
      )) {
        setState(() {
          _secondsRemaining = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  // =========================
  // CAMBIAR CONTRASEÑA
  // =========================

  Future<void> _resetPassword() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context)
        .unfocus();

    final password =
        _passwordController.text;

    final confirmPassword =
        _confirmPasswordController.text;

    if (password.length < 8) {
      _showError(
        'La contraseña debe tener al menos 8 caracteres',
      );
      return;
    }

    if (password.length > 128) {
      _showError(
        'La contraseña no puede superar 128 caracteres',
      );
      return;
    }

    if (password !=
        confirmPassword) {
      _showError(
        'Las contraseñas no coinciden',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result =
          await AuthService.resetPassword(
        email:
            _emailController.text
                .trim()
                .toLowerCase(),

        code:
            _getCode(),

        newPassword:
            password,
      );

      if (!mounted) {
        return;
      }

      _showSuccess(
        result['message']
                ?.toString() ??
            'Contraseña actualizada correctamente',
      );

      Navigator.pop(
        context,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message =
          _cleanErrorMessage(
        error,
      );

      _showError(
        message,
      );

      if (_isExpiredOrBlocked(
        message,
      )) {
        _passwordController.clear();
        _confirmPasswordController.clear();

        setState(() {
          _step = 2;
          _secondsRemaining = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

      appBar:
          AppBar(
        backgroundColor:
            AppColors.background,

        foregroundColor:
            AppColors.textPrimary,

        elevation:
            0,

        title:
            const Text(
          'Recuperar contraseña',
        ),
      ),

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(
            horizontal:
                24,

            vertical:
                30,
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,

            children: [
              Center(
                child:
                    Container(
                  width:
                      88,

                  height:
                      88,

                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,

                    color:
                        AppColors.surface,

                    border:
                        Border.all(
                      color:
                          AppColors.primary,

                      width:
                          2,
                    ),
                  ),

                  child:
                      Icon(
                    _step == 1
                        ? Icons.mail_outline_rounded
                        : _step == 2
                            ? Icons.password_rounded
                            : Icons.lock_reset_rounded,

                    color:
                        AppColors.primary,

                    size:
                        42,
                  ),
                ),
              ),

              const SizedBox(
                height:
                    26,
              ),

              Text(
                _step == 1
                    ? '¿Olvidaste tu contraseña?'
                    : _step == 2
                        ? 'Revisa tu correo'
                        : 'Crea una nueva contraseña',

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      AppColors.textPrimary,

                  fontSize:
                      26,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height:
                    10,
              ),

              Text(
                _step == 1
                    ? 'Ingresa tu correo y te enviaremos un código de recuperación.'
                    : _step == 2
                        ? 'Ingresa el código de 6 dígitos que enviamos a tu correo.'
                        : 'Usa una contraseña de entre 8 y 128 caracteres.',

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      AppColors.textSecondary,

                  fontSize:
                      14,
                ),
              ),

              const SizedBox(
                height:
                    30,
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
                    _buildCurrentStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCurrentStep() {
    if (_step == 1) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,

        children: [
          TextField(
            controller:
                _emailController,

            keyboardType:
                TextInputType.emailAddress,

            textInputAction:
                TextInputAction.done,

            onSubmitted:
                (_) =>
                    _sendCode(),

            enabled:
                !_isLoading,

            style:
                const TextStyle(
              color:
                  AppColors.textPrimary,
            ),

            decoration:
                _inputDecoration(
              hint:
                  'Correo electrónico',

              icon:
                  Icons.mail_outline_rounded,
            ),
          ),

          const SizedBox(
            height:
                20,
          ),

          _primaryButton(
            text:
                'Enviar código',

            onPressed:
                () => _sendCode(),
          ),
        ],
      );
    }

    if (_step == 2) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,

        children: [
          Text(
            _emailController.text
                .trim(),

            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color:
                  AppColors.textSecondary,

              fontSize:
                  13,
            ),
          ),

          const SizedBox(
            height:
                20,
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

            children:
                List.generate(
              6,
              (index) {
                return SizedBox(
                  width:
                      44,

                  height:
                      58,

                  child:
                      TextField(
                    controller:
                        _codeControllers[index],

                    focusNode:
                        _codeFocusNodes[index],

                    enabled:
                        !_isLoading,

                    keyboardType:
                        TextInputType.number,

                    textAlign:
                        TextAlign.center,

                    maxLength:
                        1,

                    inputFormatters:
                        [
                      FilteringTextInputFormatter
                          .digitsOnly,
                    ],

                    style:
                        const TextStyle(
                      color:
                          AppColors.textPrimary,

                      fontSize:
                          22,

                      fontWeight:
                          FontWeight.w800,
                    ),

                    decoration:
                        InputDecoration(
                      counterText:
                          '',

                      filled:
                          true,

                      fillColor:
                          AppColors.background,

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),

                        borderSide:
                            BorderSide.none,
                      ),

                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),

                        borderSide:
                            const BorderSide(
                          color:
                              AppColors.divider,
                        ),
                      ),

                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),

                        borderSide:
                            const BorderSide(
                          color:
                              AppColors.primary,

                          width:
                              1.6,
                        ),
                      ),
                    ),

                    onChanged:
                        (value) {
                      _onCodeDigitChanged(
                        index,
                        value,
                      );
                    },
                  ),
                );
              },
            ),
          ),

          if (_attemptsRemaining != null) ...[
            const SizedBox(
              height:
                  14,
            ),

            Text(
              'Intentos restantes: $_attemptsRemaining',

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color:
                    AppColors.textSecondary,

                fontSize:
                    12,
              ),
            ),
          ],

          const SizedBox(
            height:
                20,
          ),

          _primaryButton(
            text:
                'Verificar código',

            onPressed:
                _verifyCode,
          ),

          const SizedBox(
            height:
                8,
          ),

          TextButton(
            onPressed:
                _isLoading ||
                        _isResending ||
                        _secondsRemaining > 0
                    ? null
                    : () => _sendCode(
                          isResend: true,
                        ),

            child:
                _isResending
                    ? const SizedBox(
                        width:
                            20,

                        height:
                            20,

                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,

                          color:
                              AppColors.primary,
                        ),
                      )
                    : Text(
                        _secondsRemaining > 0
                            ? 'Reenviar código en ${_secondsRemaining}s'
                            : 'Reenviar código',

                        style:
                            TextStyle(
                          color:
                              _secondsRemaining > 0
                                  ? AppColors.textSecondary
                                  : AppColors.primary,

                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
          ),

          const SizedBox(
            height:
                8,
          ),

          const Text(
            'El código vence en 10 minutos.',

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  AppColors.textSecondary,

              fontSize:
                  12,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        TextField(
          controller:
              _passwordController,

          obscureText:
              _obscurePassword,

          textInputAction:
              TextInputAction.next,

          enabled:
              !_isLoading,

          style:
              const TextStyle(
            color:
                AppColors.textPrimary,
          ),

          decoration:
              _inputDecoration(
            hint:
                'Nueva contraseña',

            icon:
                Icons.lock_outline_rounded,

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
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,

                color:
                    AppColors.textSecondary,
              ),
            ),
          ),
        ),

        const SizedBox(
          height:
              14,
        ),

        TextField(
          controller:
              _confirmPasswordController,

          obscureText:
              _obscureConfirmPassword,

          textInputAction:
              TextInputAction.done,

          onSubmitted:
              (_) =>
                  _resetPassword(),

          enabled:
              !_isLoading,

          style:
              const TextStyle(
            color:
                AppColors.textPrimary,
          ),

          decoration:
              _inputDecoration(
            hint:
                'Confirmar contraseña',

            icon:
                Icons.lock_reset_rounded,

            suffixIcon:
                IconButton(
              onPressed:
                  () {
                setState(() {
                  _obscureConfirmPassword =
                      !_obscureConfirmPassword;
                });
              },

              icon:
                  Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,

                color:
                    AppColors.textSecondary,
              ),
            ),
          ),
        ),

        const SizedBox(
          height:
              20,
        ),

        _primaryButton(
          text:
              'Cambiar contraseña',

          onPressed:
              _resetPassword,
        ),
      ],
    );
  }


  Widget _primaryButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height:
          54,

      child:
          ElevatedButton(
        onPressed:
            _isLoading
                ? null
                : onPressed,

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              AppColors.primary,

          foregroundColor:
              Colors.white,

          elevation:
              0,

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
                    width:
                        22,

                    height:
                        22,

                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2.4,

                      color:
                          Colors.white,
                    ),
                  )
                : Text(
                    text,

                    style:
                        const TextStyle(
                      fontSize:
                          16,

                      fontWeight:
                          FontWeight.w700,
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
        horizontal:
            18,

        vertical:
            18,
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

          width:
              1.4,
        ),
      ),
    );
  }
}
