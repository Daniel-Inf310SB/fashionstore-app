import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'return_style.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'purchase_history_screen.dart';
import 'return_history_screen.dart';


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
              ReturnStyle.paper,

          title:
              const Text(
            'Cerrar sesión',

            style:
                TextStyle(
              color:
                  ReturnStyle.ink,

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
                  ReturnStyle.grey,
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
  // PRESENTACIÓN DEL PERFIL (estilo tienda de moda)
  // La autenticación, los destinos y las acciones se conservan.
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReturnStyle.canvas,
      appBar: ReturnStyle.appBar('Mi cuenta'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ReturnStyle.ink))
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _profileHeader(),
                    const SizedBox(height: 24),
                    _sectionTitle('MI CUENTA'),
                    const SizedBox(height: 10),
                    _settingsGroup([
                      _accountTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Editar perfil',
                        subtitle: 'Nombre, usuario y foto',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Editar perfil lo añadiremos después')),
                          );
                        },
                      ),
                      _accountTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Mis compras',
                        subtitle: 'Pedidos, pagos y seguimiento',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()),
                        ),
                      ),
                      _accountTile(
                        icon: Icons.assignment_return_outlined,
                        title: 'Mis devoluciones y cambios',
                        subtitle: 'Devoluciones y cambios de compras online y presenciales',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReturnHistoryScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _sectionTitle('CONFIGURACIÓN'),
                    const SizedBox(height: 10),
                    _settingsGroup([
                      _accountTile(
                        icon: Icons.devices_outlined,
                        title: 'Dispositivos y sesiones',
                        subtitle: 'Administra dónde has iniciado sesión',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Dispositivos y sesiones lo añadiremos después')),
                          );
                        },
                      ),
                      _accountTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notificaciones',
                        subtitle: 'Configura tus preferencias',
                        onTap: () {},
                      ),
                      _accountTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacidad',
                        subtitle: 'Controla tu información',
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _sectionTitle('SONELYA'),
                    const SizedBox(height: 10),
                    _settingsGroup([
                      _accountTile(
                        icon: Icons.info_outline,
                        title: 'Acerca de Sonelya',
                        subtitle: 'Información de la aplicación',
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 26),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isLoggingOut ? null : _logout,
                        icon: _isLoggingOut
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: ReturnStyle.ink),
                              )
                            : const Icon(Icons.logout_rounded, size: 20),
                        label: Text(_isLoggingOut ? 'Cerrando sesión...' : 'Cerrar sesión'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ReturnStyle.ink,
                          side: const BorderSide(color: ReturnStyle.ink, width: 1),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'SONELYA',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: ReturnStyle.grey),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _profileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: ReturnStyle.paper,
        border: Border.all(color: ReturnStyle.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            height: 76,
            width: 76,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: ReturnStyle.canvas,
              shape: BoxShape.circle,
              border: Border.all(color: ReturnStyle.line),
            ),
            child: _photoUrl.isNotEmpty
                ? Image.network(
                    _photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person_outline_rounded, size: 40, color: ReturnStyle.ink),
                  )
                : const Icon(Icons.person_outline_rounded, size: 40, color: ReturnStyle.ink),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BIENVENIDO/A', style: TextStyle(fontSize: 10, color: ReturnStyle.grey, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
                const SizedBox(height: 6),
                Text(
                  _name.isNotEmpty ? _name : 'Usuario Sonelya',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, height: 1.12, color: ReturnStyle.ink, fontWeight: FontWeight.w800),
                ),
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(_email, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: ReturnStyle.grey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(title,
      style: const TextStyle(color: ReturnStyle.ink, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
  );

  Widget _settingsGroup(List<Widget> tiles) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: ReturnStyle.paper,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ReturnStyle.line),
    ),
    child: Column(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i != 0) const Divider(height: 1, thickness: 1, color: ReturnStyle.line, indent: 62),
          tiles[i],
        ],
      ],
    ),
  );

  Widget _accountTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: ReturnStyle.paper,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: ReturnStyle.ink, size: 23),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: ReturnStyle.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: ReturnStyle.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ReturnStyle.grey, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}
