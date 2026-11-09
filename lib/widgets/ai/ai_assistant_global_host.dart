import 'package:flutter/material.dart';

import '../../models/ai_assistant.dart';
import '../../services/ai_assistant_context_service.dart';
import '../../services/ai_assistant_navigation_service.dart';
import '../../services/push_notification_service.dart';
import '../../screens/ai/ai_assistant_screen.dart';
import 'ai_assistant_floating_button.dart';

class AIAssistantGlobalHost extends StatefulWidget {
  const AIAssistantGlobalHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AIAssistantGlobalHost> createState() =>
      _AIAssistantGlobalHostState();
}

class _AIAssistantGlobalHostState
    extends State<AIAssistantGlobalHost> {
  bool _assistantOpen = false;

  Future<void> _openAssistant() async {
    if (_assistantOpen) {
      return;
    }

    final navigator =
        PushNotificationService.navigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    final assistantContext =
        AIAssistantContextService.current;

    setState(() {
      _assistantOpen = true;
    });

    try {
      final navigation =
          await navigator.push<CustomerAssistantNavigation>(
        MaterialPageRoute(
          builder: (_) => AIAssistantScreen(
            currentPage:
                assistantContext.currentPage,
            productId:
                assistantContext.productId,
            variantId:
                assistantContext.variantId,
            cartItemId:
                assistantContext.cartItemId,
            reservationId:
                assistantContext.reservationId,
          ),
        ),
      );

      if (navigation != null) {
        await AIAssistantNavigationService.handle(
          navigation,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _assistantOpen = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AIAssistantContextState>(
      valueListenable:
          AIAssistantContextService.notifier,
      builder: (
        context,
        assistantContext,
        _,
      ) {
        return Stack(
          children: [
            widget.child,
            if (assistantContext.enabled &&
                !_assistantOpen)
              Positioned(
                right: 14,
                bottom: 82,
                child: SafeArea(
                  top: false,
                  child:
                      AIAssistantFloatingButton(
                    onTap: _openAssistant,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
