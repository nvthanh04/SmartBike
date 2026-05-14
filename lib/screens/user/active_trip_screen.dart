import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'invoice_screen.dart';
import '../../models/station_model.dart';
import '../../models/bike_model.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import '../../services/station_service.dart';
import '../../services/bike_service.dart';
import '../../widgets/location_indicator.dart';
import '../../widgets/station_marker_icon.dart';

class ActiveTripScreen extends StatefulWidget {
  final String bikeId;
  final String startStationName;

  const ActiveTripScreen({super.key, required this.bikeId, required this.startStationName});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  // === TRẠNG THÁI CHUYẾN ĐI ===
  int _secondsElapsed = 0;
  Timer? _timer;
  bool _isMonthlyTicket = false;

  // === Vị trí ===
  LatLng? currentLocation = const LatLng(21.028511, 105.804817); // Mặc định ở Hà Nội để load bản đồ trong 0s
  double _heading = 0;
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  // === Tìm đường ===
  final RoutingService _routingService = RoutingService();
  final StationService _stationService = StationService();
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  RouteResult? _routeResult;
  LatLng? _destination;
  bool _isSearching = false;
  bool _isLoadingRoute = false;
  bool _showSearchResults = false;
  bool _isRerouting = false; // Đang tìm đường lại

  // Ngưỡng đi lệch đường (mét) - nếu cách tuyến đường > 50m thì tìm lại
  static const double _rerouteThreshold = 50;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
    _startTimer();
    _initLocationTracking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationService.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // =============================================
  // LOGIC CHUYẾN ĐI
  // =============================================

