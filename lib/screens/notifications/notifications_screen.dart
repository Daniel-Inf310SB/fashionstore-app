import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';

/// Pantalla de notificaciones con estética monocromática de tienda de moda.
/// Conserva los contratos existentes de NotificationService.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _ink = Color(0xFF151515);
  static const _canvas = Color(0xFFF7F7F7);
  static const _paper = Colors.white;
  static const _muted = Color(0xFF737373);
  static const _line = Color(0xFFE5E5E5);

  bool _loading = true;
  bool _markingAll = false;
  String? _error;
  NotificationPage? _page;
  int _filter = 0; // 0: todas, 1: no leídas, 2: leídas

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() => _page = page);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await NotificationService.markAllAsRead();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _ink,
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await NotificationService.markAsRead(notification.id);
      await _load();
    } catch (_) {
      // Conserva la notificación visible si no pudo actualizarse en el servidor.
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final unread = page?.unreadCount ?? 0;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _canvas,
        colorScheme: const ColorScheme.light(primary: _ink, surface: _paper),
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          titleSpacing: 0,
          title: const Text('Notificaciones', style: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w800, color: _ink,
          )),
          actions: [
            if (unread > 0)
              TextButton(
                onPressed: _markingAll ? null : _markAllRead,
                style: TextButton.styleFrom(foregroundColor: _ink),
                child: _markingAll
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Leer todas', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          color: _ink,
          onRefresh: _load,
          child: _buildBody(page),
        ),
      ),
    );
  }

  Widget _buildBody(NotificationPage? page) {
    if (_loading && page == null) {
      return const Center(child: CircularProgressIndicator(color: _ink));
    }
    if (_error != null && page == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 96, 24, 32),
        children: [
          const Icon(Icons.wifi_off_outlined, color: _muted, size: 56),
          const SizedBox(height: 18),
          const Text('NO PUDIMOS CARGAR TUS AVISOS',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.5)),
          const SizedBox(height: 24),
          _darkButton('REINTENTAR', _load),
        ],
      );
    }

    final all = page?.items ?? const <AppNotification>[];
    final visible = all.where((item) => _filter == 0 ||
        (_filter == 1 && !item.isRead) ||
        (_filter == 2 && item.isRead)).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        const Text('MI CUENTA / ACTUALIZACIONES',
          style: TextStyle(color: _muted, fontSize: 11,
            fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        const Text('Tu actividad', style: TextStyle(color: _ink,
          fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.6)),
        const SizedBox(height: 6),
        Text(page == null ? 'Consulta tus avisos y novedades.' :
          (page.unreadCount == 0 ? 'Estás al día con tus notificaciones.' :
           '${page.unreadCount} ${page.unreadCount == 1 ? 'notificación sin leer' : 'notificaciones sin leer'}'),
          style: const TextStyle(color: _muted, fontSize: 14)),
        const SizedBox(height: 22),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterButton('Todas', 0),
            const SizedBox(width: 8),
            _filterButton('Sin leer', 1),
            const SizedBox(width: 8),
            _filterButton('Leídas', 2),
          ]),
        ),
        const SizedBox(height: 22),
        if (_error != null && page != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _paper, border: Border.all(color: _line)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: _ink, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('No pudimos actualizar. Mostrando avisos anteriores.',
                style: TextStyle(fontSize: 12, color: _muted))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if (_loading && page != null) ...[
          const LinearProgressIndicator(color: _ink, backgroundColor: _line,
            minHeight: 2),
          const SizedBox(height: 12),
        ],
        if (visible.isEmpty)
          _emptyState(all.isEmpty)
        else ...[
          Text('${visible.length} ${visible.length == 1 ? 'AVISO' : 'AVISOS'}',
            style: const TextStyle(color: _muted, fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          for (final item in visible) ...[
            _notificationCard(item),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _filterButton(String label, int index) {
    final active = _filter == index;
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () => setState(() => _filter = index),
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? _ink : _paper,
          foregroundColor: active ? _paper : _ink,
          side: BorderSide(color: active ? _ink : _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 19),
        ),
        child: Text(label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _notificationCard(AppNotification item) {
    return Material(
      color: _paper,
      child: InkWell(
        onTap: () => _markRead(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: item.isRead ? _line : _ink, width: 1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(_iconForType(item.type), color: _ink, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(item.title,
                    style: TextStyle(color: _ink, fontSize: 15,
                      fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800))),
                  if (!item.isRead) ...[
                    const SizedBox(width: 8),
                    Container(width: 7, height: 7, decoration: const BoxDecoration(
                      color: _ink, shape: BoxShape.circle)),
                  ],
                ]),
                const SizedBox(height: 7),
                Text(item.message, style: const TextStyle(
                  color: _muted, fontSize: 13, height: 1.45)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text(_formatDate(item.createdAt),
                    style: const TextStyle(color: _muted, fontSize: 11))),
                  if (!item.isRead)
                    const Text('MARCAR LEÍDA', style: TextStyle(color: _ink,
                      fontSize: 10, fontWeight: FontWeight.w800,
                      letterSpacing: .4)),
                ]),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _emptyState(bool noNotifications) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 62),
      decoration: BoxDecoration(color: _paper,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(5)),
      child: Column(children: [
        const Icon(Icons.notifications_none_outlined, size: 58, color: _muted),
        const SizedBox(height: 18),
        Text(noNotifications ? 'AÚN NO TIENES NOTIFICACIONES' : 'NO HAY AVISOS EN ESTA CATEGORÍA',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontSize: 14,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Text(noNotifications
          ? 'Aquí encontrarás novedades de tus compras, reservas y promociones.'
          : 'Prueba otro filtro para consultar tus notificaciones.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.5)),
      ]),
    );
  }

  Widget _darkButton(String label, VoidCallback callback) {
    return SizedBox(height: 48, child: ElevatedButton(
      onPressed: callback,
      style: ElevatedButton.styleFrom(
        backgroundColor: _ink, foregroundColor: _paper,
        elevation: 0, shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4))),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ));
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'ORDER': return Icons.shopping_bag_outlined;
      case 'RESERVATION': return Icons.event_available_outlined;
      case 'PAYMENT': return Icons.credit_card_outlined;
      case 'PROMOTION': return Icons.local_offer_outlined;
      case 'COLLECTION': return Icons.checkroom_outlined;
      case 'SEASON': return Icons.style_outlined;
      default: return Icons.notifications_none_outlined;
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }
}
