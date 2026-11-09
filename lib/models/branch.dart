class StoreCity {
  const StoreCity({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory StoreCity.fromJson(Map<String, dynamic> json) {
    return StoreCity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class StoreBranch {
  const StoreBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.cityId,
    required this.city,
    required this.isActive,
    this.phone,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String name;
  final String address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final int cityId;
  final StoreCity city;
  final bool isActive;

  factory StoreBranch.fromJson(Map<String, dynamic> json) {
    final rawCity = json['city'];

    return StoreBranch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Sucursal',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString(),
      latitude: _toNullableDouble(json['latitude']),
      longitude: _toNullableDouble(json['longitude']),
      cityId: (json['city_id'] as num?)?.toInt() ?? 0,
      city: rawCity is Map
          ? StoreCity.fromJson(
              Map<String, dynamic>.from(rawCity),
            )
          : StoreCity(
              id: (json['city_id'] as num?)?.toInt() ?? 0,
              name: '',
            ),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'city_id': cityId,
      'city': city.toJson(),
      'is_active': isActive,
    };
  }
}

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
