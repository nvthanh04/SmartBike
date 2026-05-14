import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

/// Service cập nhật vị trí xe real-time qua Firebase Realtime Database
/// Dùng Realtime Database thay vì Firestore vì tối ưu cho ghi/đọc liên tục GPS
class RealtimeLocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Đường dẫn node trên Realtime Database
  static const String _bikesLocationPath = 'bike_locations';

  // ===================== GHI VỊ TRÍ =====================

  /// Cập nhật vị trí xe lên Realtime Database
  /// Gọi liên tục khi xe đang di chuyển (từ GPS của user)
  Future<void> updateBikeLocation(
    String bikeId,
    double latitude,
    double longitude,
  ) async {
    await _dbRef.child('$_bikesLocationPath/$bikeId').set({
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': ServerValue.timestamp,
    });
  }

  // ===================== ĐỌC VỊ TRÍ (REALTIME) =====================

  /// Stream lắng nghe vị trí của một xe (realtime)
  /// Trả về Map {'latitude': ..., 'longitude': ..., 'updatedAt': ...}
  Stream<Map<String, dynamic>?> getBikeLocationStream(String bikeId) {
    return _dbRef
        .child('$_bikesLocationPath/$bikeId')
        .onValue
        .map((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return data;
      }
      return null;
    });
  }

  /// Lấy vị trí hiện tại của xe (one-time)
  Future<Map<String, dynamic>?> getBikeLocation(String bikeId) async {
    final snapshot =
        await _dbRef.child('$_bikesLocationPath/$bikeId').get();
    if (snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  // ===================== XÓA VỊ TRÍ =====================

  /// Xóa vị trí xe khi xe trả về trạm
  Future<void> removeBikeLocation(String bikeId) async {
    await _dbRef.child('$_bikesLocationPath/$bikeId').remove();
  }

  // ===================== GIẢ LẬP DI CHUYỂN (EMULATOR) =====================

  /// Giả lập xe di chuyển từ điểm A đến điểm B
  /// Dùng cho testing trên Emulator
  /// [steps] = số bước di chuyển, [intervalMs] = khoảng cách giữa các bước (ms)
  Timer? _simulationTimer;

  void simulateMovement({
    required String bikeId,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    int steps = 20,
    int intervalMs = 1000,
  }) {
    int currentStep = 0;
    final latStep = (endLat - startLat) / steps;
    final lngStep = (endLng - startLng) / steps;

    // Hủy simulation cũ nếu có
    stopSimulation();

    _simulationTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (timer) {
        if (currentStep >= steps) {
          timer.cancel();
          debugPrint('Giả lập kết thúc cho xe $bikeId');
          return;
        }

        // Thêm chút nhiễu random cho tự nhiên
        final random = Random();
        final noise = (random.nextDouble() - 0.5) * 0.0001;

        final lat = startLat + (latStep * currentStep) + noise;
        final lng = startLng + (lngStep * currentStep) + noise;

        updateBikeLocation(bikeId, lat, lng);
        debugPrint(
            'Xe $bikeId → bước $currentStep/$steps: ($lat, $lng)');

        currentStep++;
      },
    );
  }

  /// Dừng giả lập di chuyển
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }
}
