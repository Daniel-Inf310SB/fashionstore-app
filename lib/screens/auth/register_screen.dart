import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import 'verify_email_screen.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });


  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}


class _RegisterScreenState
    extends State<RegisterScreen> {
  final _formKey =
      GlobalKey<FormState>();


  final _firstNameController =
      TextEditingController();

  final _lastNameController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();


  bool _obscurePassword = true;

  bool _obscureConfirmPassword = true;

  bool _isLoading = false;


  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }


  // =========================
  // REGISTRO
  // =========================

  Future<void> _register() async {
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
          await AuthService.register(
        firstName:
            _firstNameController.text,

        lastName:
            _lastNameController.text,

        email:
            _emailController.text,

        password:
            _passwordController.text,
      );


      if (!mounted) {
        return;
      }


      final email =
          result['email']
                  ?.toString() ??
              _emailController.text
                  .trim()
                  .toLowerCase();


      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
          builder:
              (_) =>
                  VerifyEmailScreen(
            email: email,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }


      await _handleRegisterError(
        error,
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
  // MANEJAR ERROR REGISTRO
  // =========================

  Future<void> _handleRegisterError(
    Object error,
  ) async {
    final cleanMessage =
        _cleanErrorMessage(
      error,
    );


    try {
      final decoded =
          jsonDecode(
        cleanMessage,
      );


      if (decoded is Map) {
        final code =
            decoded['code']
                ?.toString();

        final message =
            decoded['message']
                    ?.toString() ??
                'No se pudo crear la cuenta';


        if (code ==
            'EMAIL_NOT_VERIFIED') {
          await _showPendingVerificationDialog(
            message,
          );

          return;
        }


        if (code ==
            'EMAIL_ALREADY_EXISTS') {
          _showError(
            message,
          );

          return;
        }


        _showError(
          message,
        );

        return;
      }
    } catch (_) {
      // El backend devolvió un mensaje normal.
    }


    _showError(
      cleanMessage,
    );
  }


  // =========================
  // CUENTA SIN VERIFICAR
  // =========================

  Future<void>
      _showPendingVerificationDialog(
    String message,
  ) async {
    final email =
        _emailController.text
            .trim()
            .toLowerCase();


    await showDialog<void>(
      context:
          context,

      barrierDismissible:
          !_isLoading,

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
                width: 68,
                height: 68,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.primary
                          .withValues(
                    alpha: 0.14,
                  ),

                  shape:
                      BoxShape.circle,
                ),

                child:
                    const Icon(
                  Icons
                      .mark_email_unread_rounded,

                  color:
                      AppColors.primary,

                  size: 34,
                ),
              ),


              const SizedBox(
                height: 18,
              ),


              const Text(
                'Correo sin verificar',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors.textPrimary,

                  fontSize: 21,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),


              const SizedBox(
                height: 10,
              ),


              Text(
                message,

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      AppColors.textSecondary,

                  fontSize: 14,

                  height: 1.4,
                ),
              ),


              const SizedBox(
                height: 8,
              ),


              Text(
                email,

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      AppColors.textPrimary,

                  fontSize: 13,

                  fontWeight:
                      FontWeight.w700,
                ),
              ),


              const SizedBox(
                height: 24,
              ),


              SizedBox(
                width:
                    double.infinity,

                height:
                    50,

                child:
                    ElevatedButton(
                  onPressed:
                      () async {
                    Navigator.pop(
                      dialogContext,
                    );


                    await _continueVerification(
                      email,
                    );
                  },

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
                        14,
                      ),
                    ),
                  ),

                  child:
                      const Text(
                    'Verificar ahora',

                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),


              const SizedBox(
                height: 8,
              ),


              TextButton(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                  );
                },

                child:
                    const Text(
                  'Cancelar',

                  style:
                      TextStyle(
                    color:
                        AppColors.textSecondary,
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
  // CONTINUAR VERIFICACIÓN
  // =========================

  Future<void> _continueVerification(
    String email,
  ) async {
    if (!mounted) {
      return;
    }


    setState(() {
      _isLoading = true;
    });


    try {
      await AuthService
          .resendVerificationCode(
        email:
            email,
      );


      if (!mounted) {
        return;
      }


      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
          builder:
              (_) =>
                  VerifyEmailScreen(
            email:
                email,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }


      final message =
          _cleanErrorMessage(
        error,
      );


      // Si el código anterior todavía está vigente
      // y el backend aplica cooldown,
      // dejamos que el usuario entre igual
      // a la pantalla de verificación.
      if (message.contains(
        'Espera ',
      )) {
        Navigator.pushReplacement(
          context,

          MaterialPageRoute(
            builder:
                (_) =>
                    VerifyEmailScreen(
              email:
                  email,
            ),
          ),
        );

        return;
      }


      _showError(
        message,
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

      appBar: AppBar(
        backgroundColor:
            AppColors.background,

        elevation: 0,

        scrolledUnderElevation: 0,

        leadingWidth: 64,

        leading: Padding(
          padding:
              const EdgeInsets.only(
            left: 12,
          ),

          child: Center(
            child: Material(
              color:
                  AppColors.surface,

              borderRadius:
                  BorderRadius.circular(
                14,
              ),

              child: InkWell(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),

                onTap:
                    _isLoading
                        ? null
                        : () {
                            Navigator.pop(
                              context,
                            );
                          },

                child:
                    const SizedBox(
                  width: 40,
                  height: 40,

                  child: Icon(
                    Icons
                        .arrow_back_ios_new_rounded,

                    size: 18,

                    color:
                        AppColors.textPrimary,
                  ),
                ),
              ),
            ),
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
            10,
            24,
            32,
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
                    width: 108,
                    height: 108,
                    padding: const EdgeInsets.all(10),

                    decoration: BoxDecoration(
                      color: AppColors.surface,

                      borderRadius:
                          BorderRadius.circular(28),

                      border: Border.all(
                        color: AppColors.divider,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.22,
                          ),
                          blurRadius: 24,
                          offset: const Offset(
                            0,
                            10,
                          ),
                        ),
                      ],
                    ),

                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(20),

                      child: Image.asset(
                        'assets/images/register.gif',
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),


                const SizedBox(
                  height: 20,
                ),


                const Text(
                  'Crea tu cuenta',

                  textAlign:
                      TextAlign.center,

                  style:
                      TextStyle(
                    color:
                        AppColors.textPrimary,

                    fontSize: 30,

                    fontWeight:
                        FontWeight.w900,
                  ),
                ),


                const SizedBox(
                  height: 8,
                ),


                const Text(
                  'Únete a FashionStore y encuentra tu próximo estilo.',

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
                  height: 32,
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
                      // NOMBRE

                      TextFormField(
                        controller:
                            _firstNameController,

                        enabled:
                            !_isLoading,

                        textCapitalization:
                            TextCapitalization.words,

                        textInputAction:
                            TextInputAction.next,

                        autofillHints:
                            const [
                          AutofillHints.givenName,
                        ],

                        style:
                            const TextStyle(
                          color:
                              AppColors.textPrimary,
                        ),

                        validator:
                            (value) {
                          final name =
                              value
                                      ?.trim() ??
                                  '';


                          if (name.isEmpty) {
                            return 'Ingresa tu nombre';
                          }


                          if (name.length <
                              2) {
                            return 'Debe tener al menos 2 caracteres';
                          }


                          return null;
                        },

                        decoration:
                            _inputDecoration(
                          hint:
                              'Nombre',

                          icon:
                              Icons
                                  .person_outline_rounded,
                        ),
                      ),


                      const SizedBox(
                        height: 14,
                      ),


                      // APELLIDO

                      TextFormField(
                        controller:
                            _lastNameController,

                        enabled:
                            !_isLoading,

                        textCapitalization:
                            TextCapitalization.words,

                        textInputAction:
                            TextInputAction.next,

                        autofillHints:
                            const [
                          AutofillHints.familyName,
                        ],

                        style:
                            const TextStyle(
                          color:
                              AppColors.textPrimary,
                        ),

                        decoration:
                            _inputDecoration(
                          hint:
                              'Apellido (opcional)',

                          icon:
                              Icons
                                  .badge_outlined,
                        ),
                      ),


                      const SizedBox(
                        height: 14,
                      ),


                      // EMAIL

                      TextFormField(
                        controller:
                            _emailController,

                        enabled:
                            !_isLoading,

                        keyboardType:
                            TextInputType.emailAddress,

                        textInputAction:
                            TextInputAction.next,

                        autocorrect:
                            false,

                        autofillHints:
                            const [
                          AutofillHints.email,
                        ],

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


                      // PASSWORD

                      TextFormField(
                        controller:
                            _passwordController,

                        enabled:
                            !_isLoading,

                        obscureText:
                            _obscurePassword,

                        textInputAction:
                            TextInputAction.next,

                        autofillHints:
                            const [
                          AutofillHints.newPassword,
                        ],

                        style:
                            const TextStyle(
                          color:
                              AppColors.textPrimary,
                        ),

                        validator:
                            (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'Crea una contraseña';
                          }


                          if (value.length <
                              8) {
                            return 'Debe tener al menos 8 caracteres';
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
                                _isLoading
                                    ? null
                                    : () {
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
                        height: 14,
                      ),


                      // CONFIRMAR PASSWORD

                      TextFormField(
                        controller:
                            _confirmPasswordController,

                        enabled:
                            !_isLoading,

                        obscureText:
                            _obscureConfirmPassword,

                        textInputAction:
                            TextInputAction.done,

                        onFieldSubmitted:
                            (_) {
                          if (!_isLoading) {
                            _register();
                          }
                        },

                        style:
                            const TextStyle(
                          color:
                              AppColors.textPrimary,
                        ),

                        validator:
                            (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'Confirma tu contraseña';
                          }


                          if (value !=
                              _passwordController
                                  .text) {
                            return 'Las contraseñas no coinciden';
                          }


                          return null;
                        },

                        decoration:
                            _inputDecoration(
                          hint:
                              'Confirmar contraseña',

                          icon:
                              Icons
                                  .verified_user_outlined,

                          suffixIcon:
                              IconButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },

                            icon:
                                Icon(
                              _obscureConfirmPassword
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
                        height: 10,
                      ),


                      const Text(
                        'Al crear tu cuenta aceptas los términos y la política de privacidad de FashionStore.',

                        style:
                            TextStyle(
                          color:
                              AppColors.textSecondary,

                          fontSize: 11,

                          height: 1.4,
                        ),
                      ),


                      const SizedBox(
                        height: 24,
                      ),


                      SizedBox(
                        height: 54,

                        child:
                            ElevatedButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : _register,

                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.primary,

                            foregroundColor:
                                Colors.white,

                            disabledBackgroundColor:
                                AppColors.primary
                                    .withValues(
                              alpha: 0.45,
                            ),

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
                                      'Crear cuenta',

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


              ],
            ),
          ),
        ),
      ),
    );
  }


  // =========================
  // INPUT
  // =========================

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