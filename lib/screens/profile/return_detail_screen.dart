import 'package:flutter/material.dart';
import '../../models/purchase_order.dart';
import '../../models/return_request.dart';
import '../../services/purchase_service.dart';
import '../../services/return_service.dart';
import 'return_product_tile.dart';
import 'return_style.dart';

class ReturnDetailScreen extends StatefulWidget {
  const ReturnDetailScreen({super.key, required this.returnId});
  final int returnId;
  @override
  State<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends State<ReturnDetailScreen> {
  CustomerReturn? request;
  PurchaseOrder? order;
  ReturnRefundStatus? refund;
  String? error;
  bool loading = true, cancelling = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await ReturnService.detail(widget.returnId);
      // Order details and refund status are optional extras: a failure must
      // not hide an otherwise valid return request.
      PurchaseOrder? purchase;
      ReturnRefundStatus? status;
      try { purchase = await PurchaseService.getOrder(result.orderId); } catch (_) {}
      try { status = await ReturnService.refundStatus(widget.returnId); } catch (_) {}
      if (mounted) setState(() { request = result; order = purchase; refund = status; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cancel() async {
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: ReturnStyle.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CANCELAR DEVOLUCIÓN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
            const SizedBox(height: 12),
            const Text('¿Quieres cancelar esta solicitud? Esta acción no puede deshacerse.',
              style: TextStyle(color: ReturnStyle.grey, height: 1.5)),
            const SizedBox(height: 22),
            ReturnStyle.button('SÍ, CANCELAR', () => Navigator.pop(dialogContext, true)),
            const SizedBox(height: 10),
            ReturnStyle.button('VOLVER', () => Navigator.pop(dialogContext, false), outline: true),
          ]),
        ),
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => cancelling = true);
    try {
      await ReturnService.cancel(widget.returnId);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Theme(
      data: ThemeData.light(useMaterial3: true),
      child: Scaffold(
        backgroundColor: ReturnStyle.canvas,
        appBar: ReturnStyle.appBar('DETALLE DE DEVOLUCIÓN'),
        body: RefreshIndicator(
          onRefresh: _load,
          child: loading
              ? ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator(color: ReturnStyle.ink))])
              : error != null
                  ? ListView(padding: const EdgeInsets.all(24), children: [
                      const SizedBox(height: 100), Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 20), ReturnStyle.button('REINTENTAR', _load),
                    ])
                  : r == null
                      ? ListView(children: const [SizedBox(height: 150), Center(child: Text('No se encontró la devolución'))])
                      : ListView(padding: const EdgeInsets.all(16), children: [
                          ReturnStyle.section(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ReturnStyle.label('SOLICITUD #${r.id} · ${order?.orderCode ?? 'PEDIDO #${r.orderId}'}'),
                            const SizedBox(height: 10),
                            Text(r.statusLabel, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                            const SizedBox(height: 8),
                            ReturnStyle.label('Registrada ${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}'),
                            const Divider(height: 28, color: ReturnStyle.line),
                            const Text('MOTIVO', style: TextStyle(color: ReturnStyle.ink, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8), Text(r.reason),
                            if (r.adminNote != null && r.adminNote!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text('RESPUESTA DE LA TIENDA', style: TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6), Text(r.adminNote!),
                            ],
                          ])),
                          const SizedBox(height: 12),
                          ReturnStyle.section(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('PRENDAS SOLICITADAS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                            const SizedBox(height: 8),
                            if (r.items.isEmpty) ReturnStyle.label('No se recibieron detalles de prendas.'),
                            ...r.items.asMap().entries.map((entry) => Column(children: [
                              if (entry.key > 0) const Divider(color: ReturnStyle.line),
                              ReturnProductTile(item: entry.value, order: order),
                            ])),
                          ])),
                          const SizedBox(height: 12),
                          ReturnStyle.section(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('REEMBOLSO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                            const SizedBox(height: 12),
                            Text(refund == null ? 'Estado no disponible' : _refundLabel(refund!.status),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: ReturnStyle.ink)),
                            if (refund?.amount != null) ...[
                              const SizedBox(height: 8), Text('${refund!.amount} ${refund!.currency ?? ''}'),
                            ],
                            const SizedBox(height: 10),
                            ReturnStyle.label('La aprobación de la solicitud no implica un reembolso inmediato.'),
                          ])),
                          if (r.status == 'REQUESTED') ...[
                            const SizedBox(height: 18),
                            ReturnStyle.button(cancelling ? 'CANCELANDO...' : 'CANCELAR SOLICITUD', cancelling ? null : _cancel),
                          ],
                          const SizedBox(height: 24),
                        ]),
        ),
      ),
    );
  }

  String _refundLabel(String s) => switch (s) {
    'NOT_STARTED' => 'Todavía no iniciado',
    'SUCCEEDED' => 'Reembolso completado',
    'PENDING' => 'Pendiente',
    'PROCESSING' => 'En proceso',
    'FAILED' => 'No completado',
    _ => s,
  };
}
