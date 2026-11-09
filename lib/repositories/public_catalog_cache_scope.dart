import 'package:shared_preferences/shared_preferences.dart';

import '../core/offline/offline_database.dart';
import '../services/tenant_context_service.dart';

/// Ámbito exclusivo de DATOS PÚBLICOS (catálogo y sucursales).
/// No utilizar este ámbito para ventas, reservas, carrito ni datos privados.
class PublicCatalogCacheScope {
  PublicCatalogCacheScope._();
  static const int globalBranch = 2147483647;
  static const int publicUser = 1;

  static Future<OfflineScope> resolve({int? branchId}) async {
    final prefs = await SharedPreferences.getInstance();
    final slug = (await TenantContextService.requireTenantSlug()).trim();
    // Usa el ID real si existe; en sesiones antiguas permite un ámbito
    // determinista por slug sin inventar acceso a un tenant distinto.
    final realTenantId = prefs.getInt('auth_tenant_id');
    final tenantId = realTenantId != null && realTenantId > 0
        ? realTenantId
        : _stableSlugId(slug);
    final resolvedBranch = branchId ?? globalBranch;
    if (resolvedBranch <= 0) {
      throw ArgumentError('La sucursal debe tener ID positivo.');
    }
    return OfflineScope(
      tenantId: tenantId,
      branchId: resolvedBranch,
      userId: publicUser,
    );
  }

  static int _stableSlugId(String slug) {
    // FNV-1a de 32 bits, estable entre reinicios. Nunca usado para autorizar.
    var hash = 2166136261;
    for (final codePoint in slug.codeUnits) {
      hash = ((hash ^ codePoint) * 16777619) & 0xffffffff;
    }
    return (hash & 0x7fffffff) + 1;
  }
}
