import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF2ECC71);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            // 1. Hình ảnh minh họa (Dùng Icon xe đạp lớn)
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.directions_bike_rounded, size: 150, color: primaryGreen),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // 2. Nội dung giới thiệu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  Text(
                    "Smart Bike",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryGreen),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Hệ thống cho thuê xe đạp điện thông minh. Giúp bạn di chuyển nhanh chóng, tiết kiệm và bảo vệ môi trường học đường.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 3. Hai nút bấm Đăng ký & Đăng nhập
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              child: Column(
                children: [
                  // Nút Đăng nhập
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                      },
                      child: const Text("ĐĂNG NHẬP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Nút Đăng ký (Viền xanh)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryGreen, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                      },
                      child: Text("ĐĂNG KÝ TÀI KHOẢN", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}