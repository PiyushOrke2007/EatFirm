/// Filter and sorting criteria for restaurant discovery feed (SRS BROWSE-1, BROWSE-2).
class BrowseFilterModel {
  final String? search;
  final String? cuisine;
  final double? minRating;
  final double? maxDistanceKm;
  final int? maxDeliveryMins;
  final String? priceTier;
  final bool? vegOnly;
  final bool? isOpenOnly;
  final double? latitude;
  final double? longitude;
  final String? sortBy;
  final int page;
  final int limit;

  const BrowseFilterModel({
    this.search,
    this.cuisine,
    this.minRating,
    this.maxDistanceKm,
    this.maxDeliveryMins,
    this.priceTier,
    this.vegOnly,
    this.isOpenOnly,
    this.latitude,
    this.longitude,
    this.sortBy,
    this.page = 1,
    this.limit = 20,
  });

  BrowseFilterModel copyWith({
    String? search,
    String? cuisine,
    double? minRating,
    double? maxDistanceKm,
    int? maxDeliveryMins,
    String? priceTier,
    bool? vegOnly,
    bool? isOpenOnly,
    double? latitude,
    double? longitude,
    String? sortBy,
    int? page,
    int? limit,
    bool clearSearch = false,
    bool clearCuisine = false,
    bool clearPriceTier = false,
    bool clearMinRating = false,
    bool clearMaxDistance = false,
    bool clearMaxDeliveryMins = false,
    bool clearVegOnly = false,
  }) {
    return BrowseFilterModel(
      search: clearSearch ? null : (search ?? this.search),
      cuisine: clearCuisine ? null : (cuisine ?? this.cuisine),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      maxDistanceKm:
          clearMaxDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
      maxDeliveryMins: clearMaxDeliveryMins
          ? null
          : (maxDeliveryMins ?? this.maxDeliveryMins),
      priceTier: clearPriceTier ? null : (priceTier ?? this.priceTier),
      vegOnly: clearVegOnly ? null : (vegOnly ?? this.vegOnly),
      isOpenOnly: isOpenOnly ?? this.isOpenOnly,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search!.trim().isNotEmpty) {
      params['search'] = search!.trim();
    }
    if (cuisine != null && cuisine!.trim().isNotEmpty) {
      params['cuisine'] = cuisine!.trim();
    }
    if (minRating != null && minRating! > 0) {
      params['minRating'] = minRating!.toString();
    }
    if (maxDistanceKm != null && maxDistanceKm! > 0) {
      params['maxDistanceKm'] = maxDistanceKm!.toString();
    }
    if (maxDeliveryMins != null && maxDeliveryMins! > 0) {
      params['maxDeliveryMins'] = maxDeliveryMins!.toString();
    }
    if (priceTier != null && priceTier!.trim().isNotEmpty) {
      params['priceTier'] = priceTier!.trim();
    }
    if (vegOnly != null) {
      params['vegOnly'] = vegOnly!.toString();
    }
    if (isOpenOnly != null) {
      params['isOpenOnly'] = isOpenOnly!.toString();
    }
    if (latitude != null) {
      params['latitude'] = latitude!.toString();
    }
    if (longitude != null) {
      params['longitude'] = longitude!.toString();
    }
    if (sortBy != null && sortBy!.trim().isNotEmpty) {
      params['sortBy'] = sortBy!.trim();
    }

    return params;
  }
}

