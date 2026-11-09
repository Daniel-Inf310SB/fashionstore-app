import 'package:flutter/material.dart';

import '../../models/post_sale.dart';
import '../../models/purchase_order.dart';
import '../../models/pos_purchase.dart';
import '../../services/post_sale_service.dart';
import '../../services/purchase_service.dart';
import '../../services/pos_purchase_service.dart';
import 'return_style.dart';

class PostSaleCaseDetailScreen extends StatefulWidget {
  const PostSaleCaseDetailScreen({super.key, required this.caseId});
  final int caseId;

  @override
  State<PostSaleCaseDetailScreen> createState() => _PostSaleCaseDetailScreenState();
}

class _PostSaleCaseDetailScreenState extends State<PostSaleCaseDetailScreen> {
  PostSaleCase? _case;
  Map<int, PostSaleSourceItem> _sourceItems = {};
  String? _branchName;
  String? _sourceCode;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;

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
      final result = await PostSaleService.detail(widget.caseId);
      final items = <int, PostSaleSourceItem>{};
      String? branchName;
      String? sourceCode;
      try {
        if (result.sourceChannel == 'ONLINE') {
          final order = await PurchaseService.getOrder(result.sourceId);
          branchName = order.branch.name;
          sourceCode = order.orderCode;
          for (final item in order.items) {
            items[item.id] = PostSaleSourceItem(
              id: item.id,
              name: item.variant.productName,
              sku: item.variant.sku,
              size: item.variant.size,
              color: item.variant.color,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              subtotal: item.subtotal,
              imageUrl: item.variant.displayImageUrl,
            );
          }
        } else {
          final sale = await PosPurchaseService.detail(result.sourceId);
          branchName = sale.branch;
          sourceCode = sale.code;
          for (final item in sale.items) {
            items[item.id] = PostSaleSourceItem(
              id: item.id,
              name: item.name,
              sku: item.sku,
              size: item.size,
              color: item.color,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              subtotal: item.subtotal,
              imageUrl: item.imageUrl,
            );
          }
        }
      } catch (_) {
        // The post-sale case remains visible even if the original receipt cannot be enriched.
      }
      if (!mounted) return;
      setState(() {
        _case = result;
        _sourceItems = items;
        _branchName = branchName;
        _sourceCode = sourceCode;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ReturnStyle.paper,
        title: const Text('Cancelar solicitud'),
        content: const Text('Solo se pueden cancelar solicitudes que todavía no fueron revisadas. ¿Deseas continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ReturnStyle.ink, foregroundColor: ReturnStyle.paper),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await PostSaleService.cancel(widget.caseId);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postSale = _case;
    return Theme(
      data: ThemeData.light(useMaterial3: true),
      child: Scaffold(
        backgroundColor: ReturnStyle.canvas,
        appBar: ReturnStyle.appBar('DETALLE DE SOLICITUD'),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? ListView(children: [SizedBox(height: 210), Center(child: CircularProgressIndicator(color: ReturnStyle.ink))])
              : _error != null
                  ? ListView(padding: const EdgeInsets.all(24), children: [
                      const SizedBox(height: 100),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ReturnStyle.button('REINTENTAR', _load),
                    ])
                  : postSale == null
                      ? ListView(children: const [SizedBox(height: 150), Center(child: Text('No se encontró la solicitud.'))])
                      : _body(postSale),
        ),
      ),
    );
  }

  Widget _body(PostSaleCase postSale) {
    final statusTone = postSale.status == 'COMPLETED'
        ? const Color(0xFF267447)
        : postSale.status == 'REJECTED' || postSale.status == 'CANCELLED'
            ? const Color(0xFF9B3030)
            : ReturnStyle.ink;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        ReturnStyle.section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReturnStyle.label('${postSale.caseCode} · ${postSale.channelLabel.toUpperCase()}'),
              const SizedBox(height: 8),
              Text(postSale.resolutionLabel, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(3)),
                child: Text(postSale.statusLabel, style: TextStyle(color: statusTone, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(height: 12),
              ReturnStyle.label('Compra ${_sourceCode?.isNotEmpty == true ? _sourceCode : '#${postSale.sourceId}'} · Solicitud ${_date(postSale.createdAt)}'),
              if (_branchName != null && _branchName!.isNotEmpty) ...[
                const SizedBox(height: 5),
                ReturnStyle.label('Sucursal de atención: $_branchName'),
              ],
              if (postSale.staffNote != null && postSale.staffNote!.trim().isNotEmpty) ...[
                const Divider(height: 24, color: ReturnStyle.line),
                const Text('MENSAJE DE LA SUCURSAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                const SizedBox(height: 6),
                Text(postSale.staffNote!, style: const TextStyle(color: ReturnStyle.grey, height: 1.4)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        ReturnStyle.section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ARTÍCULOS SOLICITADOS', style: TextStyle(fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
              const SizedBox(height: 10),
              ...postSale.items.map((line) {
                final source = _sourceItems[line.sourceItemId];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ReturnStyle.line))),
                  child: Row(
                    children: [
                      _image(source?.imageUrl),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(source?.name ?? 'Artículo de compra #${line.sourceItemId}',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: ReturnStyle.ink)),
                            const SizedBox(height: 3),
                            Text('${source?.size ?? ''} ${source?.color ?? ''}'.trim(),
                                style: const TextStyle(fontSize: 11, color: ReturnStyle.grey)),
                            Text('Cantidad: ${line.quantity}', style: const TextStyle(fontSize: 11, color: ReturnStyle.grey)),
                          ],
                        ),
                      ),
                      Text('Bs ${line.originalTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: ReturnStyle.ink)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              _amountRow('Importe reconocido', postSale.originalAmount, strong: true),
            ],
          ),
        ),
        if (postSale.replacementItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          ReturnStyle.section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PRENDAS PROPUESTAS POR LA SUCURSAL', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...postSale.replacementItems.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _image(item.imageUrl),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName ?? 'Prenda de reemplazo', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${item.size ?? 'Sin talla'} · ${item.color ?? 'Sin color'}', style: const TextStyle(color: ReturnStyle.grey)),
                          Text('${item.sku ?? item.productCode ?? 'Sin SKU'} · ${item.quantity} unidad(es)', style: const TextStyle(color: ReturnStyle.grey)),
                        ],
                      )),
                      Text('Bs ${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                )),
                const Divider(color: ReturnStyle.line),
                _amountRow('Valor de reemplazo', postSale.replacementAmount),
                _amountRow(
                  postSale.differenceAmount > 0 ? 'Diferencia a pagar' : postSale.differenceAmount < 0 ? 'Diferencia a tu favor' : 'Diferencia',
                  postSale.differenceAmount.abs(),
                  strong: true,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        ReturnStyle.section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SEGUIMIENTO FINANCIERO', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (postSale.settlementKind == 'NONE')
                const Text('No se requiere un pago o reintegro adicional.', style: TextStyle(color: ReturnStyle.grey))
              else ...[
                _amountRow(
                  postSale.settlementKind == 'COLLECT' ? 'Diferencia por pagar' : 'Reintegro pendiente',
                  postSale.settlementAmount,
                  strong: true,
                ),
                const SizedBox(height: 5),
                Text(_settlementStatusLabel(postSale.settlementStatus),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: ReturnStyle.ink)),
                if (postSale.settlement != null) ...[
                  const SizedBox(height: 6),
                  ReturnStyle.label('Método: ${_modeLabel(postSale.settlement!.mode, postSale.settlement!.method)}'),
                  if (postSale.settlement!.reference?.isNotEmpty == true)
                    ReturnStyle.label('Referencia: ${postSale.settlement!.reference}'),
                ] else
                  ReturnStyle.label('La tienda te notificará cuando la liquidación esté confirmada.'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        ReturnStyle.section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HISTORIAL', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (postSale.events.isEmpty)
                ReturnStyle.label('Aún no hay movimientos registrados.')
              else
                ...postSale.events.map((event) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 9, color: ReturnStyle.ink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.actionLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            ReturnStyle.label(_date(event.createdAt)),
                            if (event.note != null && event.note!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(event.note!, style: const TextStyle(color: ReturnStyle.grey, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
        if (postSale.canCancel) ...[
          const SizedBox(height: 18),
          ReturnStyle.button(_cancelling ? 'CANCELANDO...' : 'CANCELAR SOLICITUD',
              _cancelling ? null : _cancel, outline: true),
        ],
      ],
    );
  }

  Widget _image(String? url) => Container(
        width: 54,
        height: 66,
        decoration: BoxDecoration(color: ReturnStyle.canvas, border: Border.all(color: ReturnStyle.line)),
        clipBehavior: Clip.antiAlias,
        child: url == null || url.isEmpty
            ? const Icon(Icons.checkroom_outlined, color: ReturnStyle.grey)
            : Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_outlined, color: ReturnStyle.grey)),
      );

  Widget _amountRow(String label, double amount, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: TextStyle(color: strong ? ReturnStyle.ink : ReturnStyle.grey, fontWeight: strong ? FontWeight.w900 : FontWeight.normal))),
            Text('Bs ${amount.toStringAsFixed(2)}', style: TextStyle(color: ReturnStyle.ink, fontWeight: FontWeight.w900, fontSize: strong ? 16 : 13)),
          ],
        ),
      );

  String _settlementStatusLabel(String value) => switch (value) {
    'NOT_REQUIRED' => 'No requiere liquidación',
    'PENDING' => 'Pendiente de confirmación',
    'PROCESSING' => 'En proceso',
    'COMPLETED' => 'Completada',
    'FAILED' => 'No completada',
    'MANUAL_REVIEW' => 'En revisión manual',
    _ => value,
  };

  String _modeLabel(String? mode, String? method) => switch (mode) {
    'DEMO_LOCAL' => 'Simulación de prueba',
    'EXTERNAL_MANUAL' => 'Reintegro externo',
    'STRIPE_TEST' => 'Stripe de prueba',
    'BRANCH_COLLECTION' => 'Cobro en sucursal',
    _ => method ?? 'Pendiente',
  };

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }
}
