class FuelPrice {
  final int id;
  final String fuelType;
  final String serviceLevel;
  final double price;
  final bool isGuaranteed;
  final String? priceDate;

  const FuelPrice({
    required this.id,
    required this.fuelType,
    required this.serviceLevel,
    required this.price,
    this.isGuaranteed = false,
    this.priceDate,
  });

  factory FuelPrice.fromJson(Map<String, dynamic> json) {
    return FuelPrice(
      id: json['id'] as int,
      fuelType: json['fuel_type'] as String,
      serviceLevel: json['service_level'] as String,
      price: (json['price'] is String)
          ? double.parse(json['price'] as String)
          : (json['price'] as num).toDouble(),
      isGuaranteed: json['is_guaranteed'] as bool? ?? false,
      priceDate: json['price_date'] as String?,
    );
  }
}

class Fbo {
  final int id;
  final String airportIdentifier;
  final String name;
  final String? phone;
  final String? tollFreePhone;
  final String? asriFrequency;
  final String? website;
  final String? email;
  final String? description;
  final List<String> badges;
  final String? fuelBrand;
  final double? rating;
  final List<FuelPrice> fuelPrices;

  const Fbo({
    required this.id,
    required this.airportIdentifier,
    required this.name,
    this.phone,
    this.tollFreePhone,
    this.asriFrequency,
    this.website,
    this.email,
    this.description,
    this.badges = const [],
    this.fuelBrand,
    this.rating,
    this.fuelPrices = const [],
  });

  factory Fbo.fromJson(Map<String, dynamic> json) {
    return Fbo(
      id: json['id'] as int,
      airportIdentifier: json['airport_identifier'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      tollFreePhone: json['toll_free_phone'] as String?,
      asriFrequency: json['asri_frequency'] as String?,
      website: json['website'] as String?,
      email: json['email'] as String?,
      description: json['description'] as String?,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((b) => b.toString())
              .toList() ??
          [],
      fuelBrand: json['fuel_brand'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      fuelPrices: (json['fuel_prices'] as List<dynamic>?)
              ?.map((fp) => FuelPrice.fromJson(fp as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Cheapest 100LL price across all service levels.
  double? get cheapest100LL {
    final prices = fuelPrices
        .where((fp) => fp.fuelType == '100LL')
        .map((fp) => fp.price)
        .toList();
    if (prices.isEmpty) return null;
    prices.sort();
    return prices.first;
  }

  /// Cheapest Jet-A price across all service levels.
  double? get cheapestJetA {
    final prices = fuelPrices
        .where((fp) => fp.fuelType == 'Jet A' || fp.fuelType == 'Jet-A')
        .map((fp) => fp.price)
        .toList();
    if (prices.isEmpty) return null;
    prices.sort();
    return prices.first;
  }
}
