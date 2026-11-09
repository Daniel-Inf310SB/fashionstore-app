import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/branch.dart';
import 'tenant_context_service.dart';

class SelectedBranchService {
  SelectedBranchService._();

  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _storageKey =
      'fashionstore_selected_branch';

  static final ValueNotifier<StoreBranch?> selectedBranchNotifier =
      ValueNotifier<StoreBranch?>(null);

  static String? _initializedScope;
  static String? _activeStorageKey;

  static StoreBranch? get selectedBranch =>
      selectedBranchNotifier.value;

  static Future<void> initialize() async {
    final scope = await TenantContextService.selectionScope;
    if (_initializedScope == scope) return;
    _initializedScope = scope;
    _activeStorageKey = '${_storageKey}_$scope';
    selectedBranchNotifier.value = null;
    // Descartamos el formato antiguo sin ámbito de usuario.
    await _storage.delete(key: _storageKey);
    final raw = await _storage.read(key: _activeStorageKey!);

    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        selectedBranchNotifier.value =
            StoreBranch.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      await _storage.delete(key: _activeStorageKey!);
      selectedBranchNotifier.value = null;
    }
  }

  static Future<void> selectBranch(
    StoreBranch branch,
  ) async {
    await initialize();
    selectedBranchNotifier.value = branch;

    await _storage.write(
      key: _activeStorageKey!,
      value: jsonEncode(branch.toJson()),
    );
  }

  static Future<void> clearBranch() async {
    selectedBranchNotifier.value = null;
    if (_activeStorageKey != null) {
      await _storage.delete(key: _activeStorageKey!);
    }
    _initializedScope = null;
    _activeStorageKey = null;
  }
}
