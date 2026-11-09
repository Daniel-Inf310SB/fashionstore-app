import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'return_style.dart';
import '../../models/purchase_order.dart';
import '../../models/post_sale.dart';
import '../../services/purchase_service.dart';
import '../payments/payment_screen.dart';
import 'post_sale_request_screen.dart';
import '../../services/post_sale_service.dart';

class PurchaseDetailScreen extends StatefulWidget {
  const PurchaseDetailScreen({
    super.key,
    required this.orderId,
  });

  final int orderId;

  @override
  State<PurchaseDetailScreen> createState() =>
      _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState
    extends State<PurchaseDetailScreen> {
  PurchaseOrder? _order;
  bool _loading = true;
  String? _error;
  Future<PostSaleEligibility>? _postSaleEligibilityFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final order =
          await PurchaseService.getOrder(widget.orderId);

      if (!mounted) return;

      _postSaleEligibilityFuture = PostSaleService.eligibility(channel: 'ONLINE', sourceId: order.id);
      setState(() => _order = order);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _order = null;
        _error =
            error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pay(PurchaseOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          orderId: order.id,
        ),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      backgroundColor: ReturnStyle.canvas,
      appBar: AppBar(
        backgroundColor: ReturnStyle.paper,
        foregroundColor: ReturnStyle.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Detalle de compra', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(order),
      ),
    );
  }

  Widget _buildBody(PurchaseOrder? order) {
    if (_loading && order == null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (order == null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 100),
          Text(
            _error ?? 'No pudimos cargar la compra.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReturnStyle.grey,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ReturnStyle.ink, foregroundColor: ReturnStyle.paper),
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        32,
      ),
      children: [
        Text(
          order.orderCode,
          style: const TextStyle(
            color: ReturnStyle.ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          order.statusLabel,
          style: const TextStyle(
            color: ReturnStyle.ink,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Creada el ${_date(order.createdAt)}',
          style: const TextStyle(
            color: ReturnStyle.grey,
          ),
        ),
        if (order.paymentExpirationLabel().isNotEmpty) ...[
          const SizedBox(height: 16),
          _Notice(
            tone: order.paymentExpiringSoon()
                ? AppColors.warning
                : ReturnStyle.ink,
            title: order.paymentExpirationLabel(),
            message:
                'Límite: ${_date(order.paymentExpiresAt)}',
          ),
        ],
        if (order.isReadyForPickup) ...[
          const SizedBox(height: 16),
          _Notice(
            tone: AppColors.success,
            title:
                'Tu pedido está listo para recoger',
            message:
                'Ya puedes pasar por ${order.branch.name}.',
          ),
        ],
        const SizedBox(height: 16),
        _Panel(
          title: 'Productos',
          child: Column(
            children: order.items
                .map(
                  (item) => _ItemTile(item: item),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Entrega',
          child: Column(
            children: [
              _Row(
                label: 'Modalidad',
                value: order.deliveryLabel,
              ),
              _Row(
                label: 'Sucursal',
                value: order.branch.name,
              ),
              _Row(
                label: 'Dirección',
                value: order.shippingAddress ??
                    'Recojo en sucursal',
              ),
              _Row(
                label: 'Seguimiento',
                value: order.trackingCode ??
                    'Sin código todavía',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title:
              'Historial de pagos (${order.payments.length})',
          child: order.payments.isEmpty
              ? const Text(
                  'No hay intentos de pago todavía.',
                  style: TextStyle(
                    color: ReturnStyle.grey,
                  ),
                )
              : Column(
                  children: ([
                    ...order.payments,
                  ]..sort(
                          (a, b) =>
                              b.id.compareTo(a.id),
                        ))
                      .map(
                        (payment) => _PaymentTile(
                          payment: payment,
                        ),
                      )
                      .toList(),
                ),
        ),
        if (order.receipt != null) ...[
          const SizedBox(height: 14),
          _Panel(
            title: 'Comprobante',
            child: Column(
              children: [
                _Row(
                  label: 'Número',
                  value:
                      order.receipt!.receiptNumber,
                ),
                _Row(
                  label: 'Tipo',
                  value:
                      order.receipt!.receiptType,
                ),
                _Row(
                  label: 'Correo',
                  value:
                      order.receipt!.emailStatus,
                ),
              ],
            ),
          ),
        ],
        if (['PAID', 'PREPARING', 'READY_FOR_PICKUP', 'SHIPPED', 'DELIVERED', 'COMPLETED', 'REFUNDED'].contains(order.status)) ...[
          const SizedBox(height: 14),
          _Panel(
            title: 'Cambios y devoluciones',
            child: FutureBuilder<PostSaleEligibility>(
              future: _postSaleEligibilityFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(color: ReturnStyle.ink),
                  ));
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No pudimos comprobar si tu pedido admite una solicitud de postventa.',
                        style: TextStyle(color: ReturnStyle.grey),
                      ),
                      const SizedBox(height: 8),
                      ReturnStyle.button(
                        'REINTENTAR',
                        () => setState(() {
                          _postSaleEligibilityFuture = PostSaleService.eligibility(
                            channel: 'ONLINE',
                            sourceId: order.id,
                          );
                        }),
                        outline: true,
                      ),
                    ],
                  );
                }

                final eligibility = snapshot.data!;
                final canRequest = eligibility.eligible &&
                    eligibility.items.any((item) => item.availableQuantity > 0);
                final sourceItems = order.items.map((item) => PostSaleSourceItem(
                  id: item.id,
                  name: item.variant.productName,
                  sku: item.variant.sku,
                  size: item.variant.size,
                  color: item.variant.color,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                  subtotal: item.subtotal,
                  imageUrl: item.variant.displayImageUrl,
                )).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canRequest
                          ? 'Puedes solicitar una devolución de dinero o un cambio de prendas. La sucursal revisará tu solicitud.'
                          : (eligibility.reason ?? 'Este pedido no tiene artículos disponibles para postventa.'),
                      style: const TextStyle(color: ReturnStyle.grey, height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    ReturnStyle.button(
                      canRequest ? 'SOLICITAR DEVOLUCIÓN O CAMBIO' : 'NO DISPONIBLE',
                      canRequest
                          ? () async {
                              try {
                                final fresh = await PostSaleService.eligibility(
                                  channel: 'ONLINE',
                                  sourceId: order.id,
                                );
                                if (!mounted) return;
                                if (!fresh.eligible || !fresh.items.any((item) => item.availableQuantity > 0)) {
                                  setState(() {
                                    _postSaleEligibilityFuture = Future.value(fresh);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(fresh.reason ?? 'La compra ya no tiene artículos disponibles.')),
                                  );
                                  return;
                                }
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PostSaleRequestScreen(
                                      channel: 'ONLINE',
                                      sourceId: order.id,
                                      sourceCode: order.orderCode,
                                      sourceItems: sourceItems,
                                    ),
                                  ),
                                );
                                if (mounted) await _load();
                              } catch (error) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                                  );
                                }
                              }
                            }
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        _Panel(
          title: 'Resumen',
          child: Column(
            children: [
              _Row(
                label: 'Subtotal',
                value:
                    'Bs ${order.subtotal.toStringAsFixed(2)}',
              ),
              _Row(
                label: 'Descuento',
                value:
                    'Bs ${order.discountAmount.toStringAsFixed(2)}',
              ),
              const Divider(
                color: ReturnStyle.line,
              ),
              _Row(
                label: 'Total',
                value:
                    'Bs ${order.totalAmount.toStringAsFixed(2)}',
                emphasize: true,
              ),
              if (order.canPay) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: ReturnStyle.ink, foregroundColor: ReturnStyle.paper, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                    onPressed: () => _pay(order),
                    icon: const Icon(
                      Icons.credit_card_rounded,
                    ),
                    label: Text(
                      order.paymentActionLabel,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _date(DateTime value) {
    final d =
        value.day.toString().padLeft(2, '0');
    final m =
        value.month.toString().padLeft(2, '0');
    final h =
        value.hour.toString().padLeft(2, '0');
    final min =
        value.minute.toString().padLeft(2, '0');

    return '$d/$m/${value.year} $h:$min';
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ReturnStyle.paper,
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: ReturnStyle.line,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ReturnStyle.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
  });

  final PurchaseItem item;

  @override
  Widget build(BuildContext context) {
    final image =
        item.variant.displayImageUrl;

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: ReturnStyle.canvas,
              borderRadius:
                  BorderRadius.circular(4),
            ),
            child: image != null
                ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                            const Icon(
                      Icons.checkroom_rounded,
                      color: ReturnStyle.grey,
                    ),
                  )
                : const Icon(
                    Icons.checkroom_rounded,
                    color: ReturnStyle.grey,
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.variant.productName,
                  style: const TextStyle(
                    color:
                        ReturnStyle.ink,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.variant.size} · ${item.variant.color} · ${item.variant.sku}',
                  style: const TextStyle(
                    color:
                        ReturnStyle.grey,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} × Bs ${item.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color:
                        ReturnStyle.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Bs ${item.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color:
                  ReturnStyle.ink,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
  });

  final PurchasePayment payment;

  @override
  Widget build(BuildContext context) {
    final tone =
        payment.status == 'APPROVED'
            ? AppColors.success
            : [
                'FAILED',
                'REJECTED',
              ].contains(payment.status)
                ? AppColors.error
                : AppColors.warning;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ReturnStyle.canvas,
        borderRadius:
            BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${payment.provider ?? payment.paymentMethod} · ${payment.paymentCode}',
              style: const TextStyle(
                color:
                    ReturnStyle.ink,
                fontWeight:
                    FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            payment.statusLabel,
            style: TextStyle(
              color: tone,
              fontWeight:
                  FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.tone,
    required this.title,
    required this.message,
  });

  final Color tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            tone.withValues(alpha: 0.09),
        borderRadius:
            BorderRadius.circular(6),
        border: Border.all(
          color:
              tone.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tone,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              color:
                  ReturnStyle.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color:
                    ReturnStyle.grey,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: emphasize
                    ? ReturnStyle.ink
                    : ReturnStyle.ink,
                fontWeight:
                    FontWeight.w800,
                fontSize:
                    emphasize ? 18 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
