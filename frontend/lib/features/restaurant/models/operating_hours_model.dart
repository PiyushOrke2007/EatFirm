/// Represents weekly operating hours schedule for a restaurant.
class OperatingHoursModel {
  final String? id;
  final String? restaurantId;
  final String dayOfWeek;
  final String openTime;
  final String closeTime;
  final bool isClosed;

  const OperatingHoursModel({
    this.id,
    this.restaurantId,
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    this.isClosed = false,
  });

  String get displayDayName {
    if (dayOfWeek.isEmpty) return '';
    return dayOfWeek[0].toUpperCase() + dayOfWeek.substring(1).toLowerCase();
  }

  String get formattedTime => isClosed ? 'Closed' : '$openTime - $closeTime';

  factory OperatingHoursModel.fromJson(Map<String, dynamic> json) {
    return OperatingHoursModel(
      id: json['id'] as String?,
      restaurantId: json['restaurantId'] as String?,
      dayOfWeek: json['dayOfWeek'] as String,
      openTime: json['openTime'] as String,
      closeTime: json['closeTime'] as String,
      isClosed: json['isClosed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (restaurantId != null) 'restaurantId': restaurantId,
      'dayOfWeek': dayOfWeek,
      'openTime': openTime,
      'closeTime': closeTime,
      'isClosed': isClosed,
    };
  }

  OperatingHoursModel copyWith({
    String? id,
    String? restaurantId,
    String? dayOfWeek,
    String? openTime,
    String? closeTime,
    bool? isClosed,
  }) {
    return OperatingHoursModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      isClosed: isClosed ?? this.isClosed,
    );
  }
}
