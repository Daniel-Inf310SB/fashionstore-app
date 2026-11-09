import 'dart:convert';
import '../models/pos_purchase.dart';
import 'api_service.dart';

class PosPurchaseService {
  static Future<PosPurchaseList> mine({int page = 1, int pageSize = 5, String? paymentMethod}) async {
    final uri = Uri(path: '/sales/mine', queryParameters: {
      'page': '$page', 'page_size': '$pageSize',
      if (paymentMethod != null) 'payment_method': paymentMethod,
    });
    final response = await ApiService.get(uri.toString(), requiresAuth: true);
    final body = jsonDecode(response.body);
    if (response.statusCode != 200 || body is! Map) {
      throw Exception(body is Map ? (body['detail']?.toString() ?? 'No se pudieron cargar las compras presenciales.') : 'Respuesta inválida.');
    }
    return PosPurchaseList.fromJson(Map<String,dynamic>.from(body));
  }

  static Future<PosPurchase> detail(int saleId) async {
    final response = await ApiService.get('/sales/mine/$saleId', requiresAuth: true);
    final body = jsonDecode(response.body);
    if (response.statusCode != 200 || body is! Map) {
      throw Exception(body is Map ? (body['detail']?.toString() ?? 'No se pudo cargar la venta.') : 'Respuesta inválida.');
    }
    return PosPurchase.fromJson(Map<String,dynamic>.from(body));
  }
}
