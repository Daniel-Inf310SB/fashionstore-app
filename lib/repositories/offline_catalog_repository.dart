import '../core/offline/offline_database.dart';
import '../models/branch.dart';
import '../models/catalog_models.dart';

/// Adaptador de caché local: reutiliza los modelos JSON existentes de Flutter.
/// No reemplaza CatalogService ni BranchService, ni realiza llamadas HTTP.
/// La capa de red guarda respuestas exitosas y consulta estas copias sin red.
class OfflineCatalogRepository {
  OfflineCatalogRepository({OfflineDatabase? database})
      : _database = database ?? OfflineDatabase.instance;

  final OfflineDatabase _database;

  static void _check(OfflineScope scope) {
    if (scope.tenantId <= 0 || scope.branchId <= 0 || scope.userId <= 0) {
      throw ArgumentError('Contexto tenant/sucursal/usuario inválido');
    }
  }

  /// La clave incluye la consulta completa (página, búsqueda, filtros y orden).
  /// Esto evita devolver resultados de otra consulta o un filtro distinto.
  static String catalogKey(Uri requestUri) {
    final params = requestUri.queryParametersAll.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final normalized = <String, String>{};
    for (final entry in params) {
      final sortedValues = [...entry.value]..sort();
      normalized[entry.key] = sortedValues.join(',');
    }
    return Uri(path: requestUri.path, queryParameters: normalized).toString();
  }

  /// Guardar el JSON *original* que CatalogPageResponse.fromJson ya comprende.
  /// Llamar solo tras recibir HTTP 200 y comprobar el tenant autorizado.
  Future<void> saveCatalog({
    required OfflineScope scope,
    required Uri requestUri,
    required Map<String, dynamic> responseJson,
  }) async {
    _check(scope);
    if (responseJson['items'] is! List) {
      throw FormatException('El catálogo no tiene lista items');
    }
    // Valida usando el mismo parser del servicio online antes de persistir.
    CatalogPageResponse.fromJson(responseJson);
    await _database.putCatalogSnapshot(
      scope: scope,
      cacheKey: 'catalog:${catalogKey(requestUri)}',
      data: responseJson,
    );
  }

  /// Entrega exactamente CatalogPageResponse (NO otro Product alternativo).
  Future<CatalogPageResponse?> readCatalog({
    required OfflineScope scope,
    required Uri requestUri,
  }) async {
    _check(scope);
    final json = await _database.getCatalogSnapshot(
      scope: scope,
      cacheKey: 'catalog:${catalogKey(requestUri)}',
    );
    return json == null ? null : CatalogPageResponse.fromJson(json);
  }

  /// Persiste una sucursal usando el mismo formato de StoreBranch.toJson().
  Future<void> saveBranch({
    required OfflineScope scope,
    required StoreBranch branch,
  }) async {
    _check(scope);
    if (branch.id != scope.branchId) {
      throw ArgumentError('La sucursal no corresponde al contexto offline');
    }
    await _database.putCatalogSnapshot(
      scope: scope,
      cacheKey: 'branch:${branch.id}',
      data: branch.toJson(),
    );
  }

  Future<StoreBranch?> readBranch(OfflineScope scope) async {
    _check(scope);
    final json = await _database.getCatalogSnapshot(
      scope: scope,
      cacheKey: 'branch:${scope.branchId}',
    );
    return json == null ? null : StoreBranch.fromJson(json);
  }
}
