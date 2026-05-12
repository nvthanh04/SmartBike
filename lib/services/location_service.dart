import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Dữ liệu vị trí kèm hướng
class LocationData {
  final LatLng position;
  final double heading; // Góc hướng (0-360), 0 = Bắc

  LocationData({required this.position, required this.heading});
}

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Kiểm tra và yêu cầu quyền GPS
  Future<void> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return Future.error('GPS chưa được bật. Vui lòng bật GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Bạn đã từ chối quyền truy cập GPS.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Quyền GPS bị từ chối vĩnh viễn. Vào Cài đặt để cấp quyền.',
      );
    }
  }

  /// Lấy vị trí lưu trữ gần nhất (nhanh, không cần đợi GPS)
  Future<LocationData?> getLastKnownLocation() async {
    if (kIsWeb) {
      return null; // Web không hỗ trợ getLastKnownPosition
    }

    try {
      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        return LocationData(
          position: LatLng(position.latitude, position.longitude),
          heading: position.heading,
        );
      }
    } catch (e) {
      // Bắt lỗi nếu thiết bị không hỗ trợ hoặc có lỗi khác
    }
    return null;
  }

  /// Lấy vị trí hiện tại một lần (kèm heading) - Có thể chậm nếu GPS yếu
  Future<LocationData> getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LocationData(
      position: LatLng(position.latitude, position.longitude),
      heading: position.heading,
    );
  }

  /// Lấy vị trí hiện tại với độ chính xác thấp để có kết quả ngay lập tức (dùng làm fallback)
  Future<LocationData?> getFastLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // Lấy vị trí mạng/Wi-Fi (rất nhanh)
        timeLimit: const Duration(seconds: 3), // Ép trả kết quả nhanh
      );
      return LocationData(
        position: LatLng(position.latitude, position.longitude),
        heading: position.heading,
      );
    } catch (e) {
      return null;
    }
  }

  /// Bắt đầu theo dõi vị trí realtime (kèm heading)
  void startPositionStream({
    required void Function(LocationData locationData) onLocationChanged,
    void Function(dynamic error)? onError,
    int distanceFilter = 5,
  }) {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final data = LocationData(
          position: LatLng(position.latitude, position.longitude),
          heading: position.heading,
        );
        onLocationChanged(data);
      },
      onError: onError,
    );
  }

  /// Hủy stream khi không cần nữa
  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}
