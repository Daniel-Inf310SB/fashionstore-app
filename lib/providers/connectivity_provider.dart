import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/connectivity_service.dart';

/// Estado global compartido. No crea otro monitor de red.
final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService.instance,
);

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final notifier = ref.watch(connectivityServiceProvider).status;
  final controller = StreamController<ConnectionStatus>();
  void listener() {
    if (!controller.isClosed) controller.add(notifier.value);
  }

  notifier.addListener(listener);
  controller.add(notifier.value);
  ref.onDispose(() {
    notifier.removeListener(listener);
    controller.close();
  });
  return controller.stream;
});
