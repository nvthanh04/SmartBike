import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/station_model.dart';
import '../models/bike_model.dart';

/// Model cho cảnh báo trạm
class StationAlert {
  final Station station;
  final int currentBikes;
  final String alertType; // 'low' = thiếu xe, 'high' = thừa xe
  final String message;

  StationAlert({
    required this.station,
    required this.currentBikes,
    required this.alertType,
    required this.message,
  });

  /// Tỷ lệ lấp đầy (%)
  double get fillPercent =>
      station.capacity > 0 ? (currentBikes / station.capacity) * 100 : 0;
}

/// Model cho đề xuất điều phối xe
class TransferSuggestion {
  final Station fromStation;
  final Station toStation;
  final int fromBikes;
  final int toBikes;
  final int transferCount;
  final double distanceKm;

  TransferSuggestion({
    required this.fromStation,
    required this.toStation,
    required this.fromBikes,
    required this.toBikes,
    required this.transferCount,
    required this.distanceKm,
  });
}

/// Service phân tích & cảnh báo trạm cho Admin
class AdminNotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Ngưỡng cảnh báo
  static const int lowThresholdAbsolute = 3;
  static const double lowThresholdPercent = 0.20;
  static const double highThresholdPercent = 0.90;

  /// Kiểm tra trạm thiếu xe
  static bool isLowStation(int bikeCount, int capacity) {
    return bikeCount <= lowThresholdAbsolute ||
        (capacity > 0 && bikeCount / capacity <= lowThresholdPercent);
  }

  /// Kiểm tra trạm thừa xe
  static bool isHighStation(int bikeCount, int capacity) {
    return capacity > 0 && bikeCount / capacity >= highThresholdPercent;
  }

  /// Lấy danh sách tất cả cảnh báo (trạm thiếu + thừa xe)
  Future<List<StationAlert>> getStationAlerts() async {
    final stationSnap = await _db.collection('stations').get();
    final stations = stationSnap.docs
        .map((doc) => Station.fromJson(doc.data(), doc.id))
        .where((s) => s.status == 'active')
        .toList();

    final bikeSnap = await _db.collection('bikes').get();
    final bikes =
        bikeSnap.docs.map((doc) => Bike.fromJson(doc.data(), doc.id)).toList();

    Map<String, int> bikeCounts = {};
    for (var bike in bikes) {
      if (bike.stationId.isNotEmpty) {
        bikeCounts[bike.stationId] = (bikeCounts[bike.stationId] ?? 0) + 1;
      }
    }

    List<StationAlert> alerts = [];
    for (var station in stations) {
      int count = bikeCounts[station.id] ?? 0;

      if (isLowStation(count, station.capacity)) {
        alerts.add(StationAlert(
          station: station,
          currentBikes: count,
          alertType: 'low',
          message: 'Trạm ${station.name} chỉ còn $count/${station.capacity} xe!',
        ));
      } else if (isHighStation(count, station.capacity)) {
        alerts.add(StationAlert(
          station: station,
          currentBikes: count,
          alertType: 'high',
          message:
              'Trạm ${station.name} gần đầy $count/${station.capacity} xe!',
        ));
      }
    }

    alerts.sort((a, b) {
      if (a.alertType == 'low' && b.alertType == 'high') return -1;
      if (a.alertType == 'high' && b.alertType == 'low') return 1;
      return a.currentBikes.compareTo(b.currentBikes);
    });

    return alerts;
  }

  /// Tính khoảng cách Haversine giữa 2 điểm (km)
  static double haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180;

  /// Tạo đề xuất điều phối xe tối ưu
  Future<List<TransferSuggestion>> getTransferSuggestions() async {
    final stationSnap = await _db.collection('stations').get();
    final stations = stationSnap.docs
        .map((doc) => Station.fromJson(doc.data(), doc.id))
        .where((s) => s.status == 'active')
        .toList();

    final bikeSnap = await _db.collection('bikes').get();
    final bikes =
        bikeSnap.docs.map((doc) => Bike.fromJson(doc.data(), doc.id)).toList();

    Map<String, int> bikeCounts = {};
    for (var bike in bikes) {
      if (bike.stationId.isNotEmpty) {
        bikeCounts[bike.stationId] = (bikeCounts[bike.stationId] ?? 0) + 1;
      }
    }

    List<_StationWithCount> overStations = [];
    List<_StationWithCount> underStations = [];

    for (var station in stations) {
      int count = bikeCounts[station.id] ?? 0;
      if (isHighStation(count, station.capacity)) {
        overStations.add(_StationWithCount(station, count));
      } else if (isLowStation(count, station.capacity)) {
        underStations.add(_StationWithCount(station, count));
      }
    }

    List<TransferSuggestion> suggestions = [];
    Set<String> usedOverStations = {};

    underStations.sort((a, b) => a.count.compareTo(b.count));

    for (var under in underStations) {
      double bestDistance = double.infinity;
      _StationWithCount? bestOver;

      for (var over in overStations) {
        if (usedOverStations.contains(over.station.id)) continue;

        double dist = haversineDistance(
          over.station.latitude,
          over.station.longitude,
          under.station.latitude,
          under.station.longitude,
        );

        if (dist < bestDistance) {
          bestDistance = dist;
          bestOver = over;
        }
      }

      if (bestOver != null) {
        int idealBikes = (under.station.capacity * 0.5).round();
        int needBikes = idealBikes - under.count;
        int excessBikes =
            bestOver.count - (bestOver.station.capacity * 0.5).round();
        int transferCount = needBikes < excessBikes ? needBikes : excessBikes;
        if (transferCount <= 0) transferCount = 1;

        suggestions.add(TransferSuggestion(
          fromStation: bestOver.station,
          toStation: under.station,
          fromBikes: bestOver.count,
          toBikes: under.count,
          transferCount: transferCount,
          distanceKm: double.parse(bestDistance.toStringAsFixed(2)),
        ));

        usedOverStations.add(bestOver.station.id);
      }
    }

    suggestions.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return suggestions;
  }

  /// Stream đếm số cảnh báo (cho badge chuông)
  Stream<int> getPendingTicketsCount() {
    return _db
        .collection('support_tickets')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}

class _StationWithCount {
  final Station station;
  final int count;
  _StationWithCount(this.station, this.count);
}
