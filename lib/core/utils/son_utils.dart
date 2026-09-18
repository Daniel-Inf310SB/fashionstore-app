/// Utilidades para leer los JSON del backend.
///
/// IMPORTANTE: FastAPI/Pydantic v2 serializa los `Decimal` como STRING
/// (por ejemplo `"120.00"`), no como número. Por eso nunca se debe
/// hacer `json['price'] as double`: hay que pasar por estos helpers.

double parseDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? parseDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Formato de precio usado en toda la app: `Bs 120.00`.
String formatBs(double value) => 'Bs ${value.toStringAsFixed(2)}';