import 'product.dart';

class HomePromotion {
  const HomePromotion({
    required this.id,
    required this.name,
    required this.discountType,
    required this.discountValue,
    required this.startAt,
    required this.endAt,
    required this.productCount,
    this.description,
  });

  final int id;
  final String name;
  final String? description;
  final String discountType;
  final double discountValue;
  final DateTime? startAt;
  final DateTime? endAt;
  final int productCount;

  String get discountLabel {
    final value = discountValue % 1 == 0
        ? discountValue.toStringAsFixed(0)
        : discountValue.toStringAsFixed(2);

    if (discountType.toUpperCase() == 'PERCENTAGE') {
      return '$value% OFF';
    }

    return 'Bs $value OFF';
  }

  String? get endDateLabel {
    final value = endAt;

    if (value == null) {
      return null;
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return '$day/$month/${local.year}';
  }

  factory HomePromotion.fromJson(Map<String, dynamic> json) {
    return HomePromotion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: _toDouble(json['discount_value']),
      startAt: DateTime.tryParse(json['start_at']?.toString() ?? ''),
      endAt: DateTime.tryParse(json['end_at']?.toString() ?? ''),
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class HomeCollection {
  const HomeCollection({
    required this.id,
    required this.name,
    required this.productCount,
    this.description,
    this.launchDate,
  });

  final int id;
  final String name;
  final String? description;
  final DateTime? launchDate;
  final int productCount;

  factory HomeCollection.fromJson(Map<String, dynamic> json) {
    return HomeCollection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      launchDate:
          DateTime.tryParse(json['launch_date']?.toString() ?? ''),
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class HomeSeason {
  const HomeSeason({
    required this.id,
    required this.name,
    required this.productCount,
    this.description,
    this.startDate,
    this.endDate,
  });

  final int id;
  final String name;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final int productCount;

  factory HomeSeason.fromJson(Map<String, dynamic> json) {
    return HomeSeason(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      startDate:
          DateTime.tryParse(json['start_date']?.toString() ?? ''),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? ''),
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class HomeBanner {
  const HomeBanner({required this.id, required this.title, required this.imageUrl,
    required this.targetType, this.subtitle, this.mobileImageUrl, this.targetId, this.showAsPopup = false, this.popupPriority = 0});
  final int id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? mobileImageUrl;
  final String targetType;
  final int? targetId;
  final bool showAsPopup;
  final int popupPriority;

  String get displayImage => mobileImageUrl?.isNotEmpty == true ? mobileImageUrl! : imageUrl;

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString(),
    imageUrl: json['image_url']?.toString() ?? '',
    mobileImageUrl: json['mobile_image_url']?.toString(),
    targetType: json['target_type']?.toString() ?? 'catalog',
    targetId: (json['target_id'] as num?)?.toInt(),
    showAsPopup: json['show_as_popup'] == true,
    popupPriority: (json['popup_priority'] as num?)?.toInt() ?? 0,
  );
}

class HomeCategory {
  const HomeCategory({required this.id, required this.name, required this.productCount});
  final int id;
  final String name;
  final int productCount;
  factory HomeCategory.fromJson(Map<String, dynamic> json) => HomeCategory(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    productCount: (json['product_count'] as num?)?.toInt() ?? 0,
  );
}

class HomeBestSeller {
  const HomeBestSeller({required this.productId, required this.name, required this.unitsSold, this.coverImageUrl});
  final int productId;
  final String name;
  final int unitsSold;
  final String? coverImageUrl;
  factory HomeBestSeller.fromJson(Map<String, dynamic> json) => HomeBestSeller(
    productId: (json['product_id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    unitsSold: (json['units_sold'] as num?)?.toInt() ?? 0,
    coverImageUrl: json['cover_image_url']?.toString(),
  );
}

class HomeData {
  const HomeData({
    required this.promotions,
    required this.collections,
    required this.seasons,
    required this.featuredProducts,
    required this.seasonProducts,
    this.banners = const [],
    this.categories = const [],
    this.offers = const [],
    this.bestSellers = const [],
    this.recommended = const [],
  });
  final List<HomeBanner> banners;
  final List<HomeCategory> categories;
  final List<Product> offers;
  final List<HomeBestSeller> bestSellers;
  final List<Product> recommended;
  final List<HomePromotion> promotions;
  final List<HomeCollection> collections;
  final List<HomeSeason> seasons;
  final List<Product> featuredProducts;
  final List<Product> seasonProducts;
  HomeSeason? get activeSeason => seasons.isNotEmpty ? seasons.first : null;

  factory HomeData.fromStoreJson(Map<String, dynamic> json) => HomeData(
    banners: _homeItems(json['banners'], HomeBanner.fromJson),
    categories: _homeItems(json['categories'], HomeCategory.fromJson),
    offers: _homeItems(json['offers'], Product.fromJson),
    bestSellers: _homeItems(json['best_sellers'], HomeBestSeller.fromJson),
    recommended: _homeItems(json['recommended'], Product.fromJson),
    promotions: _homeItems(json['promotions'], HomePromotion.fromJson),
    collections: _homeItems(json['featured_collections'], HomeCollection.fromJson),
    seasons: const [],
    featuredProducts: _homeItems(json['new_arrivals'], Product.fromJson),
    seasonProducts: const [],
  );
}

List<T> _homeItems<T>(dynamic source, T Function(Map<String, dynamic>) parse) {
  if (source is! List) return <T>[];
  final values = <T>[];
  for (final value in source) {
    if (value is! Map) continue;
    try { values.add(parse(Map<String, dynamic>.from(value))); } catch (_) { /* Skip one malformed item, not the whole home. */ }
  }
  return values;
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}
