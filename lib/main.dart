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
