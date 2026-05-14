import 'package:cloud_firestore/cloud_firestore.dart';

class Station {
  final String id;
  final String stationId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int capacity; // Sức chứa tối đa
  int currentBikes; // Số xe đang có tại trạm

  Station({
    required this.id,
    this.stationId = '',
    required this.name,
    this.address = '',
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.currentBikes,
  });

  // Chuyển từ JSON (Database) sang Object
  // Hỗ trợ cả GeoPoint (trường 'location') và tọa độ riêng lẻ
  factory Station.fromJson(Map<String, dynamic> json, String id) {
    double lat = 0.0;
    double lng = 0.0;

    // Ưu tiên đọc từ trường 'location' kiểu GeoPoint
    if (json['location'] != null && json['location'] is GeoPoint) {
      final GeoPoint geoPoint = json['location'] as GeoPoint;
      lat = geoPoint.latitude;
      lng = geoPoint.longitude;
    } else {
      // Fallback: đọc từ trường latitude/longitude riêng lẻ
      lat = (json['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (json['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    return Station(
      id: id,
      stationId: json['stationId']?.toString() ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: lat,
      longitude: lng,
      capacity: json['capacity'] ?? 0,
      currentBikes: json['currentBikes'] ?? 0,
    );
  }

  // Chuyển từ Object sang JSON để lưu lên Database
  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,
      'name': name,
      'address': address,
      'location': GeoPoint(latitude, longitude),
      'capacity': capacity,
      'currentBikes': currentBikes,
    };
  }
}