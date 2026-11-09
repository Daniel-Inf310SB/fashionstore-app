class AIAssistantProduct {
  const AIAssistantProduct({
    required this.productId,
    required this.name,
    this.variantId,
  });

  final int productId;
  final int? variantId;
  final String name;

  factory AIAssistantProduct.fromJson(
    Map<String, dynamic> json,
  ) {
    return AIAssistantProduct(
      productId:
          (json['product_id'] as num?)?.toInt() ?? 0,
      variantId:
          (json['variant_id'] as num?)?.toInt(),
      name: json['name']?.toString() ?? 'Producto',
    );
  }
}

class AIAssistantResponse {
  const AIAssistantResponse({
    required this.message,
    required this.products,
  });

  final String message;
  final List<AIAssistantProduct> products;

  factory AIAssistantResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawProducts = json['products'];

    return AIAssistantResponse(
      message: json['message']?.toString() ?? '',
      products: rawProducts is List
          ? rawProducts
              .whereType<Map>()
              .map(
                (item) => AIAssistantProduct.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class AssistantChatMessage {
  const AssistantChatMessage({
    required this.role,
    required this.text,
    this.products = const [],
  });

  final String role;
  final String text;
  final List<AIAssistantProduct> products;

  bool get isUser => role == 'user';
}

class CustomerAssistantContext {
  const CustomerAssistantContext({
    this.currentPage,
    this.branchId,
    this.productId,
    this.variantId,
    this.cartItemId,
    this.reservationId,
  });

  final String? currentPage;
  final int? branchId;
  final int? productId;
  final int? variantId;
  final int? cartItemId;
  final int? reservationId;

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'branch_id': branchId,
      'product_id': productId,
      'variant_id': variantId,
      'cart_item_id': cartItemId,
      'reservation_id': reservationId,
    };
  }
}

class CustomerAssistantNavigation {
  const CustomerAssistantNavigation({
    required this.target,
    required this.params,
    required this.query,
  });

  final String target;
  final Map<String, dynamic> params;
  final Map<String, dynamic> query;

  factory CustomerAssistantNavigation.fromJson(
    Map<String, dynamic> json,
  ) {
    return CustomerAssistantNavigation(
      target: json['target']?.toString() ?? '',
      params: _map(json['params']),
      query: _map(json['query']),
    );
  }

  int? get productId =>
      _int(params['product_id']) ??
      _int(query['product_id']);

  int? get cartId =>
      _int(params['cart_id']) ??
      _int(params['cartId']) ??
      _int(query['cart_id']) ??
      _int(query['cartId']);

  int? get branchId =>
      _int(params['branch_id']) ??
      _int(query['branch_id']);

  String? get catalogSearch {
    final value =
        query['search'] ??
        query['q'] ??
        params['search'];

    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class CustomerAssistantResolvedCommand {
  const CustomerAssistantResolvedCommand({
    required this.action,
    required this.message,
    required this.canExecute,
    required this.requiresConfirmation,
    required this.params,
    required this.unresolved,
    this.confirmationMessage,
    this.navigation,
  });

  final String action;
  final String message;
  final bool canExecute;
  final bool requiresConfirmation;
  final String? confirmationMessage;
  final CustomerAssistantNavigation? navigation;
  final Map<String, dynamic> params;
  final List<String> unresolved;

  factory CustomerAssistantResolvedCommand.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawNavigation = json['navigation'];
    final rawUnresolved = json['unresolved'];

    return CustomerAssistantResolvedCommand(
      action: json['action']?.toString() ?? 'UNKNOWN',
      message: json['message']?.toString() ?? '',
      canExecute: json['can_execute'] == true,
      requiresConfirmation:
          json['requires_confirmation'] == true,
      confirmationMessage:
          json['confirmation_message']?.toString(),
      navigation: rawNavigation is Map
          ? CustomerAssistantNavigation.fromJson(
              Map<String, dynamic>.from(rawNavigation),
            )
          : null,
      params: _map(json['params']),
      unresolved: rawUnresolved is List
          ? rawUnresolved.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class CustomerAssistantInterpretResponse {
  const CustomerAssistantInterpretResponse({
    required this.command,
    required this.result,
  });

  final String command;
  final CustomerAssistantResolvedCommand result;

  factory CustomerAssistantInterpretResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawResult = json['result'];

    if (rawResult is! Map) {
      throw const FormatException(
        'La respuesta no contiene un comando interpretado.',
      );
    }

    return CustomerAssistantInterpretResponse(
      command: json['command']?.toString() ?? '',
      result: CustomerAssistantResolvedCommand.fromJson(
        Map<String, dynamic>.from(rawResult),
      ),
    );
  }
}

class CustomerAssistantExecuteResponse {
  const CustomerAssistantExecuteResponse({
    required this.action,
    required this.message,
    this.data,
    this.navigation,
  });

  final String action;
  final String message;
  final dynamic data;
  final CustomerAssistantNavigation? navigation;

  factory CustomerAssistantExecuteResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawNavigation = json['navigation'];

    return CustomerAssistantExecuteResponse(
      action: json['action']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: json['data'],
      navigation: rawNavigation is Map
          ? CustomerAssistantNavigation.fromJson(
              Map<String, dynamic>.from(rawNavigation),
            )
          : null,
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
