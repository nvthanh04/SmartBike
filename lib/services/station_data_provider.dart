import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/station_model.dart';
import '../models/bike_model.dart';

/// Cung cấp dữ liệu trạm/xe cho AI context
class StationDataProvider {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _cachedSummary;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(seconds: 30);

  /// Tóm tắt tất cả trạm (có cache 30s)
  Future<String> getStationSummary() async {
    if (_cachedSummary != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedSummary!;
    }

    try {
      final stationSnap = await _db.collection('stations').get();
      final bikeSnap = await _db.collection('bikes').get();

      Map<String, int> bikeCounts = {};
      for (var doc in bikeSnap.docs) {
        final data = doc.data();
        final sid = data['stationId'] ?? '';
        if (sid.toString().isNotEmpty) {
          bikeCounts[sid] = (bikeCounts[sid] ?? 0) + 1;
        }
      }

      final buffer = StringBuffer();
      for (var doc in stationSnap.docs) {
        final s = Station.fromJson(doc.data(), doc.id);
        final count = bikeCounts[s.id] ?? 0;
        buffer.writeln('- ${s.name} (${s.address}): $count/${s.capacity} xe');
      }

      _cachedSummary = buffer.toString();
      _cacheTime = DateTime.now();
      return _cachedSummary!;
    } catch (e) {
      return '';
    }
  }

  /// Tìm trạm gần nhất
  Future<String> getNearestStation(double lat, double lng) async {
    try {
      final snap = await _db.collection('stations').get();
      final stations = snap.docs
          .map((d) => Station.fromJson(d.data(), d.id))
          .where((s) => s.status == 'active')
          .toList();

      if (stations.isEmpty) return 'Không có trạm nào.';

      Station? nearest;
      double minDist = double.infinity;
      for (var s in stations) {
        final d = _haversine(lat, lng, s.latitude, s.longitude);
        if (d < minDist) {
          minDist = d;
          nearest = s;
        }
      }

      if (nearest == null) return 'Không tìm thấy trạm.';
      return '${nearest.name} (${nearest.address}) - cách ${minDist.toStringAsFixed(1)}km';
    } catch (e) {
      return 'Lỗi tìm trạm.';
    }
  }

  /// Tìm trạm theo tên
  Future<String> searchStation(String keyword) async {
    try {
      final snap = await _db.collection('stations').get();
      final results = snap.docs
          .map((d) => Station.fromJson(d.data(), d.id))
          .where((s) => s.name.toLowerCase().contains(keyword.toLowerCase()))
          .toList();

      if (results.isEmpty) return 'Không tìm thấy trạm "$keyword".';
      return results.map((s) => '${s.name}: ${s.address}').join('\n');
    } catch (e) {
      return 'Lỗi tìm kiếm.';
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
