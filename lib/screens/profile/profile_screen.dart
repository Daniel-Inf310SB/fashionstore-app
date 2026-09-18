import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'purchase_history_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}


class _ProfileScreenState
    extends State<ProfileScreen> {
  String _name = '';
  String _email = '';
  String _photoUrl = '';

  bool _isLoading = true;
  bool _isLoggingOut = false;


  @override
  void initState() {
    super.initState();

    _loadProfile();
  }


  // =========================
  // CARGAR PERFIL
  // =========================

  Future<void> _loadProfile() async {
    final name =
        await AuthService.getUserName();

    final email =
        await AuthService.getUserEmail();

    final photo =
        await AuthService.getUserPhoto();


    if (!mounted) {
      return;
    }


    setState(() {
      _name =
          name ?? '';

      _email =
          email ?? '';

      _photoUrl =
          photo ?? '';

      _isLoading =
          false;
    });
  }


  // =========================
  // LOGOUT
  // =========================

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }


    final shouldLogout =
        await showDialog<bool>(
      context:
          context,

      builder:
          (context) {
        return AlertDialog(
          backgroundColor:
              AppColors.surface,

          title:
              const Text(
            'Cerrar sesión',

            style:
                TextStyle(
              color:
                  AppColors.textPrimary,

              fontWeight:
                  FontWeight.w700,
            ),
          ),

          content:
              const Text(
            '¿Quieres cerrar tu sesión en Sonelya?',

            style:
                TextStyle(
              color:
                  AppColors.textSecondary,
            ),
          ),

          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  false,
                );
              },

              child:
                  const Text(
                'Cancelar',
              ),
            ),

            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              child:
                  const Text(
                'Cerrar sesión',

                style:
                    TextStyle(
                  color:
                      AppColors.error,
                ),
              ),
            ),
          ],
        );
      },
    );


    if (shouldLogout != true) {
      return;
    }


    setState(() {
      _isLoggingOut =
          true;
    });


    try {
      await AuthService.logout();


      if (!mounted) {
        return;
      }


      Navigator.pushAndRemoveUntil(
        context,

        MaterialPageRoute(
          builder:
              (_) =>
                  const LoginScreen(),
        ),

        (_) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }


      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            error.toString(),
          ),

          backgroundColor:
              AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut =
              false;
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

        elevation:
            0,

        title:
            const Text(
          'Cuenta',

          style:
              TextStyle(
            color:
                AppColors.textPrimary,

            fontWeight:
                FontWeight.w700,
          ),
        ),

        iconTheme:
            const IconThemeData(
          color:
              AppColors.textPrimary,
        ),
      ),

      body:
          _isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : SafeArea(
                  top:
                      false,

                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      32,
                    ),

                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,

                      children: [
                        const SizedBox(
                          height:
                              12,
                        ),


                        // =========================
                        // FOTO
                        // =========================

                        Center(
                          child:
                              Container(
                            width:
                                112,

                            height:
                                112,

                            clipBehavior:
                                Clip.antiAlias,

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
                                _photoUrl.isNotEmpty
                                    ? Image.network(
                                        _photoUrl,

                                        fit:
                                            BoxFit.cover,

                                        errorBuilder:
                                            (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return const Icon(
                                            Icons.person_rounded,

                                            size:
                                                62,

                                            color:
                                                AppColors.textSecondary,
                                          );
                                        },
                                      )
                                    : const Icon(
                                        Icons.person_rounded,

                                        size:
                                            62,

                                        color:
                                            AppColors.textSecondary,
                                      ),
                          ),
                        ),


                        const SizedBox(
                          height:
                              18,
                        ),


                        // =========================
                        // NOMBRE
                        // =========================

                        Text(
                          _name.isNotEmpty
                              ? _name
                              : 'Usuario Sonelya',

                          textAlign:
                              TextAlign.center,

                          style:
                              const TextStyle(
                            color:
                                AppColors.textPrimary,

                            fontSize:
                                24,

                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),


                        if (_email.isNotEmpty) ...[
                          const SizedBox(
                            height:
                                6,
                          ),

                          Text(
                            _email,

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
                        ],


                        const SizedBox(
                          height:
                              36,
                        ),


                        // =========================
                        // CUENTA
                        // =========================

                        const Text(
                          'Cuenta',

                          style:
                              TextStyle(
                            color:
                                AppColors.textPrimary,

                            fontSize:
                                18,

                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),


                        const SizedBox(
                          height:
                              12,
                        ),


                        _accountTile(
                          icon:
                              Icons.person_outline_rounded,

                          title:
                              'Editar perfil',

                          subtitle:
                              'Nombre, usuario y foto',

                          onTap:
                              () {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content:
                                    Text(
                                  'Editar perfil lo añadiremos después',
                                ),
                              ),
                            );
                          },
                        ),
                        _accountTile(                                    // 👈 nuevo
                          icon: Icons.receipt_long_outlined,
                          title: 'Mis compras',
                          subtitle: 'Historial y estado de tus compras digitales',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()),
                            );
                          },
                        ),



                        _accountTile(
                          icon:
                              Icons.devices_rounded,

                          title:
                              'Dispositivos y sesiones',

                          subtitle:
                              'Administra dónde has iniciado sesión',

                          onTap:
                              () {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content:
                                    Text(
                                  'Dispositivos y sesiones lo añadiremos después',
                                ),
                              ),
                            );
                          },
                        ),


                        _accountTile(
                          icon:
                              Icons.notifications_none_rounded,

                          title:
                              'Notificaciones',

                          subtitle:
                              'Configura tus preferencias',

                          onTap:
                              () {},
                        ),


                        _accountTile(
                          icon:
                              Icons.privacy_tip_outlined,

                          title:
                              'Privacidad',

                          subtitle:
                              'Controla tu información',

                          onTap:
                              () {},
                        ),


                        const SizedBox(
                          height:
                              28,
                        ),


                        // =========================
                        // SONELYA
                        // =========================

                        const Text(
                          'Sonelya',

                          style:
                              TextStyle(
                            color:
                                AppColors.textPrimary,

                            fontSize:
                                18,

                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),


                        const SizedBox(
                          height:
                              12,
                        ),


                        _accountTile(
                          icon:
                              Icons.info_outline_rounded,

                          title:
                              'Acerca de Sonelya',

                          subtitle:
                              'Información de la aplicación',

                          onTap:
                              () {},
                        ),


                        const SizedBox(
                          height:
                              32,
                        ),


                        // =========================
                        // LOGOUT
                        // =========================

                        SizedBox(
                          height:
                              54,

                          child:
                              OutlinedButton.icon(
                            onPressed:
                                _isLoggingOut
                                    ? null
                                    : _logout,

                            icon:
                                _isLoggingOut
                                    ? const SizedBox(
                                        width:
                                            20,

                                        height:
                                            20,

                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2.3,

                                          color:
                                              AppColors.error,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.logout_rounded,
                                      ),

                            label:
                                Text(
                              _isLoggingOut
                                  ? 'Cerrando sesión...'
                                  : 'Cerrar sesión',
                            ),

                            style:
                                OutlinedButton.styleFrom(
                              foregroundColor:
                                  AppColors.error,

                              side:
                                  const BorderSide(
                                color:
                                    AppColors.error,
                              ),

                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  16,
                                ),
                              ),
                            ),
                          ),
                        ),


                        const SizedBox(
                          height:
                              18,
                        ),


                        const Text(
                          'Sonelya',

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


  // =========================
  // ITEM CUENTA
  // =========================

  Widget _accountTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom:
            10,
      ),

      child:
          Material(
        color:
            AppColors.surface,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        child:
            InkWell(
          onTap:
              onTap,

          borderRadius:
              BorderRadius.circular(
            16,
          ),

          child:
              Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal:
                  16,

              vertical:
                  15,
            ),

            child:
                Row(
              children: [
                Container(
                  width:
                      42,

                  height:
                      42,

                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.background,

                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),

                  child:
                      Icon(
                    icon,

                    color:
                        AppColors.textPrimary,
                  ),
                ),


                const SizedBox(
                  width:
                      14,
                ),


                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        title,

                        style:
                            const TextStyle(
                          color:
                              AppColors.textPrimary,

                          fontSize:
                              15,

                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),


                      const SizedBox(
                        height:
                            3,
                      ),


                      Text(
                        subtitle,

                        style:
                            const TextStyle(
                          color:
                              AppColors.textSecondary,

                          fontSize:
                              12,
                        ),
                      ),
                    ],
                  ),
                ),


                const Icon(
                  Icons.chevron_right_rounded,

                  color:
                      AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}