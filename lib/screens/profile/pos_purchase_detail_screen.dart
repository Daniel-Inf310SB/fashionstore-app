import 'package:flutter/material.dart';

import '../../models/pos_purchase.dart';
import '../../models/post_sale.dart';
import '../../services/pos_purchase_service.dart';
import '../../services/post_sale_service.dart';
import 'post_sale_request_screen.dart';
import 'return_style.dart';

class PosPurchaseDetailScreen extends StatefulWidget {
  const PosPurchaseDetailScreen({super.key, required this.saleId});
  final int saleId;

  @override
  State<PosPurchaseDetailScreen> createState() => _PosPurchaseDetailScreenState();
}

class _PosPurchaseDetailScreenState extends State<PosPurchaseDetailScreen> {
  late final Future<PosPurchase> _future = PosPurchaseService.detail(widget.saleId);
  late Future<PostSaleEligibility> _eligibilityFuture = _loadEligibility();

  Future<PostSaleEligibility> _loadEligibility() => PostSaleService.eligibility(
        channel: 'POS',
        sourceId: widget.saleId,
      );

  Future<void> _refreshEligibility() async {
    setState(() => _eligibilityFuture = _loadEligibility());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ReturnStyle.canvas,
        appBar: AppBar(
          title: const Text('Compra presencial'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: FutureBuilder<PosPurchase>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: ReturnStyle.ink));
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No se pudo consultar la venta: ${snapshot.error}'),
                ),
              );
            }
            final sale = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              children: [
                ReturnStyle.section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReturnStyle.label('COMPROBANTE DE COMPRA'),
                      const SizedBox(height: 7),
                      Text(sale.code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                      const SizedBox(height: 7),
                      Text('${sale.statusLabel} · ${sale.branch}', style: const TextStyle(color: ReturnStyle.grey)),
                      Text('Método de pago: ${sale.paymentLabel}', style: const TextStyle(color: ReturnStyle.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ReturnStyle.section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PRODUCTOS', style: TextStyle(fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                      const SizedBox(height: 8),
                      ...sale.items.map((item) => _purchaseItem(item)),
                      const Divider(color: ReturnStyle.line, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
                          Text('Bs ${sale.amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _postSalePanel(sale),
              ],
            );
          },
        ),
      );

  Widget _purchaseItem(PosPurchaseItem item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 70,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: ReturnStyle.canvas, border: Border.all(color: ReturnStyle.line)),
              child: item.imageUrl == null || item.imageUrl!.isEmpty
                  ? const Icon(Icons.checkroom_outlined, color: ReturnStyle.grey)
                  : Image.network(item.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_outlined, color: ReturnStyle.grey)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, color: ReturnStyle.ink)),
                  const SizedBox(height: 3),
                  Text('${item.size} · ${item.color} · ${item.sku}', style: const TextStyle(fontSize: 11, color: ReturnStyle.grey)),
                  Text('${item.quantity} × Bs ${item.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: ReturnStyle.grey)),
                ],
              ),
            ),
            Text('Bs ${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _postSalePanel(PosPurchase sale) => ReturnStyle.section(
        child: FutureBuilder<PostSaleEligibility>(
          future: _eligibilityFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CAMBIOS Y DEVOLUCIONES', style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 12),
                  Center(child: CircularProgressIndicator(color: ReturnStyle.ink)),
                ],
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CAMBIOS Y DEVOLUCIONES', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  const Text(
                    'No pudimos validar esta venta para postventa. Si la compra no está asociada a tu cuenta, presenta el comprobante en la sucursal.',
                    style: TextStyle(color: ReturnStyle.grey, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  ReturnStyle.button('REINTENTAR', _refreshEligibility, outline: true),
                ],
              );
            }
            final eligibility = snapshot.data!;
            final canRequest = eligibility.eligible &&
                eligibility.items.any((item) => item.availableQuantity > 0);
            final sourceItems = sale.items
                .map((item) => PostSaleSourceItem(
                      id: item.id,
                      name: item.name,
                      sku: item.sku,
                      size: item.size,
                      color: item.color,
                      quantity: item.quantity,
                      unitPrice: item.unitPrice,
                      subtotal: item.subtotal,
                      imageUrl: item.imageUrl,
                    ))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CAMBIOS Y DEVOLUCIONES', style: TextStyle(fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                const SizedBox(height: 7),
                Text(
                  canRequest
                      ? 'Puedes solicitar una devolución de dinero o un cambio de prendas. La sucursal revisará tu solicitud.'
                      : (eligibility.reason ?? 'Esta compra no tiene artículos disponibles para postventa.'),
                  style: const TextStyle(color: ReturnStyle.grey, height: 1.4),
                ),
                const SizedBox(height: 12),
                ReturnStyle.button(
                  canRequest ? 'SOLICITAR DEVOLUCIÓN O CAMBIO' : 'NO DISPONIBLE',
                  canRequest
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostSaleRequestScreen(
                                channel: 'POS',
                                sourceId: sale.id,
                                sourceCode: sale.code,
                                sourceItems: sourceItems,
                              ),
                            ),
                          );
                          if (mounted) _refreshEligibility();
                        }
                      : null,
                ),
              ],
            );
          },
        ),
      );
}
