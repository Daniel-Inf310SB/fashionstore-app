import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../models/ai_assistant.dart';

class AIAssistantContextState {
  const AIAssistantContextState({
    this.enabled = false,
    this.currentPage = 'home',
    this.productId,
    this.variantId,
    this.cartItemId,
    this.reservationId,
  });

  final bool enabled;
  final String currentPage;
  final int? productId;
  final int? variantId;
  final int? cartItemId;
  final int? reservationId;

  CustomerAssistantContext toAssistantContext({
    int? branchId,
  }) {
    return CustomerAssistantContext(
      currentPage: currentPage,
      branchId: branchId,
      productId: productId,
      variantId: variantId,
      cartItemId: cartItemId,
      reservationId: reservationId,
    );
  }
}

class AIAssistantContextService {
  AIAssistantContextService._();

  static final ValueNotifier<AIAssistantContextState> notifier =
      ValueNotifier<AIAssistantContextState>(
    const AIAssistantContextState(),
  );

  static AIAssistantContextState get current =>
      notifier.value;

  static void _update(
    AIAssistantContextState state,
  ) {
    final phase =
        WidgetsBinding.instance.schedulerPhase;

    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          notifier.value = state;
        },
      );

      return;
    }

    notifier.value = state;
  }

  static void enable({
    String currentPage = 'home',
  }) {
    _update(
      AIAssistantContextState(
        enabled: true,
        currentPage: currentPage,
      ),
    );
  }

  static void disable() {
    _update(
      const AIAssistantContextState(),
    );
  }

  static void setPage(
    String currentPage, {
    int? productId,
    int? variantId,
    int? cartItemId,
    int? reservationId,
  }) {
    _update(
      AIAssistantContextState(
        enabled: true,
        currentPage: currentPage,
        productId: productId,
        variantId: variantId,
        cartItemId: cartItemId,
        reservationId: reservationId,
      ),
    );
  }

  static void setProduct({
    required int productId,
    int? variantId,
  }) {
    setPage(
      'product',
      productId: productId,
      variantId: variantId,
    );
  }

  static void setReservation(
    int reservationId,
  ) {
    setPage(
      'reservation_detail',
      reservationId: reservationId,
    );
  }
}