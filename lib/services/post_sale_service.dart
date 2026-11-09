import 'dart:convert';
import 'dart:math';

import '../models/post_sale.dart';
import 'api_service.dart';

class PostSaleService {
  static dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static dynamic _unwrap(dynamic body, int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return body;
    final detail = body is Map ? body['detail'] : null;
    final message = detail is String
        ? detail
        : detail is List
            ? detail.map((e) => e is Map ? e['msg'] : e).join('; ')
            : null;
    throw Exception(message?.toString() ?? 'No se pudo completar la operación (${statusCode}).');
  }

  static Future<PostSaleEligibility> eligibility({
    required String channel,
    required int sourceId,
  }) async {
    final normalized = channel.toUpperCase();
    if (!['ONLINE', 'POS'].contains(normalized)) {
      throw ArgumentError('Canal de compra no válido.');
    }
    final response = await ApiService.get(
      '/post-sale/eligibility/$normalized/$sourceId',
      requiresAuth: true,
    );
    final data = _unwrap(_decode(response.body), response.statusCode);
    return PostSaleEligibility.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<PostSaleCase> create({
    required String channel,
    required int sourceId,
    required String resolutionType,
    required String reason,
    required Map<int, int> items,
  }) async {
    final normalizedChannel = channel.toUpperCase();
    final normalizedResolution = resolutionType.toUpperCase();
    if (!['ONLINE', 'POS'].contains(normalizedChannel) ||
        !['REFUND', 'EXCHANGE'].contains(normalizedResolution)) {
      throw ArgumentError('Tipo de solicitud no válido.');
    }
    final response = await ApiService.post(
      '/post-sale/cases',
      requiresAuth: true,
      body: {
        'source_channel': normalizedChannel,
        'source_id': sourceId,
        'resolution_type': normalizedResolution,
        'reason': reason.trim(),
        'items': items.entries
            .where((entry) => entry.value > 0)
            .map((entry) => {
                  'source_item_id': entry.key,
                  'quantity': entry.value,
                })
            .toList(),
        'idempotency_key': _uuidV4(),
      },
    );
    final data = _unwrap(_decode(response.body), response.statusCode);
    return PostSaleCase.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<PostSaleCase>> mine({String? channel}) async {
    final uri = Uri(
      path: '/post-sale/cases/mine',
      queryParameters: {
        if (channel != null && channel.isNotEmpty) 'channel': channel.toUpperCase(),
      },
    );
    final response = await ApiService.get(uri.toString(), requiresAuth: true);
    final data = _unwrap(_decode(response.body), response.statusCode);
    if (data is! List) throw Exception('La respuesta de postventa no tiene el formato esperado.');
    return data
        .whereType<Map>()
        .map((e) => PostSaleCase.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<PostSaleCase> detail(int caseId) async {
    final response = await ApiService.get('/post-sale/cases/$caseId', requiresAuth: true);
    final data = _unwrap(_decode(response.body), response.statusCode);
    return PostSaleCase.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<PostSaleCase> cancel(int caseId, {String? reason}) async {
    final uri = Uri(
      path: '/post-sale/cases/$caseId/cancel',
      queryParameters: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final response = await ApiService.post(uri.toString(), requiresAuth: true);
    final data = _unwrap(_decode(response.body), response.statusCode);
    return PostSaleCase.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
