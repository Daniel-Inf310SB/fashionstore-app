import 'package:flutter/material.dart';

import '../../core/offline/offline_database.dart';
import '../../services/offline_reservation_service.dart';
import '../../services/offline_sync_coordinator.dart';
import '../../widgets/reservations/reservation_fashion_style.dart';

/// Historial de operaciones locales. Una operación SYNCED fue aceptada por
/// FastAPI; LOCAL_PENDING nunca equivale a una reserva confirmada.
class OfflinePendingReservationsScreen extends StatefulWidget {
  const OfflinePendingReservationsScreen({super.key, required this.branchId});
  final int branchId;

  @override
  State<OfflinePendingReservationsScreen> createState() =>
      _OfflinePendingReservationsScreenState();
}

class _LocalOperationDetail {
  const _LocalOperationDetail(this.operation, this.items, this.branchName);
  final OfflineOperation operation;
  final List<Map<String, dynamic>> items;
  final String branchName;
}

class _OfflinePendingReservationsScreenState
    extends State<OfflinePendingReservationsScreen> {
  late Future<List<_LocalOperationDetail>> _load;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _load = _read();

  Future<List<_LocalOperationDetail>> _read() async {
    final scope = await OfflineReservationService.requireScope(widget.branchId);
    final repository = OfflineReservationService.repository;
    final operations = await repository.allOperations(scope);
    final output = <_LocalOperationDetail>[];
    for (final op in operations) {
      if (op.type != 'RESERVATION_CREATE') continue;
      final display = await repository.reservationDisplay(
        scope: scope, operationId: op.id,
      );
      final rows = await repository.transactionItems(
        scope: scope, operationId: op.id,
      );
      final descriptions = (display?['items'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          [];
      final items = <Map<String, dynamic>>[];
      for (final row in rows) {
        final variantId = (row['variant_id'] as num).toInt();
        Map<String, dynamic> description = {};
        for (final candidate in descriptions) {
          if (candidate['variant_id'] == variantId) {
            description = candidate;
            break;
          }
        }
        // Los importes y cantidades proceden siempre de la transacción local.
        items.add({...description, ...row});
      }
      output.add(_LocalOperationDetail(op, items,
          display?['branch_name']?.toString() ?? 'Sucursal ${widget.branchId}'));
    }
    return output.reversed.toList();
  }

  Future<void> _synchronize() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await OfflineSyncCoordinator.instance.startForBranch(widget.branchId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo comprobar la sincronización: $error'),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _reload();
        });
      }
    }
  }

  static String _label(String status) => switch (status) {
        OfflineDatabase.synced => 'Recibida por el servidor',
        OfflineDatabase.conflict => 'Requiere revisión',
        OfflineDatabase.rejected => 'Rechazada',
        _ => 'Pendiente de sincronizar',
      };

  static IconData _icon(String status) => switch (status) {
        OfflineDatabase.synced => Icons.check_circle_rounded,
        OfflineDatabase.conflict => Icons.warning_amber_rounded,
        OfflineDatabase.rejected => Icons.error_outline_rounded,
        _ => Icons.schedule_rounded,
      };

  static Color _color(String status) => switch (status) {
        OfflineDatabase.synced => Colors.green,
        OfflineDatabase.conflict => Colors.orange,
        OfflineDatabase.rejected => Colors.redAccent,
        _ => Colors.blueAccent,
      };

  Widget _operationCard(_LocalOperationDetail detail) {
    final op = detail.operation;
    final totalCents = detail.items.fold<int>(0, (sum, item) =>
        sum + (item['quantity'] as num).toInt() *
            (item['unit_price_cents'] as num).toInt());
    return Card(
      color: ReservationFashionStyle.surface,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: ExpansionTile(
        leading: Icon(_icon(op.status), color: _color(op.status)),
        title: Text(_label(op.status)),
        subtitle: Text('${detail.branchName}\n${op.createdAt.toLocal()}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operación: ${op.id}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          if (detail.items.isEmpty)
            const Text('No se encontraron detalles locales para esta operación.')
          else
            ...detail.items.map((item) {
              final quantity = (item['quantity'] as num).toInt();
              final cents = (item['unit_price_cents'] as num).toInt();
              final name = item['name']?.toString() ??
                  'Variante ${item['variant_id']}';
              final size = item['size']?.toString() ?? '';
              final color = item['color']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('$name ${[size, color].where((s) => s.isNotEmpty).join(' · ')}'
                    '\n$quantity × Bs ${(cents / 100).toStringAsFixed(2)}'),
              );
            }),
          Text('Total referencial: Bs ${(totalCents / 100).toStringAsFixed(2)}'),
          Text('Intentos de envío: ${op.attempts}'),
          if (op.lastError != null && op.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Motivo: ${op.lastError}',
                style: TextStyle(color: _color(op.status))),
          ],
          if (op.status == OfflineDatabase.pending)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('La reserva todavía no fue aceptada por el servidor. '
                  'Puedes reintentar cuando vuelva la conexión.'),
            ),
          if (op.status == OfflineDatabase.conflict ||
              op.status == OfflineDatabase.rejected)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Esta operación no se reenvía automáticamente. '
                  'Revisa el motivo antes de crear otra solicitud.'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: ReservationFashionStyle.theme(context),
        child: Scaffold(
        backgroundColor: ReservationFashionStyle.background,
        appBar: AppBar(
          title: const Text('Operaciones locales'),
          actions: [
            IconButton(
              tooltip: 'Sincronizar operaciones pendientes',
              onPressed: _syncing ? null : _synchronize,
              icon: _syncing
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<_LocalOperationDetail>>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('No se pudieron consultar las operaciones: '
                  '${snapshot.error}'));
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const Center(child: Text('No hay operaciones locales.'));
            }
            return RefreshIndicator(
              onRefresh: _synchronize,
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) => _operationCard(entries[index]),
              ),
            );
          },
        ),
      ),
      );
}
