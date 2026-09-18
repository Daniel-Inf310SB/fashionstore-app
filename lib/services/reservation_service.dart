import 'dart:convert';

import '../core/errors/api_exception.dart';
import '../models/reservation.dart';
import 'api_service.dart';

/// CU28 - Gestionar reservas (lado cliente).
///
/// CU29 (vincular prendas), CU30 (atención) y CU31 (preparación) usan
/// `require_reservations_staff_manage` en el backend: son operaciones
/// de personal de sucursal, no del cliente, así que no van en este
/// servicio ni en la app cliente.
class ReservationService {
  ReservationService._();

  // =========================================================
  // CU28 - CONTADOR (BADGE)
  // =========================================================

  static Future<ReservationCount> getMyReservationCount() async {
    final response = await ApiService.get(
      '/reservations/mine/count',
      requiresAuth: true,
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return ReservationCount.fromJson(data as Map<String, dynamic>);
  }

  // =========================================================
  // CU28 - MIS RESERVAS
  //
  // Por defecto trae todas las sucursales; branchId y
  // activeOnly son filtros opcionales, igual que en el backend.
  // =========================================================

  static Future<ReservationPage> listMyReservations({
    int page = 1,
    int pageSize = 10,
    String? status,
    int? branchId,
    bool activeOnly = false,
  }) async {
    final endpoint = Uri(
      path: '/reservations/mine',
      queryParameters: {
        'page': '$page',
        'page_size': '$pageSize',
        if (status != null) 'status': status,
        if (branchId != null) 'branch_id': '$branchId',
        if (activeOnly) 'active_only': 'true',
      },
    ).toString();

    final response = await ApiService.get(endpoint, requiresAuth: true);

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return ReservationPage.fromJson(data as Map<String, dynamic>);
  }

  // =========================================================
  // CU28 - CONSULTAR UNA RESERVA
  // =========================================================

  static Future<Reservation> getMyReservation(int reservationId) async {
    final response = await ApiService.get(
      '/reservations/mine/$reservationId',
      requiresAuth: true,
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Reservation.fromJson(data as Map<String, dynamic>);
  }

  // =========================================================
  // CU28 - CREAR RESERVA
  //
  // El cliente nunca envía customer_id: el backend lo toma del
  // usuario autenticado (JWT).
  // =========================================================

  static Future<Reservation> createReservation({
    required int branchId,
    required List<ReservationItemInput> items,
    String? notes,
  }) async {
    final response = await ApiService.post(
      '/reservations/mine',
      requiresAuth: true,
      body: {
        'branch_id': branchId,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'items': items.map((e) => e.toJson()).toList(),
      },
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Reservation.fromJson(data as Map<String, dynamic>);
  }

  // =========================================================
  // CU28 - CANCELAR RESERVA
  // =========================================================

  static Future<Reservation> cancelReservation(
      int reservationId, {
        String? reason,
      }) async {
    final response = await ApiService.patch(
      '/reservations/mine/$reservationId/cancel',
      requiresAuth: true,
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Reservation.fromJson(data as Map<String, dynamic>);
  }
}

/// Prenda a reservar, tal como la pide `ReservationItemCreate` en el backend.
class ReservationItemInput {
  final int productVariantId;
  final int quantity;

  const ReservationItemInput({
    required this.productVariantId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'product_variant_id': productVariantId,
    'quantity': quantity,
  };
}