  Future<void> _checkUserStatus() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        setState(() {
          _isMonthlyTicket = userDoc.data()?['isMonthlyTicket'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi lấy dữ liệu người dùng: $e");
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  int _calculateCost() {
    int totalMinutes = (_secondsElapsed / 60).ceil();
    int finalAmount = 0;

    if (_isMonthlyTicket) {
      if (totalMinutes <= 60) {
        finalAmount = 0;
      } else {
        int extraTime = totalMinutes - 60;
        finalAmount = (extraTime / 10).ceil() * 3000;
      }
    } else {
      if (totalMinutes <= 60) {
        finalAmount = 10000;
      } else {
        int extraTime = totalMinutes - 60;
        finalAmount = 10000 + (extraTime / 10).ceil() * 3000;
      }
    }
    return finalAmount;
  }

  // =============================================
  // LOCATION TRACKING
  // =============================================

  Future<void> _initLocationTracking() async {
    try {
      // 1. Không block UI, bản đồ đã được render ngay lập tức với vị trí mặc định (Hà Nội)
      
      // Chạy lấy quyền bất đồng bộ (nếu người dùng chưa cấp quyền, bảng hỏi sẽ hiện lên nhưng không làm treo bản đồ)
      await _locationService.checkPermission();

      // 2. Thử lấy vị trí lưu trữ gần nhất (rất nhanh, áp dụng cho Mobile)
      final lastKnown = await _locationService.getLastKnownLocation();
      if (lastKnown != null && mounted) {
        setState(() {
          currentLocation = lastKnown.position;
          _heading = lastKnown.heading;
        });
        _mapController.move(lastKnown.position, 16.0);
      }

      // 3. Ép lấy vị trí hiện tại cực nhanh (mức low accuracy) giới hạn trong 1.5 giây
      // Điều này giải quyết vấn đề Web bị chậm > 1 phút
      _locationService.getFastLocation().then((fastLocation) {
        if (fastLocation != null && mounted) {
          setState(() {
            currentLocation = fastLocation.position;
            _heading = fastLocation.heading;
          });
          _mapController.move(fastLocation.position, 16.0);
        }
      });

      // 4. Lắng nghe GPS liên tục ở chế độ nền để tự động sửa lại vị trí khi GPS bắt nét (high accuracy)
      _locationService.startPositionStream(
        onLocationChanged: (locationData) {
          if (mounted) {
            setState(() {
              currentLocation = locationData.position;
              _heading = locationData.heading;
            });
            _checkOffRoute(locationData.position);
            _mapController.move(locationData.position, _mapController.zoom);
          }
        },
        onError: (error) {
          // Bỏ qua lỗi ngầm để không làm phiền người dùng
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chưa thể lấy vị trí: $e')),
        );
      }
    }
  }

  // =============================================
  // KIỂM TRA ĐI LỆCH ĐƯỜNG + TỰ ĐỘNG TÌM LẠI
  // =============================================

  void _checkOffRoute(LatLng currentPos) {
    if (_routeResult == null || _destination == null || _isRerouting) return;

    final distToRoute = RoutingService.distanceToRoute(
      currentPos,
      _routeResult!.shortestRoute.points,
    );

    if (distToRoute > _rerouteThreshold) {
      _reroute(currentPos);
    }
  }

  Future<void> _reroute(LatLng fromPos) async {
    if (_destination == null || _isRerouting) return;

    _isRerouting = true;

    try {
      final route = await _routingService.getRoute(
        from: fromPos,
        to: _destination!,
      );

      setState(() {
        _routeResult = route;
        _isRerouting = false;
      });

      _showSnackBar('🔄 Đã cập nhật đường đi mới');
    } catch (e) {
      _isRerouting = false;
    }
  }

  // =============================================
  // TÌM KIẾM ĐỊA CHỈ
  // =============================================

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      final results = await _routingService.searchAddress(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      _showSnackBar('Lỗi tìm kiếm: $e');
    }
  }

  // =============================================
  // TÌM ĐƯỜNG
  // =============================================

  Future<void> _getRoute(SearchResult result) async {
    if (currentLocation == null) return;

    setState(() {
      _destination = result.location;
      _showSearchResults = false;
      _isLoadingRoute = true;
      _searchController.text = result.displayName;
    });

    FocusScope.of(context).unfocus();

    try {
      final route = await _routingService.getRoute(
        from: currentLocation!,
        to: result.location,
      );

      setState(() {
        _routeResult = route;
        _isLoadingRoute = false;
      });

      _fitRouteBounds(route.shortestRoute.points);

      // final altCount = route.allRoutes.length - 1;
      // _showSnackBar(
      //   '📍 ${route.shortestRoute.distanceKm.toStringAsFixed(1)} km • '
      //   '⏱️ ${route.shortestRoute.durationMin.toStringAsFixed(0)} phút'
      //   '${altCount > 0 ? ' • $altCount tuyến khác' : ''}',
      // );
    } catch (e) {
      setState(() {
        _isLoadingRoute = false;
      });
      _showSnackBar('Lỗi tìm đường: $e');
    }
  }

  void _fitRouteBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(
        padding: EdgeInsets.all(60),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _routeResult = null;
      _destination = null;
      _searchResults = [];
      _showSearchResults = false;
      _searchController.clear();
      _isRerouting = false;
    });

    if (currentLocation != null) {
      _mapController.move(currentLocation!, 16);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 240, left: 16, right: 16),
      ),
    );
  }

  // =============================================
  // BOTTOM SHEET THÔNG TIN TRẠM
  // =============================================

  void _showStationBottomSheet(Station station) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_bike,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                station.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (station.address.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        station.address,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: StreamBuilder<List<Bike>>(
                  stream: BikeService().getBikesByStationStream(station.id),
                  builder: (context, bikeSnap) {
                    final allBikes = bikeSnap.data ?? [];
                    final availableBikes = allBikes.where((b) => b.status == 'available').length;
                    final inUseBikes = allBikes.where((b) => b.status == 'in_use').length;
                    final emptySlots = station.capacity - availableBikes;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoItem(
                          icon: Icons.pedal_bike,
                          value: '$availableBikes',
                          label: 'Xe có sẵn',
                          color: const Color(0xFF4CAF50),
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[300]),
                        _buildInfoItem(
                          icon: Icons.directions_bike,
                          value: '$inUseBikes',
                          label: 'Đang mượn',
                          color: const Color(0xFFE91E63),
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[300]),
                        _buildInfoItem(
                          icon: Icons.local_parking,
                          value: '${emptySlots < 0 ? 0 : emptySlots}',
                          label: 'Chỗ trống',
                          color: const Color(0xFF2196F3),
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[300]),
                        _buildInfoItem(
                          icon: Icons.ev_station,
                          value: '${station.capacity}',
                          label: 'Sức chứa',
                          color: const Color(0xFFFF9800),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _getRoute(SearchResult(
                      displayName: station.name,
                      location: LatLng(station.latitude, station.longitude),
                    ));
                  },
                  icon: const Icon(Icons.directions, color: Colors.white),
                  label: const Text(
                    'Chỉ đường đến trạm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =============================================
  // BOTTOM SHEET DANH SÁCH TRẠM
  // =============================================

  void _showStationListBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Danh sách trạm xe đạp',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<List<Station>>(
                      stream: _stationService.getStationsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(child: Text('Đã xảy ra lỗi'));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final stations = snapshot.data ?? [];

                        if (stations.isEmpty) {
                          return const Center(child: Text('Không có dữ liệu trạm nào.'));
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: stations.length,
                          itemBuilder: (context, index) {
                            final station = stations[index];

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Material(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12.0),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12.0),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _mapController.move(
                                      LatLng(station.latitude, station.longitude),
                                      16.0,
                                    );
                                    _showStationBottomSheet(station);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${station.stationId} - ${station.name}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16.0,
                                                ),
                                              ),
                                              const SizedBox(height: 6.0),
                                              Text(
                                                station.address.isNotEmpty ? station.address : 'Chưa cập nhật địa chỉ',
                                                style: const TextStyle(
                                                  fontSize: 14.0,
                                                  color: Colors.black54,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16.0),
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.redAccent,
                                          size: 32.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    if (_routeResult == null) return [];

    final polylines = <Polyline>[];

    for (final route in _routeResult!.allRoutes) {
      if (!route.isShortest) {
        polylines.add(Polyline(
          points: route.points,
          strokeWidth: 6,
          color: const Color(0xFF6B9CE8),
        ));
        polylines.add(Polyline(
          points: route.points,
          strokeWidth: 4,
          color: const Color(0xFF8AB4F8),
        ));
      }
    }

    polylines.add(Polyline(
      points: _routeResult!.shortestRoute.points,
      strokeWidth: 8,
      color: const Color(0xFF1967D2),
    ));
    polylines.add(Polyline(
      points: _routeResult!.shortestRoute.points,
      strokeWidth: 5,
      color: const Color(0xFF4285F4),
    ));

    if (_destination != null && _routeResult!.shortestRoute.points.isNotEmpty) {
      final lastRoutePoint = _routeResult!.shortestRoute.points.last;
      const distance = Distance();
      if (distance.as(LengthUnit.Meter, lastRoutePoint, _destination!) > 5) {
        polylines.add(Polyline(
          points: [lastRoutePoint, _destination!],
          strokeWidth: 4,
          color: const Color(0xFF8AB4F8),
          isDotted: true,
        ));
      }
    }

    return polylines;
  }

  // =============================================
  // RETURN BIKE LOGIC
  // =============================================

  Future<void> _checkAndReturnBike(BuildContext context) async {
    if (currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa xác định được vị trí của bạn!')),
      );
      return;
    }

    // Hiện Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      final stations = await _stationService.getAllStations();
      if (!mounted) return;
      Navigator.pop(context); // Tắt loading

      if (stations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hệ thống hiện không có trạm nào!')),
        );
        return;
      }

      const distanceCalc = Distance();
      Station? nearestStation;
      double minDistance = double.infinity;

      for (final station in stations) {
        final dist = distanceCalc.as(
          LengthUnit.Meter,
          currentLocation!,
          LatLng(station.latitude, station.longitude),
        );
        if (dist < minDistance) {
          minDistance = dist;
          nearestStation = station;
        }
      }

      if (nearestStation != null && minDistance <= 20) {
        // Trong phạm vi 20m -> Cho phép trả xe
        _showReturnBikeDialog(context, nearestStation);
      } else if (nearestStation != null) {
        // Ngoài phạm vi 20m -> Hiển thị cảnh báo
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('Ngoài phạm vi', style: TextStyle(color: Colors.red)),
              ],
            ),
            content: Text(
              'Bạn phải trả xe trong phạm vi 20 mét của một trạm SmartBike.\n\n'
              'Trạm gần nhất là "${nearestStation!.name}", cách bạn khoảng ${minDistance.toStringAsFixed(0)} mét.\n\n'
              'Vui lòng di chuyển đến trạm để kết thúc chuyến đi.',
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Tắt popup
                  // Tìm đường đến trạm đó
                  _getRoute(SearchResult(
                    displayName: nearestStation!.name,
                    location: LatLng(nearestStation.latitude, nearestStation.longitude),
                  ));
                },
                icon: const Icon(Icons.directions, color: Colors.white, size: 18),
                label: const Text('Chỉ đường', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Tắt loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kiểm tra trạm: $e')),
      );
    }
  }

  void _showReturnBikeDialog(BuildContext context, Station nearestStation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận trả xe?'),
        content: const Text('Hệ thống sẽ kết thúc chuyến đi và tự động thanh toán từ ví của bạn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              String finalTimeStr = _formatTime(_secondsElapsed);
              int finalCost = _calculateCost();
              String userId = FirebaseAuth.instance.currentUser?.uid ?? "";

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)),
              );

              try {
                String tripId = FirebaseFirestore.instance.collection('trips').doc().id;

                DateTime end = DateTime.now();
                DateTime start = end.subtract(Duration(seconds: _secondsElapsed));

                await FirebaseFirestore.instance.collection('trips').doc(tripId).set({
                  'tripId': tripId,
                  'userId': userId,
                  'bikeId': widget.bikeId,
                  'duration': (_secondsElapsed / 60).ceil(),
                  'cost': finalCost,
                  'startLocation': widget.startStationName,
                  'endLocation': nearestStation.name,
                  'startTime': Timestamp.fromDate(start),
                  'endTime': Timestamp.fromDate(end),
                  'status': 'Completed',
                });

                await FirebaseFirestore.instance.collection('transactions').add({
                  'userId': userId,
                  'amount': finalCost,
                  'type': 'trip_payment',
                  'relatedTripId': tripId,
                  'method': _isMonthlyTicket ? 'Vé tháng' : 'Ví SmartBike',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (finalCost > 0) {
                  await FirebaseFirestore.instance.collection('users').doc(userId).update({
                    'balance': FieldValue.increment(-finalCost),
                  });
                }

                // Cập nhật trạng thái xe: Sẵn sàng và ở trạm mới
                final bikeQuery = await FirebaseFirestore.instance
                    .collection('bikes')
                    .where('bikeId', isEqualTo: widget.bikeId)
                    .limit(1)
                    .get();
                
                if (bikeQuery.docs.isNotEmpty) {
                  await bikeQuery.docs.first.reference.update({
                    'status': 'available',
                    'stationId': nearestStation.id,
                    'currentUserId': null,
                    'unlockTime': null,
                  });
                }

                if (!mounted) return;
                Navigator.pop(context); // Tắt loading
                Navigator.pop(context); // Đóng popup xác nhận

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoiceScreen(
                      bikeId: widget.bikeId,
                      duration: finalTimeStr,
                      totalCost: finalCost,
                    ),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Lỗi hệ thống: $e"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Xác nhận Trả', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // =============================================
  // BUILD UI
  // =============================================

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                    _initLocationTracking();
                  },
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (currentLocation == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang thiết lập chuyến đi...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. LỚP BẢN ĐỒ VÀ TRẠM XE
          StreamBuilder<List<Station>>(
            stream: _stationService.getStationsStream(),
            builder: (context, stationSnapshot) {
              final stations = stationSnapshot.data ?? [];

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center: currentLocation!,
                  zoom: 16,
                  minZoom: 3,
                  maxZoom: 19,
                  interactiveFlags: InteractiveFlag.all,
                  onTap: (_, __) {
                    setState(() {
                      _showSearchResults = false;
                    });
                    FocusScope.of(context).unfocus();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.smartbike',
                    maxNativeZoom: 19,
                    maxZoom: 19,
                    keepBuffer: 4,
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://openstreetmap.org/copyright'),
                        ),
                      ),
                    ],
                  ),

                  // ĐƯỜNG ĐI
                  if (_routeResult != null)
                    PolylineLayer(polylines: _buildPolylines()),

                  // MARKERS
                  MarkerLayer(
                    markers: [
                      // Vị trí hiện tại
                      Marker(
                        point: currentLocation!,
                        width: 60,
                        height: 60,
                        child: LocationIndicator(
                          heading: _heading,
                          size: 60,
                        ),
                      ),
                      // Marker điểm đích
                      if (_destination != null)
                        Marker(
                          point: _destination!,
                          width: 56,
                          height: 56,
                          child: Transform.translate(
                            offset: const Offset(0, -24),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 48,
                            ),
                          ),
                        ),
                      // Marker các trạm
                      ...stations.map((station) => Marker(
                        point: LatLng(station.latitude, station.longitude),
                        width: 48,
                        height: 48,
                        child: StationMarkerIcon(
                          size: 44,
                          onTap: () => _showStationBottomSheet(station),
                        ),
                      )),
                    ],
                  ),
                ],
              );
            },
          ),

          // 2. THANH TÌM KIẾM
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.grey),
                        onPressed: () {
                          if (_routeResult != null || _searchController.text.isNotEmpty) {
                            _clearRoute();
                          }
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Tìm địa điểm, trạm trả xe...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onSubmitted: _searchAddress,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty || _routeResult != null)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: _clearRoute,
                        ),
                      IconButton(
                        icon: const Icon(Icons.directions_bike, color: Color(0xFF4285F4)),
                        onPressed: () => _searchAddress(_searchController.text),
                      ),
                    ],
                  ),
                ),

                // Kết quả tìm kiếm
                if (_showSearchResults)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : _searchResults.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Không tìm thấy kết quả',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final result = _searchResults[index];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.place,
                                      color: Color(0xFFEA4335),
                                    ),
                                    title: Text(
                                      result.displayName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    onTap: () => _getRoute(result),
                                    dense: true,
                                  );
                                },
                              ),
                  ),
              ],
            ),
          ),

          // 3. LOADING ROUTE
          if (_isLoadingRoute)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Đang tìm đường...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. THÔNG TIN ĐƯỜNG ĐI
          if (_routeResult != null)
            Positioned(
              bottom: 230, 
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bike, color: Color(0xFF4285F4), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_routeResult!.shortestRoute.distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          Text(
                            'Khoảng ${_routeResult!.shortestRoute.durationMin.toStringAsFixed(0)} phút đạp xe',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isRerouting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: _clearRoute,
                    ),
                  ],
                ),
              ),
            ),

          // 5. THÔNG TIN CHUYẾN ĐI (BOTTOM PANEL)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 5),
                            duration: const Duration(milliseconds: 500),
                            builder: (context, double value, child) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: value),
                                child: Icon(Icons.pedal_bike, size: 28, color: Colors.green[600]),
                              );
                            },
                            onEnd: () => setState(() {}),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Mã xe: ${widget.bikeId}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      if (_isMonthlyTicket)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.blue, size: 14),
                              SizedBox(width: 4),
                              Text("Vé Tháng", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text('THỜI GIAN', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(_secondsElapsed),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87, fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      Column(
                        children: [
                          const Text('TẠM TÍNH', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${_calculateCost()}',
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                              ),
                              const SizedBox(width: 4),
                              const Text('VNĐ', style: TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => _checkAndReturnBike(context),
                      child: const Text('KẾT THÚC CHUYẾN ĐI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. NÚT MỞ DANH SÁCH TRẠM
          Positioned(
            bottom: _routeResult != null ? 310 : 250,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'active_trip_station_list_fab',
              onPressed: _showStationListBottomSheet,
              backgroundColor: Colors.white,
              child: const Icon(Icons.list, color: Color(0xFF1A1A2E)),
            ),
          ),
        ],
      ),
    );
  }
}