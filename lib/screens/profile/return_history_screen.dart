import 'package:flutter/material.dart';

import '../../models/post_sale.dart';
import '../../services/post_sale_service.dart';
import 'post_sale_case_detail_screen.dart';
import 'return_style.dart';

class ReturnHistoryScreen extends StatefulWidget {
  const ReturnHistoryScreen({super.key});

  @override
  State<ReturnHistoryScreen> createState() => _ReturnHistoryScreenState();
}

class _ReturnHistoryScreenState extends State<ReturnHistoryScreen> {
  List<PostSaleCase> _cases = [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';

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
      final result = await PostSaleService.mine(
        channel: _filter == 'ALL' ? null : _filter,
      );
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _cases = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setFilter(String value) async {
    if (_filter == value) return;
    setState(() => _filter = value);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light(useMaterial3: true),
      child: Scaffold(
        backgroundColor: ReturnStyle.canvas,
        appBar: ReturnStyle.appBar('MIS DEVOLUCIONES Y CAMBIOS'),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              ReturnStyle.section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('POSTVENTA', style: TextStyle(fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w900, color: ReturnStyle.grey)),
                    const SizedBox(height: 6),
                    const Text('Tus solicitudes', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                    const SizedBox(height: 5),
                    const Text('Consulta devoluciones de dinero y cambios de compras online o presenciales.', style: TextStyle(color: ReturnStyle.grey, height: 1.4)),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _filterChip('ALL', 'Todas'),
                        _filterChip('ONLINE', 'Online'),
                        _filterChip('POS', 'Presenciales'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 70),
                  child: Center(child: CircularProgressIndicator(color: ReturnStyle.ink)),
                )
              else if (_error != null)
                _message(
                  icon: Icons.cloud_off_outlined,
                  title: 'No pudimos cargar tus solicitudes',
                  message: _error!,
                  action: ReturnStyle.button('REINTENTAR', _load),
                )
              else if (_cases.isEmpty)
                _message(
                  icon: Icons.assignment_return_outlined,
                  title: 'Todavía no tienes solicitudes',
                  message: _filter == 'ALL'
                      ? 'Cuando solicites una devolución o un cambio desde el detalle de una compra, aparecerá aquí.'
                      : 'No hay solicitudes para este tipo de compra.',
                )
              else ..._cases.map(_caseCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _setFilter(value),
      selectedColor: ReturnStyle.ink,
      backgroundColor: ReturnStyle.paper,
      side: BorderSide(color: selected ? ReturnStyle.ink : ReturnStyle.line),
      labelStyle: TextStyle(
        color: selected ? ReturnStyle.paper : ReturnStyle.ink,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _caseCard(PostSaleCase item) {
    final tone = item.status == 'COMPLETED'
        ? const Color(0xFF267447)
        : item.status == 'REJECTED' || item.status == 'CANCELLED'
            ? const Color(0xFF9B3030)
            : ReturnStyle.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PostSaleCaseDetailScreen(caseId: item.id)),
          );
          if (mounted) _load();
        },
        child: ReturnStyle.section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.caseCode, style: const TextStyle(fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                  ),
                  const Icon(Icons.chevron_right, color: ReturnStyle.grey),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _tag(item.sourceChannel == 'POS' ? 'PRESENCIAL' : 'ONLINE'),
                  const SizedBox(width: 7),
                  _tag(item.resolutionType == 'EXCHANGE' ? 'CAMBIO' : 'REEMBOLSO'),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.statusLabel, style: TextStyle(color: tone, fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 6),
              ReturnStyle.label('Compra #${item.sourceId} · ${_date(item.createdAt)}'),
              const Divider(height: 20, color: ReturnStyle.line),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ReturnStyle.label('${item.items.fold<int>(0, (sum, line) => sum + line.quantity)} unidad(es)'),
                  Text('Bs ${item.originalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
                ],
              ),
              if (item.staffNote != null && item.staffNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.staffNote!, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ReturnStyle.grey, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: const BoxDecoration(color: ReturnStyle.canvas),
        child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .5, color: ReturnStyle.ink)),
      );

  Widget _message({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) =>
      ReturnStyle.section(
        child: Column(
          children: [
            Icon(icon, size: 42, color: ReturnStyle.grey),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ReturnStyle.ink)),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: ReturnStyle.grey, height: 1.4)),
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      );

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
