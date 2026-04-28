import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';

// Import các file màn hình trong dự án của bạn
import 'firebase_options.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/user/user_main_screen.dart';
import 'screens/user/active_trip_screen.dart';

void main() async {
  // 1. Đảm bảo các thành phần của Flutter được khởi tạo xong
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Kết nối với Firebase bằng cấu hình tự động
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Lỗi khởi tạo Firebase: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartBike App',
      // ĐIỂM BẮT ĐẦU: Màn hình chào mừng (Welcome)
      home: const WelcomeScreen(), 
    );
  }
}

// --- MÀN HÌNH BẢN ĐỒ CHI TIẾT (Dùng nhúng vào Tab Tìm Xe) ---
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  // Hàm lấy vị trí hiện tại của người dùng
  Future<void> _loadCurrentLocation() async {
    try {
      Position position = await _getCurrentPosition();
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint("Lỗi lấy vị trí: $e");
      // CỨU CÁNH: Nếu lỗi GPS, hiển thị mặc định tại ĐH Thủy Lợi (Hà Nội)
      setState(() {
        currentLocation = const LatLng(21.028511, 105.804817); 
      });
    }
  }

  // Logic xin quyền truy cập GPS
  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('GPS chưa bật');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Bạn đã từ chối quyền GPS');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Bạn đã từ chối GPS vĩnh viễn');
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: currentLocation!, 
                initialZoom: 16, 
                minZoom: 3,
                maxZoom: 25,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all, 
                ),
                // Bắt tọa độ khi click vào bản đồ để thêm trạm (Dành cho Admin/NCKH)
                onTap: (tapPosition, point) {
                  _showAddStationDialog(context, point);
                },
              ),
              children: [
                // Lớp bản đồ nền từ OpenStreetMap
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.smartbike',
                  maxNativeZoom: 19,  
                  maxZoom: 25,        
                ),
                // Lớp hiển thị vị trí người dùng/xe đạp
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vị trí của bạn hiện tại!')),
                          );
                        },
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // Hàm hiển thị Popup khi click vào bản đồ
  void _showAddStationDialog(BuildContext context, LatLng point) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Xác nhận thuê xe'),
          content: Text('Bạn muốn tìm xe gần tọa độ này?\n'
              'Vĩ độ: ${point.latitude.toStringAsFixed(4)}\n'
              'Kinh độ: ${point.longitude.toStringAsFixed(4)}'),
          actions: [
            TextButton(
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
              onPressed: () {
                Navigator.pop(context); 
                // Chuyển sang màn hình hành trình
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActiveTripScreen(bikeId: 'BIKE-NCKH'),
                  ),
                );
              },
              child: const Text('THUÊ XE', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}