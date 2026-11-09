import '../models/ai_assistant.dart';

typedef AIAssistantNavigationHandler = Future<void> Function(
  CustomerAssistantNavigation navigation,
);

class AIAssistantNavigationService {
  AIAssistantNavigationService._();

  static AIAssistantNavigationHandler? _handler;

  static void register(
    AIAssistantNavigationHandler handler,
  ) {
    _handler = handler;
  }

  static void unregister() {
    _handler = null;
  }

  static Future<void> handle(
    CustomerAssistantNavigation navigation,
  ) async {
    final handler = _handler;

    if (handler == null) {
      return;
    }

    await handler(navigation);
  }
}
