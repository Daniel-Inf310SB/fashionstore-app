import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/reservation.dart';
import '../repositories/account_snapshot_repository.dart';
import 'api_service.dart';

class ReservationService {
  static const String _mine = '/reservations/mine';

  static Future<ReservationListPage> getMyReservations({
    int page = 1,
    int pageSize = 6,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (status != null && status.isNotEmpty) 'status': status,
      if (dateFrom != null)
        'date_from': _startOfDay(dateFrom).toUtc().toIso8601String(),
      if (dateTo != null)
        'date_to': _endOfDay(dateTo).toUtc().toIso8601String(),
    };

    final endpoint = Uri(
      path: _mine,
      queryParameters: query,
    ).toString();

    final response = await ApiService.get(
      endpoint,
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(data, 'No se pudieron cargar tus reservas.'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida de reservas.');
    }

    final result = ReservationListPage.fromJson(
      Map<String, dynamic>.from(data),
    );
    try {
      await const AccountSnapshotRepository().saveReservations(
        endpoint, Map<String, dynamic>.from(data));
    } catch (error) {
      debugPrint('[FS-SNAPSHOT] No se guardó historial de reservas: $error');
    }
    // El listado puede traer todos los datos del detalle. Guardarlos para
    // 'Ver detalle' offline sin una segunda petición obligatoria.
    final rawItems = data['items'];
    if (rawItems is List) {
      for (final row in rawItems.whereType<Map>()) {
        final id = (row['id'] as num?)?.toInt();
        final variants = row['items'];
        if (id == null || id <= 0 || variants is! List || variants.isEmpty ||
            row['branch'] is! Map ||
            !variants.any((item) => item is Map && item['product_variant'] is Map)) continue;
        try {
          await const AccountSnapshotRepository().saveReservationDetail(
            id, Map<String, dynamic>.from(row));
        } catch (error) {
          debugPrint('[FS-SNAPSHOT] Detalle parcial sin guardar: $error');
        }
      }
    }
    return result;
  }

  static Future<Reservation> getMyReservation(int reservationId) async {
    final response = await ApiService.get(
      '$_mine/$reservationId',
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(data, 'No se pudo cargar la reserva.'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida de la reserva.');
    }

    try {
      await const AccountSnapshotRepository().saveReservationDetail(
        reservationId, Map<String, dynamic>.from(data));
    } catch (error) {
      debugPrint('[FS-SNAPSHOT] No se guardó detalle de reserva: $error');
    }
    return Reservation.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<ReservationCount> getMyReservationCount() async {
    final response = await ApiService.get(
      '$_mine/count',
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(data, 'No se pudo cargar el resumen de reservas.'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida del resumen de reservas.');
    }

    return ReservationCount.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static Future<Reservation?> getMyPendingReservation(
    int branchId,
  ) async {
    final endpoint = Uri(
      path: '$_mine/pending',
      queryParameters: {
        'branch_id': '$branchId',
      },
    ).toString();

    final response = await ApiService.get(
      endpoint,
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(
          data,
          'No se pudo comprobar tu reserva pendiente.',
        ),
      );
    }

    if (data == null) return null;

    if (data is! Map) {
      throw Exception('Respuesta inválida de la reserva pendiente.');
    }

    return Reservation.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static Future<Reservation> createMyReservation({
    required int branchId,
    required List<ReservationItemRequest> items,
    String? notes,
  }) async {
    final response = await ApiService.post(
      _mine,
      requiresAuth: true,
      body: {
        'branch_id': branchId,
        'notes': _nullableText(notes),
        'items': items.map((item) => item.toJson()).toList(),
      },
    );

    return _reservationResponse(
      response.statusCode,
      response.body,
      successCodes: const {200, 201},
      fallback: 'No se pudo crear la reserva.',
    );
  }

  static Future<Reservation> addItemsToMyReservation({
    required int reservationId,
    required List<ReservationItemRequest> items,
    String? notes,
  }) async {
    final response = await ApiService.post(
      '$_mine/$reservationId/items',
      requiresAuth: true,
      body: {
        'notes': _nullableText(notes),
        'items': items.map((item) => item.toJson()).toList(),
      },
    );

    return _reservationResponse(
      response.statusCode,
      response.body,
      successCodes: const {200, 201},
      fallback: 'No se pudieron agregar las prendas.',
    );
  }

  static Future<Reservation> cancelMyReservation(
    int reservationId, {
    String? reason,
  }) async {
    final response = await ApiService.patch(
      '$_mine/$reservationId/cancel',
      requiresAuth: true,
      body: {
        'reason': _nullableText(reason),
      },
    );

    return _reservationResponse(
      response.statusCode,
      response.body,
      successCodes: const {200},
      fallback: 'No se pudo cancelar la reserva.',
    );
  }

  static Reservation _reservationResponse(
    int statusCode,
    String body, {
    required Set<int> successCodes,
    required String fallback,
  }) {
    final data = _decode(body);

    if (!successCodes.contains(statusCode)) {
      throw Exception(_detail(data, fallback));
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida de la reserva.');
    }

    return Reservation.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;

    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String _detail(dynamic data, String fallback) {
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }

    return fallback;
  }

  static String? _nullableText(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _endOfDay(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      23,
      59,
      59,
      999,
    );
  }
}
