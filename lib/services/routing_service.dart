import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Kết quả tìm kiếm địa chỉ
class SearchResult {
  final String displayName;
  final LatLng location;

  SearchResult({required this.displayName, required this.location});
}

/// Một tuyến đường
class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;
  final bool isShortest; // Là đường ngắn nhất hay không

  RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    required this.isShortest,
  });
}

/// Kết quả tìm đường: gồm tất cả các tuyến
class RouteResult {
  final List<RouteInfo> allRoutes;       // Tất cả tuyến đường
  final RouteInfo shortestRoute;          // Tuyến ngắn nhất

  RouteResult({required this.allRoutes, required this.shortestRoute});
}

class RoutingService {
  /// Tìm kiếm địa chỉ bằng Nominatim (OpenStreetMap Geocoding)
  Future<List<SearchResult>> searchAddress(String query) async {
    if (query.trim().isEmpty) return [];

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query)}'
      '&format=json'
      '&limit=5'
      '&addressdetails=1',
    );

    final response = await http.get(url, headers: {
      'User-Agent': 'SmartBike/1.0',
    });

    if (response.statusCode != 200) {
      throw Exception('Lỗi tìm kiếm: ${response.statusCode}');
    }

    final List<dynamic> data = json.decode(response.body);
    return data.map((item) {
      return SearchResult(
        displayName: item['display_name'] as String,
        location: LatLng(
          double.parse(item['lat'] as String),
          double.parse(item['lon'] as String),
        ),
      );
    }).toList();
  }

  /// Tìm đường NGẮN NHẤT + các tuyến thay thế
  Future<RouteResult> getRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    // Gọi song song 3 profile của OSRM (ô tô, xe đạp, đi bộ)
    // Mỗi profile thường sẽ trả ra một con đường khác nhau (đường to, đường ngõ).
    // Bằng cách gộp cả 3, ta chắc chắn có 2-3 tuyến đường thay thế hoàn hảo.
    final profiles = ['driving', 'bike', 'foot'];
    final futures = profiles.map((mode) async {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$mode/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&alternatives=false',
      );
      try {
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
            return data['routes'][0];
          }
        }
      } catch (_) {}
      return null;
    });

    final results = await Future.wait(futures);
    final validRoutes = results.where((r) => r != null).toList();

    if (validRoutes.isEmpty) {
      throw Exception('Không tìm thấy đường đi.');
    }

    // Parse các tuyến đường
    final parsedRoutes = <RouteInfo>[];
    for (int i = 0; i < validRoutes.length; i++) {
      final route = validRoutes[i];
      final geometry = route['geometry']['coordinates'] as List;
      final distance = (route['distance'] as num).toDouble();
      
      final points = geometry.map<LatLng>((coord) {
        return LatLng(
          (coord[1] as num).toDouble(),
          (coord[0] as num).toDouble(),
        );
      }).toList();

      final distanceKm = distance / 1000;
      // Đặc thù app xe đạp: tính thời gian chung dựa trên vận tốc độ đạp xe 15km/h
      // Tránh việc tuyến đi bộ bị báo thời gian quá lâu
      final durationMin = (distanceKm / 15.0) * 60.0;

      parsedRoutes.add(RouteInfo(
        points: points,
        distanceKm: distanceKm,
        durationMin: durationMin,
        isShortest: false,
      ));
    }

    // Sắp xếp các tuyến từ ngắn đến dài theo khoảng cách
    parsedRoutes.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    // Chọn ra tất cả các tuyến không bị trùng hoàn toàn về đường đi
    final topRoutes = <RouteInfo>[parsedRoutes.first];
    for (int i = 1; i < parsedRoutes.length; i++) {
      bool isDuplicate = false;
      for (final selected in topRoutes) {
        // Thay vì so sánh khoảng cách tổng (dễ bị trùng trong thành phố bàn cờ),
        // Hãy so sánh xem điểm ở giữa tuyến đường có cách xa nhau không.
        final midIndexI = parsedRoutes[i].points.length ~/ 2;
        final midIndexSel = selected.points.length ~/ 2;
        if (parsedRoutes[i].points.isNotEmpty && selected.points.isNotEmpty) {
          final dist = const Distance().as(
            LengthUnit.Meter, 
            parsedRoutes[i].points[midIndexI], 
            selected.points[midIndexSel]
          );
          if (dist < 30) {
            isDuplicate = true; // Trùng nhau nếu điểm giữa của 2 lộ trình cách nhau quá gần (<30m)
            break;
          }
        }
      }
      if (!isDuplicate) topRoutes.add(parsedRoutes[i]);
    }
    
    // Gán lại isShortest cho tuyến ngắn nhất
    for (int i = 0; i < topRoutes.length; i++) {
        final r = topRoutes[i];
        topRoutes[i] = RouteInfo(
          points: r.points,
          distanceKm: r.distanceKm,
          durationMin: r.durationMin,
          isShortest: i == 0,
        );
    }

    return RouteResult(
      allRoutes: topRoutes,
      shortestRoute: topRoutes[0],
    );
  }

  /// Tính khoảng cách từ 1 điểm đến điểm gần nhất trên tuyến đường (mét)
  /// Dùng để phát hiện khi người dùng đi lệch đường
  static double distanceToRoute(LatLng point, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return double.infinity;

    double minDistance = double.infinity;
    const distance = Distance();

    for (final routePoint in routePoints) {
      final d = distance.as(LengthUnit.Meter, point, routePoint);
      if (d < minDistance) {
        minDistance = d;
      }
    }

    return minDistance;
  }
}
