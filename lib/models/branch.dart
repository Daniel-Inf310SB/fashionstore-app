import '../core/utils/son_utils.dart';

/// Ciudad de una sucursal.
class StoreCity {
  final int id;
  final String name;

  const StoreCity({required this.id, required this.name});

  factory StoreCity.fromJson(Map<String, dynamic> json) {
    return StoreCity(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

/// Sucursal pública (`GET /store/branches`).
class StoreBranch {
  final int id;
  final String name;
  final String address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final StoreCity city;

  const StoreBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.phone,
    this.latitude,
    this.longitude,
  });

  factory StoreBranch.fromJson(Map<String, dynamic> json) {
    return StoreBranch(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String?,
      latitude: parseDoubleOrNull(json['latitude']),
      longitude: parseDoubleOrNull(json['longitude']),
      city: StoreCity.fromJson(json['city'] as Map<String, dynamic>),
    );
  }
}