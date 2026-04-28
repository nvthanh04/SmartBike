class Station {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int capacity; // Sức chứa tối đa
  int currentBikes; // Số xe đang có tại trạm

  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.currentBikes,
  });

  // Chuyển từ JSON (Database) sang Object
  factory Station.fromJson(Map<String, dynamic> json, String id) {
    return Station(
      id: id,
      name: json['name'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      capacity: json['capacity'] ?? 0,
      currentBikes: json['currentBikes'] ?? 0,
    );
  }

  // Chuyển từ Object sang JSON để lưu lên Database
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'currentBikes': currentBikes,
    };
  }
}