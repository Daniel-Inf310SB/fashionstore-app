import 'package:flutter/material.dart';

import '../../models/post_sale.dart';
import '../../services/post_sale_service.dart';
import 'post_sale_case_detail_screen.dart';
import 'return_style.dart';

class PostSaleRequestScreen extends StatefulWidget {
  const PostSaleRequestScreen({
    super.key,
    required this.channel,
    required this.sourceId,
    required this.sourceCode,
    required this.sourceItems,
  });

  final String channel;
  final int sourceId;
  final String sourceCode;
  final List<PostSaleSourceItem> sourceItems;

  @override
  State<PostSaleRequestScreen> createState() => _PostSaleRequestScreenState();
}

class _PostSaleRequestScreenState extends State<PostSaleRequestScreen> {
  final TextEditingController _reason = TextEditingController();
  final Map<int, int> _quantities = {};
  PostSaleEligibility? _eligibility;
  String _resolutionType = 'REFUND';
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadEligibility() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await PostSaleService.eligibility(
        channel: widget.channel,
        sourceId: widget.sourceId,
      );
      if (!mounted) return;
      setState(() => _eligibility = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final selected = Map<int, int>.from(_quantities)
      ..removeWhere((key, value) => value <= 0);
    final eligibility = _eligibility;
    if (eligibility == null || !eligibility.eligible || selected.isEmpty ||
        _reason.text.trim().length < 8 || _sending) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: ReturnStyle.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _resolutionType == 'EXCHANGE' ? 'CONFIRMAR SOLICITUD DE CAMBIO' : 'CONFIRMAR DEVOLUCIÓN',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ReturnStyle.ink),
              ),
              const SizedBox(height: 14),
              const Divider(color: ReturnStyle.line),
              const SizedBox(height: 8),
              Text(
                _resolutionType == 'EXCHANGE'
                    ? 'La sucursal revisará tu solicitud, recibirá e inspeccionará las prendas y después te informará las opciones de reemplazo y cualquier diferencia de precio.'
                    : 'La sucursal revisará tu solicitud. El reembolso no es automático y dependerá de la aprobación, recepción e inspección de los productos.',
                style: const TextStyle(color: ReturnStyle.grey, height: 1.5),
              ),
              const SizedBox(height: 22),
              ReturnStyle.button('ENVIAR SOLICITUD', () => Navigator.pop(dialogContext, true)),
              const SizedBox(height: 8),
              ReturnStyle.button('VOLVER', () => Navigator.pop(dialogContext, false), outline: true),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _sending = true);
    try {
      // Refresh the server-side eligibility immediately before creating the case.
      final fresh = await PostSaleService.eligibility(
        channel: widget.channel,
        sourceId: widget.sourceId,
      );
      final available = {for (final item in fresh.items) item.sourceItemId: item.availableQuantity};
      final stillValid = fresh.eligible &&
          selected.entries.every((entry) => (available[entry.key] ?? 0) >= entry.value);
      if (!stillValid) {
        if (mounted) {
          setState(() => _eligibility = fresh);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(fresh.reason ?? 'La disponibilidad cambió. Revisa las cantidades.')),
          );
        }
        return;
      }

      final result = await PostSaleService.create(
        channel: widget.channel,
        sourceId: widget.sourceId,
        resolutionType: _resolutionType,
        reason: _reason.text,
        items: selected,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PostSaleCaseDetailScreen(caseId: result.id)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibility = _eligibility;
    final allowed = {
      for (final item in eligibility?.items ?? const <PostSaleEligibleItem>[])
        item.sourceItemId: item.availableQuantity,
    };
    final canSubmit = !_loading && !_sending && eligibility?.eligible == true &&
        _quantities.values.any((value) => value > 0) &&
        _reason.text.trim().length >= 8;

    return Theme(
      data: ThemeData.light(useMaterial3: true),
      child: Scaffold(
        backgroundColor: ReturnStyle.canvas,
        appBar: ReturnStyle.appBar('DEVOLUCIONES Y CAMBIOS'),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: ReturnStyle.ink))
            : _error != null
                ? _errorView()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      _introCard(),
                      const SizedBox(height: 12),
                      if (eligibility != null) _eligibilityCard(eligibility),
                      if (eligibility?.eligible == true) ...[
                        const SizedBox(height: 12),
                        _resolutionCard(),
                        const SizedBox(height: 12),
                        _itemsCard(allowed),
                        const SizedBox(height: 12),
                        _reasonCard(),
                        const SizedBox(height: 18),
                        ReturnStyle.button(
                          _sending ? 'ENVIANDO SOLICITUD...' : 'CONTINUAR',
                          canSubmit ? _submit : null,
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _errorView() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.cloud_off_outlined, size: 46, color: ReturnStyle.grey),
          const SizedBox(height: 14),
          Text(_error ?? 'No se pudo consultar la compra.', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          ReturnStyle.button('REINTENTAR', _loadEligibility),
        ],
      );

  Widget _introCard() => ReturnStyle.section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SOLICITUD DE POSTVENTA', style: TextStyle(fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w900, color: ReturnStyle.grey)),
            const SizedBox(height: 7),
            Text(widget.sourceCode, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
            const SizedBox(height: 5),
            Text(widget.channel == 'POS' ? 'Compra presencial' : 'Pedido online', style: const TextStyle(color: ReturnStyle.grey)),
            const SizedBox(height: 10),
            const Text('Selecciona si deseas devolver las prendas o solicitar un cambio. La tienda confirmará la recepción y la resolución final.', style: TextStyle(color: ReturnStyle.grey, height: 1.45)),
          ],
        ),
      );

  Widget _eligibilityCard(PostSaleEligibility eligibility) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: eligibility.eligible ? const Color(0xFFF0F5F0) : const Color(0xFFF5EEEE),
          border: Border.all(color: eligibility.eligible ? const Color(0xFFD7E5D7) : const Color(0xFFEADADA)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(eligibility.eligible ? Icons.check_circle_outline : Icons.info_outline,
                color: ReturnStyle.ink, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                eligibility.eligible
                    ? 'Tu compra tiene artículos disponibles para solicitar una devolución o cambio. La sucursal revisará tu solicitud.'
                    : (eligibility.reason ?? 'Esta compra no tiene artículos disponibles para postventa.'),
                style: const TextStyle(fontSize: 13, height: 1.45, color: ReturnStyle.ink),
              ),
            ),
          ],
        ),
      );

  Widget _resolutionCard() => ReturnStyle.section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿QUÉ NECESITAS?', style: TextStyle(fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
            const SizedBox(height: 12),
            _choice(
              selected: _resolutionType == 'REFUND',
              icon: Icons.assignment_return_outlined,
              title: 'Devolver y solicitar reembolso',
              subtitle: 'Solicitas recuperar el importe reconocido de las prendas aprobadas.',
              onTap: () => setState(() => _resolutionType = 'REFUND'),
            ),
            const SizedBox(height: 8),
            _choice(
              selected: _resolutionType == 'EXCHANGE',
              icon: Icons.swap_horiz_rounded,
              title: 'Cambiar por otras prendas',
              subtitle: 'La sucursal te propondrá reemplazos y calculará si existe una diferencia.',
              onTap: () => setState(() => _resolutionType = 'EXCHANGE'),
            ),
          ],
        ),
      );

  Widget _choice({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1F1F1) : ReturnStyle.paper,
            border: Border.all(color: selected ? ReturnStyle.ink : ReturnStyle.line, width: selected ? 1.4 : 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: ReturnStyle.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ReturnStyle.ink)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.4, color: ReturnStyle.grey)),
                  ],
                ),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: ReturnStyle.ink, size: 20),
            ],
          ),
        ),
      );

  Widget _itemsCard(Map<int, int> allowed) => ReturnStyle.section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SELECCIONA LAS PRENDAS', style: TextStyle(fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
            const SizedBox(height: 5),
            ReturnStyle.label('Solo puedes seleccionar las unidades que el servidor marque como disponibles.'),
            const SizedBox(height: 10),
            ...widget.sourceItems.map((item) {
              final max = allowed[item.id] ?? 0;
              final selected = _quantities[item.id] ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ReturnStyle.line))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _productImage(item.imageUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: ReturnStyle.ink)),
                          const SizedBox(height: 3),
                          Text('${item.size} · ${item.color}', style: const TextStyle(fontSize: 11, color: ReturnStyle.grey)),
                          Text('SKU: ${item.sku}', style: const TextStyle(fontSize: 10, color: ReturnStyle.grey)),
                          Text('Disponibles: $max', style: const TextStyle(fontSize: 11, color: ReturnStyle.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    _quantityPicker(
                      value: selected,
                      max: max,
                      onChanged: (value) => setState(() => _quantities[item.id] = value),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );

  Widget _productImage(String? url) => Container(
        width: 62,
        height: 76,
        decoration: BoxDecoration(color: ReturnStyle.canvas, border: Border.all(color: ReturnStyle.line)),
        clipBehavior: Clip.antiAlias,
        child: url == null || url.trim().isEmpty
            ? const Icon(Icons.checkroom_outlined, color: ReturnStyle.grey, size: 28)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_outlined, color: ReturnStyle.grey, size: 28),
              ),
      );

  Widget _quantityPicker({
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 19),
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 19),
          ),
        ],
      );

  Widget _reasonCard() => ReturnStyle.section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MOTIVO', style: TextStyle(fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              maxLines: 4,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Cuéntanos por qué deseas devolver o cambiar estas prendas.',
                helperText: 'Mínimo 8 caracteres.',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: ReturnStyle.ink)),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Para cambios, la sucursal revisará la disponibilidad de reemplazo. Si hay una diferencia de precio, te informará antes de completar la operación.',
              style: TextStyle(color: ReturnStyle.grey, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      );
}
