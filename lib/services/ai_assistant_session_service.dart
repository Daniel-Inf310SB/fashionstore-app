import '../models/ai_assistant.dart';

class AIAssistantSessionService {
  AIAssistantSessionService._();

  static final List<AssistantChatMessage> messages = [
    const AssistantChatMessage(
      role: 'assistant',
      text:
          'Hola, soy el asistente de FashionStore. Puedo ayudarte a encontrar prendas, armar combinaciones y revisar opciones disponibles en tu sucursal.',
    ),
  ];

  static void reset() {
    messages
      ..clear()
      ..add(
        const AssistantChatMessage(
          role: 'assistant',
          text:
              'Hola, soy el asistente de FashionStore. Puedo ayudarte a encontrar prendas, armar combinaciones y revisar opciones disponibles en tu sucursal.',
        ),
      );
  }
}
