import 'dart:async';

import 'package:flutter/material.dart';

import 'return_style.dart';
import '../../models/purchase_order.dart';
import '../../services/purchase_service.dart';
import '../../services/ai_assistant_context_service.dart';
import '../../widgets/orders/purchase_order_card.dart';
import 'purchase_detail_screen.dart';
import '../../models/pos_purchase.dart';
import '../../services/pos_purchase_service.dart';
import 'pos_purchase_detail_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() =>
      _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState
    extends State<PurchaseHistoryScreen> {
  static const _statuses = <String?>[
    null,
    'PENDING_PAYMENT',
    'PAID',
    'PREPARING',
    'READY_FOR_PICKUP',
    'SHIPPED',
    'DELIVERED',
    'COMPLETED',
    'PAYMENT_FAILED',
    'CANCELLED',
    'REFUNDED',
  ];

  List<PurchaseOrder> _items = const [];
  List<PosPurchase> _posItems = const [];
  bool _presencial = false;
  String? _paymentMethod;
  int _requestVersion = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  int _page = 1;
  int _total = 0;
  int _totalPages = 0;

  String? _status;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  DateTime _now = DateTime.now();

  Timer? _clock;

  @override
  void initState() {
    super.initState();
    AIAssistantContextService.setPage('orders');
    _load(reset: true);

    _clock = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      },
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final requestVersion = ++_requestVersion;
    final requestedPresencial = _presencial;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loadingMore || _page >= _totalPages) return;
      setState(() => _loadingMore = true);
    }

    try {
      if (_presencial) {
        final response = await PosPurchaseService.mine(
          page: reset ? 1 : _page + 1, pageSize: 5,
          paymentMethod: _paymentMethod,
        );
        if (!mounted || requestVersion != _requestVersion || !requestedPresencial) return;
        setState(() {
          _posItems = reset ? response.items : [..._posItems, ...response.items];
          _page = response.page;
          _total = response.total;
          _totalPages = response.totalPages;
        });
        return;
      }
      final response = await PurchaseService.getMyOrders(
        page: reset ? 1 : _page + 1,
        pageSize: 5,
        status: _status,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      if (!mounted || requestVersion != _requestVersion || requestedPresencial) return;

      setState(() {
        _items = reset
            ? response.items
            : [..._items, ...response.items];
        _page = response.page;
        _total = response.total;
        _totalPages = response.totalPages;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;

      setState(() {
        _error =
            error.toString().replaceFirst('Exception: ', '');

        if (reset) {
          _items = const [];
          _posItems = const [];
        }
      });
    } finally {
      if (!mounted || requestVersion != _requestVersion) return;

      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _openDetail(PurchaseOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseDetailScreen(
          orderId: order.id,
        ),
      ),
    );

    if (mounted) {
      await _load(reset: true);
    }
  }

  Future<void> _openPosDetail(PosPurchase sale) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PosPurchaseDetailScreen(saleId: sale.id),
    ));
    if (mounted) await _load(reset: true);
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _dateFrom != null && _dateTo != null
              ? DateTimeRange(
                  start: _dateFrom!,
                  end: _dateTo!,
                )
              : null,
    );

    if (range == null || !mounted) return;

    setState(() {
      _dateFrom = range.start;
      _dateTo = range.end;
    });

    await _load(reset: true);
  }

  void _clearDates() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });

    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReturnStyle.canvas,
      appBar: AppBar(
        backgroundColor: ReturnStyle.paper,
        foregroundColor: ReturnStyle.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mis compras', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: _presencial ? null : _pickDates,
            icon: Badge(
              isLabelVisible:
                  _dateFrom != null || _dateTo != null,
              child: const Icon(Icons.date_range_rounded),
            ),
          ),
          if (_dateFrom != null || _dateTo != null)
            IconButton(
              onPressed: _clearDates,
              icon: const Icon(
                Icons.filter_alt_off_rounded,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HISTORIAL DE COMPRAS',
                      style: TextStyle(
                        color: ReturnStyle.ink,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tus compras',
                      style: TextStyle(
                        color: ReturnStyle.ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Consulta tus compras online y presenciales.',
                      style: TextStyle(
                        color: ReturnStyle.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(children: [
                  Expanded(child: _channelButton('Online', !_presencial, () {
                    setState(() => _presencial = false); _load(reset: true);
                  })),
                  const SizedBox(width: 8),
                  Expanded(child: _channelButton('Presenciales', _presencial, () {
                    setState(() => _presencial = true); _load(reset: true);
                  })),
                ]),
              ),
            ),
            if (_presencial)
              SliverToBoxAdapter(
                child: SizedBox(height: 50, child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final method in <String?>[null, 'CASH', 'CARD', 'QR', 'TRANSFER'])
                      Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(
                        label: Text(_paymentLabel(method)), selected: _paymentMethod == method,
                        selectedColor: ReturnStyle.ink, backgroundColor: ReturnStyle.paper,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: const BorderSide(color: ReturnStyle.line),
                        labelStyle: TextStyle(color: _paymentMethod == method ? Colors.white : ReturnStyle.grey, fontWeight: FontWeight.w700),
                        onSelected: (_) { setState(() => _paymentMethod = method); _load(reset: true); },
                      )),
                  ],
                )),
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(height: 50, child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _statuses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final status = _statuses[index];
                    final selected = _status == status;
                    return ChoiceChip(
                      label: Text(_filterLabel(status)), selected: selected,
                      selectedColor: ReturnStyle.ink, backgroundColor: ReturnStyle.paper,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: const BorderSide(color: ReturnStyle.line),
                      labelStyle: TextStyle(color: selected ? Colors.white : ReturnStyle.grey, fontWeight: FontWeight.w700),
                      onSelected: (_) { if (selected) return; setState(() => _status = status); _load(reset: true); },
                    );
                  },
                )),
              ),
            if (!_loading && (_presencial ? _posItems.isNotEmpty : _items.isNotEmpty))
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    10,
                  ),
                  child: Text(
                    '$_total ${_total == 1 ? 'compra' : 'compras'}',
                    style: const TextStyle(
                      color: ReturnStyle.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_loading && (_presencial ? _posItems.isEmpty : _items.isEmpty))
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null &&
                (_presencial ? _posItems.isEmpty : _items.isEmpty))
              SliverFillRemaining(
                hasScrollBody: false,
                child: _StateBox(
                  title: 'No pudimos cargar tus compras',
                  message: _error!,
                  onRetry: () => _load(reset: true),
                ),
              )
            else if (_presencial ? _posItems.isEmpty : _items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _StateBox(
                  title: 'No encontramos compras',
                  message:
                      'Todavía no tienes compras que coincidan con este filtro.',
                ),
              )
            else ...[
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  12,
                ),
                sliver: SliverList(
                  delegate:
                      SliverChildBuilderDelegate(
                    (context, index) {
                      if (_presencial) {
                        final sale = _posItems[index];
                        return Padding(padding: const EdgeInsets.only(bottom: 12), child: _posCard(sale));
                      }
                      final order = _items[index];

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: PurchaseOrderCard(
                          order: order,
                          now: _now,
                          onTap: () =>
                              _openDetail(order),
                        ),
                      );
                    },
                    childCount: _presencial ? _posItems.length : _items.length,
                  ),
                ),
              ),
              if (_page < _totalPages)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      24,
                    ),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: ReturnStyle.ink, side: const BorderSide(color: ReturnStyle.ink), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                      onPressed: _loadingMore
                          ? null
                          : () => _load(reset: false),
                      icon: _loadingMore
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.expand_more_rounded,
                            ),
                      label: Text(
                        _loadingMore
                            ? 'Cargando...'
                            : 'Cargar más',
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _channelButton(String text, bool selected, VoidCallback onPressed) =>
    OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(
      backgroundColor: selected ? ReturnStyle.ink : Colors.white,
      foregroundColor: selected ? Colors.white : ReturnStyle.ink,
      side: const BorderSide(color: ReturnStyle.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)));

  String _paymentLabel(String? method) => switch (method) {
    'CASH' => 'Efectivo', 'CARD' => 'Tarjeta', 'QR' => 'QR',
    'TRANSFER' => 'Transferencia', _ => 'Todos los pagos',
  };

  Widget _posCard(PosPurchase sale) => Material(
    color: Colors.white, child: InkWell(onTap: () => _openPosDetail(sale), child:
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
        border: Border.all(color: ReturnStyle.line)), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(sale.code, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              Text(sale.statusLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 10),
            Text('COMPRA PRESENCIAL · ${sale.paymentLabel}', style: const TextStyle(color: ReturnStyle.grey, fontSize: 10)),
            const SizedBox(height: 8),
            Text(sale.branch, style: const TextStyle(color: ReturnStyle.grey)),
            const SizedBox(height: 12),
            Row(children: [Text('${sale.units} unidades', style: const TextStyle(color: ReturnStyle.grey)),
              const Spacer(), Text('Bs ${sale.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Icon(Icons.chevron_right_rounded)]),
          ],
        )),
    ),
  );

  String _filterLabel(String? status) {
    switch (status) {
      case null:
        return 'Todas';
      case 'PENDING_PAYMENT':
        return 'Pendientes';
      case 'PAID':
        return 'Pagadas';
      case 'PREPARING':
        return 'Preparando';
      case 'READY_FOR_PICKUP':
        return 'Listas';
      case 'SHIPPED':
        return 'Enviadas';
      case 'DELIVERED':
        return 'Entregadas';
      case 'COMPLETED':
        return 'Finalizadas';
      case 'PAYMENT_FAILED':
        return 'Pago fallido';
      case 'CANCELLED':
        return 'Canceladas';
      case 'REFUNDED':
        return 'Reembolsadas';
      default:
        return status;
    }
  }
}

class _StateBox extends StatelessWidget {
  const _StateBox({
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: ReturnStyle.grey,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ReturnStyle.ink,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ReturnStyle.grey,
                height: 1.35,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ReturnStyle.ink, foregroundColor: ReturnStyle.paper),
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
