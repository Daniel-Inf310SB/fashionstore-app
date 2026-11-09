import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../models/order.dart';
import '../../models/payment.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../services/stripe_mobile_service.dart';
import '../../widgets/payments/payment_expiration_banner.dart';
import '../../widgets/payments/payment_order_summary_card.dart';
import 'payment_result_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
  });

  final int orderId;

  @override
  State<PaymentScreen> createState() =>
      _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  CustomerOrder? _order;
  List<PaymentMethodOption> _methods = const [];
  ElectronicPayment? _payment;

  bool _loading = true;
  bool _preparing = false;
  bool _paying = false;

  String? _error;
  String? _clientSecret;

  Timer? _clock;
  DateTime _now = DateTime.now();

  bool get _paymentExpired {
    final order = _order;

    if (order == null ||
        ![
          'PENDING_PAYMENT',
          'PAYMENT_FAILED',
        ].contains(order.status)) {
      return false;
    }

    return !order.paymentExpiresAt.isAfter(_now);
  }

  bool get _paymentAllowed {
    final order = _order;

    return order != null &&
        !_paymentExpired &&
        [
          'PENDING_PAYMENT',
          'PAYMENT_FAILED',
        ].contains(order.status);
  }

  @override
  void initState() {
    super.initState();

    _load();

    _clock = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (!mounted) return;

        setState(() {
          _now = DateTime.now();
        });

        if (_paymentExpired && !_paying) {
          _refreshOrderAfterExpiration();
        }
      },
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final order =
          await OrderService.getOrder(widget.orderId);

      if (!mounted) return;

      setState(() {
        _order = order;
        _now = DateTime.now();
      });

      if (_isConfirmed(order.status)) {
        _openResult();
        return;
      }

      if ([
        'CANCELLED',
        'REFUNDED',
      ].contains(order.status)) {
        setState(() {
          _error = order.status == 'CANCELLED'
              ? 'Esta compra fue cancelada y ya no admite pagos.'
              : 'Esta compra fue reembolsada y ya no admite pagos.';
        });
        return;
      }

      if (_paymentExpired) {
        setState(() {
          _error =
              'El tiempo para completar el pago terminó. Actualizando la compra...';
        });
        await _refreshOrderAfterExpiration();
        return;
      }

      await _loadMethodsAndPrepareStripe();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error =
            error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMethodsAndPrepareStripe() async {
    final methods = await PaymentService.getPaymentMethods();

    if (!mounted) return;

    setState(() {
      _methods = methods;
    });

    await _prepareStripe();
  }

  Future<void> _prepareStripe() async {
    if (_preparing ||
        _clientSecret != null ||
        !_paymentAllowed) {
      return;
    }

    setState(() {
      _preparing = true;
      _error = null;
    });

    try {
      final response =
          await PaymentService.createStripePaymentIntent(
        widget.orderId,
      );

      await StripeMobileService.preparePaymentSheet(
        publishableKey: response.publishableKey,
        clientSecret: response.clientSecret,
      );

      if (!mounted) return;

      setState(() {
        _payment = response.payment;
        _clientSecret = response.clientSecret;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error =
            error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _preparing = false;
        });
      }
    }
  }

  Future<void> _pay() async {
    if (_paying ||
        !_paymentAllowed ||
        _clientSecret == null) {
      return;
    }

    setState(() {
      _paying = true;
      _error = null;
    });

    try {
      await StripeMobileService.presentPaymentSheet();

      if (!mounted) return;

      _openResult();
    } on StripeException catch (error) {
      if (!mounted) return;

      if (error.error.code == FailureCode.Canceled) {
        setState(() {
          _error = null;
        });
      } else {
        setState(() {
          _error =
              error.error.localizedMessage ??
              'Stripe rechazó el pago.';
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error =
            error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _paying = false;
        });
      }
    }
  }

  Future<void> _refreshOrderAfterExpiration() async {
    try {
      final order =
          await OrderService.getOrder(widget.orderId);

      if (!mounted) return;

      setState(() {
        _order = order;

        if (order.status == 'CANCELLED') {
          _error =
              'El plazo de pago venció. La compra fue cancelada y el stock reservado fue liberado.';
          _clientSecret = null;
        }
      });
    } catch (_) {}
  }

  void _openResult() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(
          orderId: widget.orderId,
          paymentId: _payment?.id,
        ),
      ),
    );
  }

  bool _isConfirmed(String status) {
    return [
      'PAID',
      'PREPARING',
      'READY_FOR_PICKUP',
      'SHIPPED',
      'DELIVERED',
      'COMPLETED',
    ].contains(status);
  }

  String get _expirationLabel {
    final order = _order;

    if (order == null) return '';

    final remaining =
        order.paymentExpiresAt.difference(_now);

    if (remaining <= Duration.zero) {
      return 'El tiempo para pagar ya venció';
    }

    final minutes = remaining.inMinutes + 1;

    if (minutes < 60) {
      return 'Quedan $minutes min para pagar';
    }

    final hours = minutes ~/ 60;
    final rest = minutes % 60;

    return rest == 0
        ? 'Quedan $hours h para pagar'
        : 'Quedan $hours h $rest min para pagar';
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        surfaceTintColor: Colors.transparent,
        title: const Text('Pago seguro', style: TextStyle(color: Color(0xFF151515), fontWeight: FontWeight.w700, fontSize: 19)),
        iconTheme: const IconThemeData(color: Color(0xFF151515)),
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(order),
      ),
    );
  }

  Widget _buildBody(CustomerOrder? order) {
    if (_loading && order == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator(color: Color(0xFF151515))),
        ],
      );
    }

    if (order == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline_rounded,
            color: const Color(0xFFB72C3A),
            size: 54,
          ),
          const SizedBox(height: 14),
          Text(
            _error ?? 'No pudimos cargar la compra.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: const Color(0xFF626262),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF151515), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), minimumSize: const Size.fromHeight(52)),
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      children: [
        const Text(
          'FASHIONSTORE / PAGO SEGURO',
          style: TextStyle(
            color: const Color(0xFF151515),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Confirma tu pago',
          style: TextStyle(
            color: const Color(0xFF151515),
            fontSize: 29,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pago protegido con Stripe. Nunca almacenamos los datos de tu tarjeta.',
          style: TextStyle(
            color: const Color(0xFF626262),
            height: 1.35,
          ),
        ),
        if ([
          'PENDING_PAYMENT',
          'PAYMENT_FAILED',
        ].contains(order.status)) ...[
          const SizedBox(height: 16),
          PaymentExpirationBanner(
            label: _expirationLabel,
            deadline: _date(order.paymentExpiresAt),
            expired: _paymentExpired,
          ),
        ],
        const SizedBox(height: 16),
        if (_paymentExpired ||
            order.status == 'CANCELLED') ...[
          _BlockedCard(
            message: _error ??
                'El tiempo disponible para completar el pago terminó.',
          ),
        ] else ...[
          _PaymentMethodCard(
            methods: _methods,
            preparing: _preparing,
            paymentReady: _clientSecret != null,
            error: _error,
          ),
          const SizedBox(height: 14),
          PaymentOrderSummaryCard(order: order),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF151515), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFBDBDBD), disabledForegroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .3)),
              onPressed: _paymentAllowed &&
                      _clientSecret != null &&
                      !_preparing &&
                      !_paying
                  ? _pay
                  : null,
              icon: _paying || _preparing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.lock_rounded),
              label: Text(
                _paying
                    ? 'Confirmando pago...'
                    : _preparing
                        ? 'Preparando Stripe...'
                        : 'Pagar Bs ${order.totalAmount.toStringAsFixed(2)}',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.methods,
    required this.preparing,
    required this.paymentReady,
    required this.error,
  });

  final List<PaymentMethodOption> methods;
  final bool preparing;
  final bool paymentReady;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Método de pago',
            style: TextStyle(
              color: const Color(0xFF151515),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (methods.isEmpty && preparing)
            const LinearProgressIndicator(color: Color(0xFF151515), backgroundColor: Color(0xFFE8E8E8))
          else
            for (final method in methods)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.credit_card_rounded,
                      color: const Color(0xFF151515),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.name,
                            style: const TextStyle(
                              color: const Color(0xFF151515),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            method.description ??
                                method.provider,
                            style: const TextStyle(
                              color: const Color(0xFF868686),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Icon(
                  paymentReady
                      ? Icons.check_circle_rounded
                      : Icons.sync_rounded,
                  color: paymentReady
                      ? const Color(0xFF238562)
                      : const Color(0xFF151515),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    paymentReady
                        ? 'Stripe está listo. Al pagar se abrirá la hoja segura para ingresar la tarjeta.'
                        : 'Preparando el formulario seguro de Stripe...',
                    style: const TextStyle(
                      color: const Color(0xFF626262),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(
                color: const Color(0xFFB72C3A),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BlockedCard extends StatelessWidget {
  const _BlockedCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFB72C3A).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFB72C3A).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_disabled_rounded,
            color: const Color(0xFFB72C3A),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta compra ya no puede pagarse',
                  style: TextStyle(
                    color: const Color(0xFFB72C3A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: const Color(0xFF626262),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
