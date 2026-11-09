import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../services/cart_service.dart';
import '../../services/selected_branch_service.dart';
import '../../services/main_tab_navigation_service.dart';

/// Resultado de una compra. La confirmación proviene exclusivamente de FastAPI,
/// que valida el intento directamente con Stripe y mantiene el webhook de respaldo.
class PaymentResultScreen extends StatefulWidget {
  const PaymentResultScreen({super.key, required this.orderId, this.paymentId});

  final int orderId;
  final int? paymentId;

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  static const _black = Color(0xFF151515);
  static const _gray = Color(0xFF707070);
  static const _bg = Color(0xFFF7F7F7);
  static const _edge = Color(0xFFE1E1E1);
  static const _maxAttempts = 12;
  CustomerOrder? _order;
  String? _error;
  bool _loading = true;
  bool _checking = false;
  int _attempts = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _confirmed(String status) => const {
    'PAID', 'PREPARING', 'READY_FOR_PICKUP', 'SHIPPED', 'DELIVERED', 'COMPLETED',
  }.contains(status);
  bool _failed(String status) => const {
    'CANCELLED', 'PAYMENT_FAILED', 'REFUNDED',
  }.contains(status);

  Future<void> _refresh() async {
    if (_checking) return;
    _checking = true;
    _timer?.cancel();
    try {
      // El servidor verifica Stripe antes de consultar el estado final del pedido.
      // Un fallo de red en esta verificación no equivale a un pago rechazado.
      if (widget.paymentId != null && widget.paymentId! > 0) {
        try {
          await PaymentService.reconcileStripePayment(widget.paymentId!);
        } catch (_) {
          // Conservamos el estado del pedido como fuente de la interfaz.
        }
      }
      final order = await OrderService.getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
        _loading = false;
      });
      if (_confirmed(order.status)) {
        // Pago verificado: actualizar contador y snapshot desde el servidor.
        unawaited(CartService.refreshAfterPurchase(
          SelectedBranchService.selectedBranch?.id,
        ));
      }
      if (!_confirmed(order.status) && !_failed(order.status) &&
          _attempts < _maxAttempts) {
        _attempts++;
        _timer = Timer(const Duration(seconds: 3), _refresh);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos actualizar el estado. Consulta Mis compras o vuelve a intentarlo.';
      });
    } finally {
      _checking = false;
    }
  }

  void _close() {
    // popUntil solo cerraba las pantallas de pago, pero dejaba seleccionada
    // la pestaña Carrito del IndexedStack. Ir explícitamente a Inicio.
    MainTabNavigationService.openHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final success = order != null && _confirmed(order.status);
    final failed = order != null && _failed(order.status);
    final pending = !success && !failed;
    final status = success ? 'PAGO CONFIRMADO' : failed ? 'PAGO NO CONFIRMADO' : 'VERIFICANDO PAGO';
    final title = success
        ? '¡Tu compra está confirmada!'
        : failed
            ? 'No se completó la compra'
            : 'Estamos verificando tu pago';
    final message = success
        ? 'Tu pedido está registrado. Podrás consultar cuándo esté listo para recoger en sucursal.'
        : failed
            ? 'Consulta el estado del pedido antes de intentar pagar de nuevo.'
            : 'Comprobamos tu pago directamente con Stripe. No vuelvas a pagar mientras se confirma el resultado.';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _black,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text('Resultado de compra', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _panel(child: Column(children: [
              const SizedBox(height: 8),
              if (_loading && order == null)
                const SizedBox(width: 55, height: 55, child: CircularProgressIndicator(color: _black, strokeWidth: 2))
              else
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(color: pending ? const Color(0xFFF3EDE0) : success ? const Color(0xFFE9F5ED) : const Color(0xFFFFEDEE), shape: BoxShape.circle),
                  child: Icon(success ? Icons.check_rounded : failed ? Icons.close_rounded : Icons.schedule_rounded,
                      size: 34, color: success ? const Color(0xFF15834A) : failed ? const Color(0xFFBE3347) : _black),
                ),
              const SizedBox(height: 20),
              Text(status, style: const TextStyle(color: _gray, letterSpacing: 1.6, fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _black, fontSize: 27, height: 1.14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 13),
              Text(_error ?? message, textAlign: TextAlign.center, style: const TextStyle(color: _gray, height: 1.5, fontSize: 14)),
              if (order != null) ...[
                const SizedBox(height: 22),
                const Divider(color: _edge),
                const SizedBox(height: 10),
                _line('Pedido', order.orderCode),
                _line('Importe', 'Bs ${order.totalAmount.toStringAsFixed(2)}'),
                _line('Unidades', '${order.totalUnits}'),
                _line('Estado', _statusLabel(order.status)),
              ],
              const SizedBox(height: 22),
              SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _black, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)), elevation: 0),
                onPressed: _close,
                child: const Text('VOLVER A FASHIONSTORE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .3)),
              )),
              if (pending) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _checking ? null : () { _attempts = 0; _refresh(); },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Volver a consultar'),
                  style: TextButton.styleFrom(foregroundColor: _black),
                ),
              ],
            ])),
            const SizedBox(height: 14),
            _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.storefront_outlined, color: _black), SizedBox(width: 10),
                Text('RETIRO EN SUCURSAL', style: TextStyle(color: _black, fontWeight: FontWeight.w900, fontSize: 13))]),
              const SizedBox(height: 10),
              const Text('Tu pedido se retira en la sucursal seleccionada una vez que la tienda confirme que está listo.',
                style: TextStyle(color: _gray, height: 1.5, fontSize: 13)),
            ])),
            const SizedBox(height: 14),
            _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.assignment_return_outlined, color: _black), SizedBox(width: 10),
                Text('CAMBIOS Y DEVOLUCIONES', style: TextStyle(color: _black, fontWeight: FontWeight.w900, fontSize: 13))]),
              const SizedBox(height: 12),
              const Text('FashionStore contempla un plazo comercial de 7 días desde la entrega efectiva para solicitar devoluciones elegibles.',
                style: TextStyle(color: _gray, height: 1.5, fontSize: 13)),
              const SizedBox(height: 9),
              const Text('Cuando recibas tus prendas, consulta Mis compras → Detalle → Consultar devolución. La tienda revisará la solicitud y el reembolso no es automático.',
                style: TextStyle(color: _gray, height: 1.5, fontSize: 13)),
              const SizedBox(height: 9),
              const Text('La elegibilidad y las excepciones aplicables deben ser confirmadas por FastAPI.',
                style: TextStyle(color: _gray, fontSize: 12, fontStyle: FontStyle.italic)),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _edge), borderRadius: BorderRadius.circular(9)),
    child: child,
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 88, child: Text(label, style: const TextStyle(color: _gray, fontSize: 13))),
      Expanded(child: Text(value, textAlign: TextAlign.end,
        style: const TextStyle(color: _black, fontWeight: FontWeight.w800, fontSize: 13))),
    ]),
  );

  String _statusLabel(String status) {
    const labels = {
      'PENDING_PAYMENT': 'Pendiente de pago', 'PAYMENT_FAILED': 'Pago fallido',
      'PAID': 'Pagada', 'PREPARING': 'En preparación',
      'READY_FOR_PICKUP': 'Lista para recoger', 'SHIPPED': 'Enviada',
      'DELIVERED': 'Entregada', 'COMPLETED': 'Finalizada',
      'CANCELLED': 'Cancelada', 'REFUNDED': 'Reembolsada',
    };
    return labels[status] ?? status;
  }
}
