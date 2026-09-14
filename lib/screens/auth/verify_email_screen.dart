import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';


class VerifyEmailScreen
    extends StatefulWidget {
  final String email;


  const VerifyEmailScreen({
    super.key,
    required this.email,
  });


  @override
  State<VerifyEmailScreen>
      createState() =>
          _VerifyEmailScreenState();
}


class _VerifyEmailScreenState
    extends State<VerifyEmailScreen> {
  final List<TextEditingController>
      _controllers =
      List.generate(
    6,
    (_) =>
        TextEditingController(),
  );


  final List<FocusNode> _focusNodes =
      List.generate(
    6,
    (_) =>
        FocusNode(),
  );


  bool _isVerifying =
      false;

  bool _isResending =
      false;


  Timer? _timer;

  int _secondsRemaining =
      60;

  int? _attemptsRemaining;


  @override
  void initState() {
    super.initState();

    _startTimer();
  }


  @override
  void dispose() {
    _timer?.cancel();


    for (final controller
        in _controllers) {
      controller.dispose();
    }


    for (final focusNode
        in _focusNodes) {
      focusNode.dispose();
    }


    super.dispose();
  }


  // =========================
  // TIMER
  // =========================

  void _startTimer() {
    _timer?.cancel();


    setState(() {
      _secondsRemaining =
          60;
    });


    _timer =
        Timer.periodic(
      const Duration(
        seconds:
            1,
      ),

      (timer) {
        if (!mounted) {
          timer.cancel();

          return;
        }


        if (_secondsRemaining <=
            1) {
          timer.cancel();


          setState(() {
            _secondsRemaining =
                0;
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
  // CÓDIGO
  // =========================

  String _getCode() {
    return _controllers
        .map(
          (controller) =>
              controller.text,
        )
        .join();
  }


  void _clearCode() {
    for (final controller
        in _controllers) {
      controller.clear();
    }

    _attemptsRemaining = null;
  }


  void _onDigitChanged(
    int index,
    String value,
  ) {
    if (value.isNotEmpty) {
      if (index <
          _focusNodes.length - 1) {
        _focusNodes[
                index + 1]
            .requestFocus();
      } else {
        _focusNodes[index]
            .unfocus();
      }
    } else {
      if (index > 0) {
        _focusNodes[
                index - 1]
            .requestFocus();
      }
    }


    if (_getCode().length ==
            6 &&
        !_isVerifying) {
      _verify();
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


  bool _shouldAllowImmediateResend(
    String message,
  ) {
    final normalized =
        message.toLowerCase();

    return normalized.contains(
          'expiró',
        ) ||
        normalized.contains(
          'expirado',
        ) ||
        normalized.contains(
          'superaste',
        ) ||
        normalized.contains(
          'máximo',
        ) ||
        normalized.contains(
          'no existe un código activo',
        );
  }


  // =========================
  // VERIFICAR
  // =========================

  Future<void> _verify() async {
    if (_isVerifying) {
      return;
    }


    final code =
        _getCode();


    if (code.length !=
        6) {
      _showError(
        'Ingresa los 6 dígitos del código',
      );

      return;
    }


    FocusScope.of(context)
        .unfocus();


    setState(() {
      _isVerifying =
          true;
    });


    try {
      await AuthService.verifyEmail(
        email:
            widget.email,

        code:
            code,
      );


      if (!mounted) {
        return;
      }


      await _showVerifiedDialog();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message =
          _cleanErrorMessage(
        error,
      );

      setState(() {
        _attemptsRemaining =
            _extractAttemptsRemaining(
          message,
        );

        if (_shouldAllowImmediateResend(
          message,
        )) {
          _secondsRemaining = 0;
        }
      });


      _showError(
        message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying =
              false;
        });
      }
    }
  }


  // =========================
  // REENVIAR
  // =========================

  Future<void> _resend() async {
    if (_secondsRemaining >
            0 ||
        _isResending) {
      return;
    }


    setState(() {
      _isResending =
          true;
    });


    try {
      await AuthService
          .resendVerificationCode(
        email:
            widget.email,
      );


      if (!mounted) {
        return;
      }


      _clearCode();


      _focusNodes.first
          .requestFocus();


      _startTimer();


      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'Te enviamos un nuevo código',
          ),
        ),
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
          _isResending =
              false;
        });
      }
    }
  }


  // =========================
  // VERIFICADO
  // =========================

  Future<void>
      _showVerifiedDialog() async {
    await showDialog<void>(
      context:
          context,

      barrierDismissible:
          false,

      builder:
          (dialogContext) {
        return AlertDialog(
          backgroundColor:
              AppColors.surface,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
          ),

          content:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Container(
                width:
                    70,

                height:
                    70,

                decoration:
                    const BoxDecoration(
                  color:
                      AppColors.primary,

                  shape:
                      BoxShape.circle,
                ),

                child:
                    const Icon(
                  Icons
                      .verified_rounded,

                  color:
                      Colors.white,

                  size:
                      38,
                ),
              ),


              const SizedBox(
                height:
                    20,
              ),


              const Text(
                'Correo verificado',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors.textPrimary,

                  fontSize:
                      22,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),


              const SizedBox(
                height:
                    8,
              ),


              const Text(
                'Tu cuenta de Sonelya ya está lista para iniciar sesión.',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors.textSecondary,

                  fontSize:
                      14,
                ),
              ),


              const SizedBox(
                height:
                    24,
              ),


              SizedBox(
                width:
                    double.infinity,

                height:
                    50,

                child:
                    ElevatedButton(
                  onPressed:
                      () {
                    Navigator.pop(
                      dialogContext,
                    );


                    Navigator
                        .pushAndRemoveUntil(
                      context,

                      MaterialPageRoute(
                        builder:
                            (_) =>
                                const LoginScreen(),
                      ),

                      (_) =>
                          false,
                    );
                  },

                  style:
                      ElevatedButton
                          .styleFrom(
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
                        14,
                      ),
                    ),
                  ),

                  child:
                      const Text(
                    'Iniciar sesión',

                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
            Text(
          message,
        ),

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

      appBar:
          AppBar(
        backgroundColor:
            AppColors.background,

        elevation:
            0,

        leading:
            IconButton(
          onPressed:
              _isVerifying
                  ? null
                  : () {
                      Navigator
                          .pushAndRemoveUntil(
                        context,

                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  const LoginScreen(),
                        ),

                        (_) =>
                            false,
                      );
                    },

          icon:
              const Icon(
            Icons
                .arrow_back_ios_new_rounded,

            color:
                AppColors.textPrimary,
          ),
        ),
      ),

      body:
          SafeArea(
        top:
            false,

        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            28,
            24,
            32,
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
                    color:
                        AppColors.primary
                            .withValues(
                      alpha:
                          0.15,
                    ),

                    shape:
                        BoxShape.circle,
                  ),

                  child:
                      const Icon(
                    Icons
                        .mark_email_read_rounded,

                    color:
                        AppColors.primary,

                    size:
                        44,
                  ),
                ),
              ),


              const SizedBox(
                height:
                    28,
              ),


              const Text(
                'Revisa tu correo',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors.textPrimary,

                  fontSize:
                      29,

                  fontWeight:
                      FontWeight.w900,
                ),
              ),


              const SizedBox(
                height:
                    10,
              ),


              const Text(
                'Enviamos un código de 6 dígitos a',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors.textSecondary,

                  fontSize:
                      14,
                ),
              ),


              const SizedBox(
                height:
                    5,
              ),


              Text(
                widget.email,

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      AppColors.textPrimary,

                  fontSize:
                      14,

                  fontWeight:
                      FontWeight.w700,
                ),
              ),


              const SizedBox(
                height:
                    36,
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
                          48,

                      height:
                          58,

                      child:
                          TextField(
                        controller:
                            _controllers[index],

                        focusNode:
                            _focusNodes[index],

                        enabled:
                            !_isVerifying,

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
                              AppColors.surface,

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
                          _onDigitChanged(
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
                    32,
              ),


              SizedBox(
                height:
                    54,

                child:
                    ElevatedButton(
                  onPressed:
                      _isVerifying
                          ? null
                          : _verify,

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
                      _isVerifying
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
                          : const Text(
                              'Verificar correo',

                              style:
                                  TextStyle(
                                fontSize:
                                    16,

                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                ),
              ),


              const SizedBox(
                height:
                    28,
              ),


              const Text(
                '¿No recibiste el código?',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors.textSecondary,

                  fontSize:
                      13,
                ),
              ),


              const SizedBox(
                height:
                    4,
              ),


              TextButton(
                onPressed:
                    _secondsRemaining >
                                0 ||
                            _isResending
                        ? null
                        : _resend,

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
                            _secondsRemaining >
                                    0
                                ? 'Reenviar código en ${_secondsRemaining}s'
                                : 'Reenviar código',

                            style:
                                TextStyle(
                              color:
                                  _secondsRemaining >
                                          0
                                      ? AppColors
                                          .textSecondary
                                      : AppColors
                                          .primary,

                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
              ),


              const SizedBox(
                height:
                    18,
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
          ),
        ),
      ),
    );
  }
}
