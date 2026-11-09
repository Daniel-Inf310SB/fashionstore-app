import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/reservations/reservation_fashion_style.dart';
import '../../core/network/app_error_message.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../repositories/account_snapshot_repository.dart';
import '../../services/offline_reservation_service.dart';
import '../../services/main_tab_navigation_service.dart';
import '../../services/branch_service.dart';
import '../../services/offline_sync_coordinator.dart';
import '../../services/offline_reservation_resolution_service.dart';
import '../../core/offline/offline_database.dart';
import '../../core/network/connectivity_service.dart';
import '../../widgets/reservations/reservation_card.dart';
import 'reservation_detail_screen.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({
    super.key,
    this.onOpenCatalog,
  });

  final VoidCallback? onOpenCatalog;

  @override
  State<ReservationsScreen> createState() =>
      _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  static const _statuses = <String?>[
    null,
    'PENDING',
    'CONFIRMED',
    'PREPARING',
    'READY',
    'COMPLETED',
    'CANCELLED',
    'EXPIRED',
  ];

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  int _page = 1;
  int _total = 0;
  int _totalPages = 0;

  String? _selectedStatus;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  List<Reservation> _reservations = const [];
  List<LocalReservationRecord> _offlineReservations = const [];
  String? _localMessage;
  bool _reservationsFromSnapshot = false;
  String? _displayedCacheKey;
  int? _cancellingId;
  String? _resolvingLocalId;

  Timer? _clock;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.status.addListener(_onConnectivityChanged);
    _onConnectivityChanged();
    OfflineSyncCoordinator.instance.syncing.addListener(_onSyncFinished);
    OfflineReservationService.changes.addListener(_onLocalChange);
    MainTabNavigationService.selectedTab.addListener(_onTabChanged);
    _load(reset: true);
    // Al volver a esta pantalla después de reiniciar, vuelve a armar
    // el observador de reconexión para las reservas del usuario.
    OfflineSyncCoordinator.instance.startForMyReservations().catchError((Object error) {
      debugPrint('[FS-SYNC] Monitor no iniciado: $error');
    });

    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!mounted) return;

        final expired = _reservations.any(
          (reservation) =>
              reservation.expirationRelevant &&
              reservation.expiredLocally &&
              reservation.status != 'EXPIRED',
        );

        if (expired && !_loading) {
          _load(reset: true);
        } else {
          setState(() {});
        }
      },
    );
  }

  ConnectionStatus? _lastConnection;

  void _onConnectivityChanged() {
    if (!mounted) return;
    final current = ConnectivityService.instance.status.value;
    if (current == _lastConnection) return;
    _lastConnection = current;
    if (current == ConnectionStatus.offline ||
        current == ConnectionStatus.networkOnly) {
      if (_reservations.isNotEmpty) setState(() => _reservationsFromSnapshot = true);
      // No se puede descargar el historial remoto, pero sí leer pendientes.
      debugPrint('[FS-RESERVAS] Sin servidor: consultando operaciones SQLite');
      _loadLocalReservations();
    } else if (current == ConnectionStatus.apiAvailable && !_loading) {
      debugPrint('[FS-RESERVAS] Servidor recuperado: actualizando historial');
      _load(reset: true);
    }
  }

  void _onSyncFinished() {
    if (mounted && !OfflineSyncCoordinator.instance.syncing.value && !_loading) {
      _load(reset: true);
    }
  }

  void _onLocalChange() {
    if (mounted) _loadLocalReservations();
  }

  void _onTabChanged() {
    if (MainTabNavigationService.selectedTab.value == 2 && mounted && !_loading) {
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    ConnectivityService.instance.status.removeListener(_onConnectivityChanged);
    OfflineSyncCoordinator.instance.syncing.removeListener(_onSyncFinished);
    _clock?.cancel();
    OfflineReservationService.changes.removeListener(_onLocalChange);
    MainTabNavigationService.selectedTab.removeListener(_onTabChanged);
    super.dispose();
  }

  Future<void> _load({
    required bool reset,
  }) async {
    if (!reset && (_loading || _loadingMore || _page >= _totalPages)) {
      return;
    }

    final generation = ++_loadGeneration;
    final targetPage = reset ? 1 : _page + 1;
    final cacheKey = Uri(path: '/reservations/mine', queryParameters: {
      'page': '$targetPage', 'page_size': '6',
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty)
        'status': _selectedStatus!,
      if (_dateFrom != null)
        'date_from': DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day)
            .toUtc().toIso8601String(),
      if (_dateTo != null)
        'date_to': DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day,
            23, 59, 59, 999).toUtc().toIso8601String(),
    }).toString();
    // Mantener la lista ya visible si el filtro no cambió. Esto evita que
    // las tarjetas desaparezcan en cada sincronización o cambio de pestaña.
    final sameFilter = _displayedCacheKey == cacheKey;
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
        if (!sameFilter) {
          _page = 1;
          _total = 0;
          _totalPages = 0;
          _reservations = const [];
          _reservationsFromSnapshot = false;
          _displayedCacheKey = null;
        }
      });
      // Las operaciones locales se recuperan sin bloquear el historial.
      unawaited(_loadLocalReservations());
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      // Consultar SQLite solo cuando todavía no mostramos el filtro pedido.
      // Un refresh no reemplaza tarjetas visibles por una copia posiblemente
      // más antigua ni muestra avisos temporales.
      if (reset && !sameFilter) {
        try {
          final cached = await const AccountSnapshotRepository()
              .readReservations(cacheKey);
          if (cached != null && mounted && generation == _loadGeneration) {
            final saved = ReservationListPage.fromJson(cached);
            setState(() {
              _reservations = saved.items;
              _page = saved.page;
              _total = saved.total;
              _totalPages = saved.totalPages;
              _displayedCacheKey = cacheKey;
              _reservationsFromSnapshot = true;
            });
          }
        } catch (error) {
          debugPrint('[FS-SNAPSHOT] Error leyendo reservas: $error');
        }
      }

      final result = await ReservationService.getMyReservations(
        page: targetPage,
        pageSize: 6,
        status: _selectedStatus,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _reservations = reset
            ? result.items
            : [..._reservations, ...result.items];
        _page = result.page;
        _total = result.total;
        _totalPages = result.totalPages;
        _displayedCacheKey = reset ? cacheKey : _displayedCacheKey;
        _reservationsFromSnapshot = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error is AppNetworkException
            ? 'No se puede actualizar el historial remoto. Las reservas guardadas siguen disponibles.'
            : AppErrorMessage.from(error);
        if (reset && _reservations.isNotEmpty) {
          // No afirmar que la información mostrada está actualizada si
          // falló la petición de red: conservarla como copia local.
          _reservationsFromSnapshot = true;
        }
      });
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  // Solo operaciones locales pertenecientes al usuario autenticado, tenant
  // activo y las sucursales conocidas. El servidor sigue siendo autoridad.
  Future<void> _loadLocalReservations() async {
    try {
      final branches = await BranchService.getStoreBranches();
      final groups = await Future.wait(branches.map((branch) async {
        return OfflineReservationService.details(branchId: branch.id, branchName: branch.name);
      }));
      final local = groups.expand((items) => items)
          .toList()
        ..sort((a, b) => b.operation.createdAt.compareTo(a.operation.createdAt));
      if (mounted) setState(() {
        _offlineReservations = local;
        _localMessage = null;
      });
      debugPrint('[FS-RESERVAS] SQLite: ${local.length} reservas locales');
    } catch (error) {
      debugPrint('[FS-RESERVAS] No se pudieron cargar reservas locales: $error');
      if (mounted) setState(() {
        _localMessage = 'No pudimos consultar las reservas guardadas en el teléfono.';
      });
    }
  }

  String _localState(OfflineOperation op) {
    switch (op.status) {
      case OfflineDatabase.pending: return 'Por sincronizar';
      case OfflineDatabase.conflict: return 'Requiere revisión';
      case OfflineDatabase.rejected: return 'Rechazada';
      case OfflineDatabase.synced: return 'Enviada';
      default: return 'Pendiente';
    }
  }

  Widget _buildLocalReservations() {
    final filtered = (_selectedStatus == null || _selectedStatus == 'PENDING')
        ? _offlineReservations : <LocalReservationRecord>[];
    if (filtered.isEmpty) return _localMessage == null
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.all(16), child: Text(_localMessage!,
            style: const TextStyle(color: ReservationFashionStyle.textSecondary)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(
          'Reservas de este dispositivo', style: TextStyle(fontSize: 17,
            fontWeight: FontWeight.bold, color: ReservationFashionStyle.textPrimary))),
        const SizedBox(height: 6),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(
          'Guardadas localmente. Aún no representan una reserva confirmada.',
          style: TextStyle(color: ReservationFashionStyle.textSecondary))),
        const SizedBox(height: 12),
        ...filtered.map((entry) {
          final op = entry.operation;
          final conflict = op.status == OfflineDatabase.conflict ||
              op.status == OfflineDatabase.rejected;
          final totalUnits = entry.items.fold<int>(0,
              (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0));
          return Card(
            color: ReservationFashionStyle.surface,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: ReservationFashionStyle.divider)),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RESERVA LOCAL', style: TextStyle(
                      color: ReservationFashionStyle.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(op.id.substring(0, 8).toUpperCase(), style: const TextStyle(
                      color: ReservationFashionStyle.textPrimary, fontSize: 17,
                      fontWeight: FontWeight.bold)),
                  ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: ReservationFashionStyle.background,
                    borderRadius: BorderRadius.circular(14)),
                  child: Text(_localState(op), style: TextStyle(
                    color: conflict ? ReservationFashionStyle.error : ReservationFashionStyle.primaryLight,
                    fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 12),
              for (final item in entry.items.take(3)) Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Icon(Icons.checkroom_rounded, color: ReservationFashionStyle.textMuted, size: 24),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name']?.toString() ?? 'Variante #${item['variant_id']}',
                        style: const TextStyle(color: ReservationFashionStyle.textPrimary,
                          fontWeight: FontWeight.w600)),
                      Text('${item['size'] ?? ''} ${item['color'] ?? ''} · ${item['quantity']} unidad(es)',
                        style: const TextStyle(color: ReservationFashionStyle.textSecondary, fontSize: 12)),
                    ])),
                ])),
              if (entry.items.length > 3) Text(
                '+ ${entry.items.length - 3} prendas más',
                style: const TextStyle(color: ReservationFashionStyle.textSecondary)),
              const Divider(color: ReservationFashionStyle.divider),
              Text(entry.branchName, style: const TextStyle(
                color: ReservationFashionStyle.textSecondary)),
              const SizedBox(height: 5),
              Row(children: [
                Text('$totalUnits unidad(es)',
                  style: const TextStyle(color: ReservationFashionStyle.textSecondary)),
                const Spacer(),
                Text('Bs ${(entry.totalCents / 100).toStringAsFixed(2)}',
                  style: const TextStyle(color: ReservationFashionStyle.primaryLight,
                    fontWeight: FontWeight.w800)),
              ]),
              if (op.lastError != null && op.lastError!.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 10), child: Text(
                  op.lastError!.startsWith(OfflineReservationResolutionService.uncertainPrefix)
                      ? 'No pudimos verificar si se agregaron las prendas. Revisa primero el detalle de la reserva existente antes de intentar otra vez.'
                      : (op.lastError!.toLowerCase().contains('reserva pending')
                          ? 'Ya existe una reserva pendiente en esta sucursal. Puedes agregarle estas prendas usando el botón inferior.'
                          : op.lastError!),
                  style: const TextStyle(color: ReservationFashionStyle.error))),
              const SizedBox(height: 10),
              if (conflict && (op.lastError ?? '').toLowerCase().contains('reserva pending') &&
                  !(op.lastError ?? '').startsWith(OfflineReservationResolutionService.uncertainPrefix)) ...[
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _resolvingLocalId == null ? () => _resolvePendingReservation(entry) : null,
                  icon: _resolvingLocalId == op.id
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_circle_outline),
                  label: const Text('Agregar a mi reserva pendiente'),
                )),
                const SizedBox(height: 8),
              ],
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => _openLocalDetail(entry),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver detalle'),
              )),
            ])),
          );
        }),
      ]),
    );
  }

  /// Resolución iniciada por el usuario. El POST de incorporar ítems no tiene
  /// idempotencia garantizada: no reenviar automáticamente tras un timeout.
  Future<void> _resolvePendingReservation(LocalReservationRecord entry) async {
    if (_resolvingLocalId != null) return;
    setState(() => _resolvingLocalId = entry.operation.id);
    try {
      final resolver = const OfflineReservationResolutionService();
      final target = await resolver.findPending(entry);
      if (!mounted) return;
      if (target == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
          'Ya no existe una reserva pendiente en esta sucursal. Actualiza el historial antes de reintentar crear una nueva.')));
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Agregar prendas a reserva existente'),
          content: Text('Tienes la reserva ${target.code} pendiente en ${entry.branchName}. '
              '¿Deseas agregar las ${entry.items.length} variante(s) guardadas en el teléfono? '
              'Solo se enviarán una vez y estarán sujetas a disponibilidad de stock.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Agregar prendas')),
          ],
        ),
      );
      if (accepted != true) return;
      final outcome = await resolver.addToPending(local: entry, target: target);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(outcome.message),
        backgroundColor: outcome.success ? null : ReservationFashionStyle.error,
      ));
      await _load(reset: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppErrorMessage.from(error)), backgroundColor: ReservationFashionStyle.error,
      ));
    } finally {
      if (mounted) setState(() => _resolvingLocalId = null);
    }
  }

  Future<void> _openLocalDetail(LocalReservationRecord entry) async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      backgroundColor: ReservationFashionStyle.surface,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reserva local ${entry.operation.id.substring(0, 8)}',
            style: const TextStyle(color: ReservationFashionStyle.textPrimary,
              fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_localState(entry.operation),
            style: const TextStyle(color: ReservationFashionStyle.primaryLight)),
          const SizedBox(height: 6),
          Text('Sucursal: ${entry.branchName}',
            style: const TextStyle(color: ReservationFashionStyle.textSecondary)),
          const SizedBox(height: 14),
          for (final item in entry.items) ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.checkroom_rounded,
              color: ReservationFashionStyle.primaryLight),
            title: Text(item['name']?.toString() ?? 'Variante #${item['variant_id']}',
              style: const TextStyle(color: ReservationFashionStyle.textPrimary)),
            subtitle: Text('Talla ${item['size'] ?? '—'} · ${item['color'] ?? '—'} · ${item['quantity']} unidad(es)',
              style: const TextStyle(color: ReservationFashionStyle.textSecondary)),
            trailing: Text('Bs ${(((item['unit_price_cents'] as num?)?.toInt() ?? 0) *
              ((item['quantity'] as num?)?.toInt() ?? 0) / 100).toStringAsFixed(2)}',
              style: const TextStyle(color: ReservationFashionStyle.primaryLight)),
          ),
          const Divider(color: ReservationFashionStyle.divider),
          Text('Total referencial: Bs ${(entry.totalCents / 100).toStringAsFixed(2)}',
            style: const TextStyle(color: ReservationFashionStyle.textPrimary,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('La reserva se confirmará únicamente cuando FastAPI la acepte. Los precios y existencias pueden haber cambiado.',
            style: TextStyle(color: ReservationFashionStyle.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))),
        ]),
      )));
  }

  Future<void> _openDetail(Reservation reservation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationDetailScreen(
          reservationId: reservation.id,
          initialReservation: reservation,
        ),
      ),
    );

    if (!mounted) return;
    await _load(reset: true);
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    if (_reservationsFromSnapshot || !reservation.canCancel || _cancellingId != null) return;

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: ReservationFashionStyle.surface,
          title: const Text(
            '¿Cancelar reserva?',
            style: TextStyle(color: ReservationFashionStyle.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se liberarán las prendas de ${reservation.reservationCode}.',
                style: const TextStyle(
                  color: ReservationFashionStyle.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLength: 255,
                maxLines: 3,
                style: const TextStyle(
                  color: ReservationFashionStyle.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Motivo (opcional)',
                  labelStyle: const TextStyle(
                    color: ReservationFashionStyle.textSecondary,
                  ),
                  filled: true,
                  fillColor: ReservationFashionStyle.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: ReservationFashionStyle.error,
              ),
              child: const Text('Sí, cancelar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    setState(() {
      _cancellingId = reservation.id;
    });

    try {
      await ReservationService.cancelMyReservation(
        reservation.id,
        reason: reason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reserva cancelada. Las prendas fueron liberadas.',
          ),
        ),
      );

      await _load(reset: true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: ReservationFashionStyle.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancellingId = null;
        });
      }
    }
  }

  Future<void> _openDateFilter() async {
    DateTime? from = _dateFrom;
    DateTime? to = _dateTo;

    final result = await showModalBottomSheet<_DateRangeResult>(
      context: context,
      backgroundColor: ReservationFashionStyle.surface,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickFrom() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: from ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(
                  const Duration(days: 365),
                ),
              );

              if (picked != null) {
                setSheetState(() => from = picked);
              }
            }

            Future<void> pickTo() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: to ?? from ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(
                  const Duration(days: 365),
                ),
              );

              if (picked != null) {
                setSheetState(() => to = picked);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrar por fecha',
                      style: TextStyle(
                        color: ReservationFashionStyle.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DateButton(
                            label: 'Desde',
                            value: from,
                            onTap: pickFrom,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateButton(
                            label: 'Hasta',
                            value: to,
                            onTap: pickTo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(
                                sheetContext,
                                const _DateRangeResult(),
                              );
                            },
                            child: const Text('Limpiar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () {
                              if (from != null &&
                                  to != null &&
                                  from!.isAfter(to!)) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'La fecha inicial no puede ser posterior a la final.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(
                                sheetContext,
                                _DateRangeResult(
                                  from: from,
                                  to: to,
                                ),
                              );
                            },
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _dateFrom = result.from;
      _dateTo = result.to;
    });

    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ReservationFashionStyle.theme(context),
      child: ColoredBox(
        color: ReservationFashionStyle.background,
        child: SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  8,
                ),
                child: _buildHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildFilters(),
            ),
            if (_reservationsFromSnapshot &&
                (_error != null ||
                 _lastConnection == ConnectionStatus.offline ||
                 _lastConnection == ConnectionStatus.networkOnly))
              const SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Text('Historial guardado en este teléfono. '
                    'Los estados pueden haber cambiado en el servidor.',
                    style: TextStyle(color: ReservationFashionStyle.textSecondary)),
              )),
            SliverToBoxAdapter(child: _buildLocalReservations()),
            if (_error != null && _offlineReservations.isNotEmpty)
              const SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Sin acceso al servidor. Las reservas locales siguen guardadas y no están confirmadas.',
                  style: TextStyle(color: ReservationFashionStyle.textSecondary)),
              )),
            if (_loading && _reservations.isEmpty &&
                (_selectedStatus != null && _selectedStatus != 'PENDING' || _offlineReservations.isEmpty))
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null && _reservations.isEmpty &&
                (_selectedStatus != null && _selectedStatus != 'PENDING' || _offlineReservations.isEmpty))
              SliverFillRemaining(
                hasScrollBody: false,
                child: _StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'No pudimos cargar tus reservas',
                  message: _error!,
                  buttonLabel: 'Reintentar',
                  onPressed: () => _load(reset: true),
                ),
              )
            else if (_reservations.isEmpty &&
                (_selectedStatus != null && _selectedStatus != 'PENDING' || _offlineReservations.isEmpty))
              SliverFillRemaining(
                hasScrollBody: false,
                child: _StateMessage(
                  icon: Icons.shopping_bag_outlined,
                  title: 'No encontramos reservas',
                  message:
                      'Prueba cambiando el estado o el rango de fechas.',
                  buttonLabel: 'Explorar catálogo',
                  onPressed: widget.onOpenCatalog,
                ),
              )
            else if (_reservations.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        '$_total ${_total == 1 ? 'reserva' : 'reservas'}',
                        style: const TextStyle(
                          color: ReservationFashionStyle.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_totalPages > 0)
                        Text(
                          'Página $_page de $_totalPages',
                          style: const TextStyle(
                            color: ReservationFashionStyle.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final reservation = _reservations[index];

                      return ReservationCard(
                        reservation: reservation,
                        cancelling:
                            _cancellingId == reservation.id,
                        onOpen: () => _openDetail(reservation),
                        onCancel: () =>
                            _cancelReservation(reservation),
                      );
                    },
                    childCount: _reservations.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildLoadMore(),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 96),
              ),
            ],
          ],
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MI CUENTA / RESERVAS',
                style: TextStyle(color: ReservationFashionStyle.textMuted,
                  fontSize: 11, fontWeight: FontWeight.w800,
                  letterSpacing: 1.3)),
              SizedBox(height: 7),
              Text('Tus reservas',
                style: TextStyle(color: ReservationFashionStyle.textPrimary,
                  fontSize: 30, fontWeight: FontWeight.w900,
                  height: 1.1)),
              SizedBox(height: 8),
              Text('Consulta el estado de tus prendas y fechas de retiro.',
                style: TextStyle(color: ReservationFashionStyle.textSecondary,
                  fontSize: 13, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Filtrar fechas',
          onPressed: _openDateFilter,
          icon: Badge(
            isLabelVisible: _dateFrom != null || _dateTo != null,
            child: const Icon(Icons.date_range_outlined,
              color: ReservationFashionStyle.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statuses[index];
          final selected = _selectedStatus == status;

          return ChoiceChip(
            label: Text(_filterLabel(status)),
            selected: selected,
            selectedColor: ReservationFashionStyle.primary,
            backgroundColor: ReservationFashionStyle.surface,
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            side: const BorderSide(color: ReservationFashionStyle.divider),
            labelStyle: TextStyle(
              color: selected
                  ? Colors.white
                  : ReservationFashionStyle.textSecondary,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) {
              if (selected) return;

              setState(() {
                _selectedStatus = status;
              });

              _load(reset: true);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadMore() {
    if (_totalPages <= 1 || _page >= _totalPages) {
      return const SizedBox(height: 12);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: OutlinedButton.icon(
        onPressed: _loadingMore
            ? null
            : () => _load(reset: false),
        icon: _loadingMore
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more_rounded),
        label: Text(
          _loadingMore ? 'Cargando...' : 'Cargar más',
        ),
      ),
    );
  }

  String _filterLabel(String? status) {
    switch (status) {
      case null:
        return 'Todas';
      case 'PENDING':
        return 'Pendientes';
      case 'CONFIRMED':
        return 'Confirmadas';
      case 'PREPARING':
        return 'Preparando';
      case 'READY':
        return 'Listas';
      case 'COMPLETED':
        return 'Completadas';
      case 'CANCELLED':
        return 'Canceladas';
      case 'EXPIRED':
        return 'Vencidas';
      default:
        return status;
    }
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ReservationFashionStyle.textMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value == null ? 'Sin fecha' : _format(value!),
            style: const TextStyle(
              color: ReservationFashionStyle.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _format(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _DateRangeResult {
  const _DateRangeResult({
    this.from,
    this.to,
  });

  final DateTime? from;
  final DateTime? to;
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: ReservationFashionStyle.textMuted,
              size: 54,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ReservationFashionStyle.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ReservationFashionStyle.textSecondary,
                height: 1.35,
              ),
            ),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onPressed,
                child: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
