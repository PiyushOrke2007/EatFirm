/// Metadata included in all EatFirm API responses.
class ApiMeta {
  final String requestId;
  final DateTime timestamp;

  const ApiMeta({required this.requestId, required this.timestamp});

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(
      requestId: (json['requestId'] as String?) ?? 'unknown',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Standard success API response envelope from EatFirm backend.
class ApiResponse<T> {
  final bool success;
  final T data;
  final ApiMeta meta;

  const ApiResponse({
    required this.success,
    required this.data,
    required this.meta,
  });
}

/// Standard pagination metadata.
class PaginationMeta {
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      hasNext: (json['hasNext'] as bool?) ?? false,
      hasPrev: (json['hasPrev'] as bool?) ?? false,
    );
  }
}

/// Paginated data container.
class PaginatedData<T> {
  final List<T> items;
  final PaginationMeta pagination;

  const PaginatedData({required this.items, required this.pagination});
}
