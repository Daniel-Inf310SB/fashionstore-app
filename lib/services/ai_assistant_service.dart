import 'dart:convert';

import '../models/ai_assistant.dart';
import 'api_service.dart';

class AIAssistantService {
  AIAssistantService._();

  static Future<AIAssistantResponse> ask({
    required int branchId,
    required String message,
    int maxProducts = 6,
  }) async {
    final response = await ApiService.post(
      '/ai/assistant',
      requiresAuth: true,
      body: {
        'branch_id': branchId,
        'message': message.trim(),
        'max_products': maxProducts,
      },
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(
          data,
          'No pude responder en este momento.',
        ),
      );
    }

    if (data is! Map) {
      throw Exception(
        'Respuesta inválida del asistente.',
      );
    }

    return AIAssistantResponse.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static Future<CustomerAssistantInterpretResponse>
      interpret({
    required String command,
    required CustomerAssistantContext context,
  }) async {
    final response = await ApiService.post(
      '/customer-assistant/interpret',
      requiresAuth: true,
      body: {
        'command': command.trim(),
        'context': context.toJson(),
      },
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(
          data,
          'No pude interpretar ese comando.',
        ),
      );
    }

    if (data is! Map) {
      throw Exception(
        'Respuesta inválida al interpretar el comando.',
      );
    }

    return CustomerAssistantInterpretResponse.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static Future<CustomerAssistantExecuteResponse>
      execute({
    required CustomerAssistantResolvedCommand command,
    required bool confirmed,
  }) async {
    final response = await ApiService.post(
      '/customer-assistant/execute',
      requiresAuth: true,
      body: {
        'action': command.action,
        'params': command.params,
        'confirmed': confirmed,
      },
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(
          data,
          'No se pudo ejecutar la acción solicitada.',
        ),
      );
    }

    if (data is! Map) {
      throw Exception(
        'Respuesta inválida al ejecutar el comando.',
      );
    }

    return CustomerAssistantExecuteResponse.fromJson(
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

  static String _detail(
    dynamic data,
    String fallback,
  ) {
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];

      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }

      return detail.toString();
    }

    return fallback;
  }
}
