import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/station_model.dart';
import '../models/bike_model.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/station_service.dart';
import '../services/bike_service.dart';
import '../widgets/location_indicator.dart';
import '../widgets/station_marker_icon.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // === Vị trí ===
  LatLng? currentLocation;
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
    _initLocationTracking();
  }

  @override
  void dispose() {
    _locationService.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // =============================================
  // LOCATION TRACKING
  // =============================================

  Future<void> _initLocationTracking() async {
    try {
      await _locationService.checkPermission();

      // 1. Sử dụng vị trí lưu trữ gần nhất để load bản đồ ngay lập tức
      final lastKnown = await _locationService.getLastKnownLocation();
      if (lastKnown != null) {
        if (mounted) {
          setState(() {
            currentLocation = lastKnown.position;
            _heading = lastKnown.heading;
          });
        }
      } else {
        // 2. Nếu không có (ví dụ trên Web), thử lấy vị trí bằng mạng/IP (rất nhanh)
        final fastLocation = await _locationService.getFastLocation();
        if (fastLocation != null) {
          if (mounted) {
            setState(() {
              currentLocation = fastLocation.position;
              _heading = fastLocation.heading;
            });
          }
        } else {
          // 3. Fallback tạm thời ở trung tâm Hà Nội để không bị kẹt ở màn hình loading
          if (mounted) {
            setState(() {
              currentLocation = const LatLng(21.028511, 105.804817);
            });
          }
        }
      }

      // Lắng nghe GPS liên tục để cập nhật vị trí chính xác nhất (có thể mất thời gian để bắt được tín hiệu)
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
          if (mounted) {
            setState(() {
              _errorMessage = error.toString();
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  // =============================================
  // KIỂM TRA ĐI LỆCH ĐƯỜNG + TỰ ĐỘNG TÌM LẠI
  // =============================================

  /// Kiểm tra nếu người dùng đi lệch đường → tự động tìm đường lại
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

  /// Tìm đường lại từ vị trí hiện tại đến đích
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
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
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
              // Thanh kéo
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icon trạm
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
              // Tên trạm
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
              // Địa chỉ
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
              // Thông tin xe
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
              // Nút chỉ đường
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Tìm đường đến trạm
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

  // =============================================
  // BUILD POLYLINES (đường xanh đậm + xanh nhạt)
  // =============================================

  List<Polyline> _buildPolylines() {
    if (_routeResult == null) return [];

    final polylines = <Polyline>[];

    // 1. Vẽ các tuyến PHỤ (xanh nhạt)
    for (final route in _routeResult!.allRoutes) {
      if (!route.isShortest) {
        // Viền tuyến phụ (tùy chọn, để đậm hơn chút)
        polylines.add(Polyline(
          points: route.points,
          strokeWidth: 6,
          color: const Color(0xFF6B9CE8), // Xanh viền nhạt
        ));
        // Lõi tuyến phụ
        polylines.add(Polyline(
          points: route.points,
          strokeWidth: 4,
          color: const Color(0xFF8AB4F8), // Xanh nhạt sáng
        ));
      }
    }

    // 2. Vẽ tuyến CHÍNH (xanh đậm có viền)
    // - Lớp viền ở dưới (rộng hơn)
    polylines.add(Polyline(
      points: _routeResult!.shortestRoute.points,
      strokeWidth: 8,
      color: const Color(0xFF1967D2), // Viền xanh đậm chìm
    ));
    // - Lớp lõi ở trên
    polylines.add(Polyline(
      points: _routeResult!.shortestRoute.points,
      strokeWidth: 5,
      color: const Color(0xFF4285F4), // Lõi màu Google Blue
    ));

    // 3. Vẽ đoạn nối nét đứt vào tận ngõ/nhà
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
                  // Thanh kéo
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
                                        Icon(
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
              Text('Đang lấy vị trí...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // === BẢN ĐỒ VỚI STREAMBUILDER TRẠM XE ===
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

                  // === TẤT CẢ TUYẾN ĐƯỜNG ===
                  if (_routeResult != null)
                    PolylineLayer(polylines: _buildPolylines()),

                  // === MARKERS ===
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
                      // === MARKERS CÁC TRẠM XE ĐẠP ===
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

          // === THANH TÌM KIẾM ===
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
                      const SizedBox(width: 14),
                      const Icon(Icons.search, color: Color(0xFF4285F4)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Tìm kiếm địa điểm...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onSubmitted: _searchAddress,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty ||
                          _routeResult != null)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: _clearRoute,
                        ),
                      IconButton(
                        icon: const Icon(Icons.directions_bike,
                            color: Color(0xFF4285F4)),
                        onPressed: () =>
                            _searchAddress(_searchController.text),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
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

          // === LOADING ROUTE ===
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

          // === THÔNG TIN ĐƯỜNG ĐI ===
          if (_routeResult != null)
            Positioned(
              bottom: 20,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
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
                    const Icon(Icons.directions_bike,
                        color: Color(0xFF4285F4), size: 28),
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
          
          // === NÚT DANH SÁCH TRẠM ===
          Positioned(
            bottom: 120, // Đặt cao hơn bottom một chút để không đè lên nút QUÉT ĐỂ THUÊ và nút attribution (i)
            right: 16,
            child: FloatingActionButton(
              heroTag: 'station_list_fab', // Cần heroTag vì có thể ở ngoài màn hình chính cũng có FAB
              onPressed: _showStationListBottomSheet,
              backgroundColor: const Color(0xFF4285F4),
              child: const Icon(Icons.list, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
