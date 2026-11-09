import 'dart:convert';
import '../models/return_request.dart';
import 'api_service.dart';

class ReturnService {
  static dynamic _parse(String body) {
    try {return jsonDecode(body);} catch (_) {return null;}
  }
  static dynamic _unwrap(dynamic data,int code) {
    if(code >= 200 && code < 300) return data;
    final detail = data is Map ? data['detail'] : null;
    final message = detail is String ? detail : (detail is List ? detail.map((e)=>e is Map ? e['msg'] : e).join('; ') : null);
    throw Exception(message?.toString() ?? 'No se pudo completar la solicitud ($code).');
  }
  static Future<ReturnEligibility> eligibility(int orderId) async {
    final r=await ApiService.get('/returns/orders/$orderId/eligibility',requiresAuth:true);
    final data=_unwrap(_parse(r.body),r.statusCode);
    return ReturnEligibility.fromJson(Map<String,dynamic>.from(data as Map));
  }
  static Future<CustomerReturn> create({required int orderId,required String reason,required Map<int,int> items}) async {
    final r=await ApiService.post('/returns',requiresAuth:true,body:{
      'order_id':orderId,'reason':reason.trim(),
      'items':items.entries.where((e)=>e.value>0).map((e)=>{'order_item_id':e.key,'quantity':e.value}).toList(),
    });
    final data=_unwrap(_parse(r.body),r.statusCode);
    return CustomerReturn.fromJson(Map<String,dynamic>.from(data as Map));
  }
  static Future<List<CustomerReturn>> mine() async {
    final r=await ApiService.get('/returns/mine',requiresAuth:true);
    final data=_unwrap(_parse(r.body),r.statusCode);
    return (data as List).whereType<Map>().map((e)=>CustomerReturn.fromJson(Map<String,dynamic>.from(e))).toList();
  }
  static Future<CustomerReturn> detail(int id) async {
    final r=await ApiService.get('/returns/$id',requiresAuth:true);
    final data=_unwrap(_parse(r.body),r.statusCode);
    return CustomerReturn.fromJson(Map<String,dynamic>.from(data as Map));
  }
  static Future<CustomerReturn> cancel(int id) async {
    final r=await ApiService.post('/returns/$id/cancel',requiresAuth:true);
    final data=_unwrap(_parse(r.body),r.statusCode);
    return CustomerReturn.fromJson(Map<String,dynamic>.from(data as Map));
  }
  static Future<ReturnRefundStatus> refundStatus(int id) async {
    final r=await ApiService.get('/returns/$id/refund-status',requiresAuth:true);
    final data=_unwrap(_parse(r.body),r.statusCode);
    return ReturnRefundStatus.fromJson(Map<String,dynamic>.from(data as Map));
  }
}
