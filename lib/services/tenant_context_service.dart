import 'package:shared_preferences/shared_preferences.dart';

/// Contexto de presentación de la cuenta autenticada.
/// El servidor sigue siendo responsable de autorizar y aislar datos.
class TenantContextService {
  static Future<int?> get tenantId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('auth_tenant_id');
  }

  static Future<String?> get tenantSlug async {
    final prefs = await SharedPreferences.getInstance();
    final slug = prefs.getString('auth_tenant_slug');
    return slug == null || slug.trim().isEmpty ? null : slug;
  }

  static Future<String?> get tenantName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_tenant_name');
  }

  static Future<String> get selectionScope async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('auth_user_id');
    final tenantId = prefs.getInt('auth_tenant_id');
    if (userId == null || userId.isEmpty || tenantId == null) {
      throw StateError('Debes iniciar sesión en una empresa antes de seleccionar sucursal.');
    }
    return '${tenantId}_$userId';
  }

  static Future<String> requireTenantSlug() async {
    final slug = await tenantSlug;
    if (slug == null) {
      throw StateError('Tu cuenta no tiene una empresa asignada. Vuelve a iniciar sesión.');
    }
    return slug;
  }

  static Future<String> withTenant(String endpoint) async {
    final slug = await requireTenantSlug();
    final uri = Uri.parse(endpoint);
    return uri.replace(queryParameters: {...uri.queryParameters, 'tenant_slug': slug}).toString();
  }
}
