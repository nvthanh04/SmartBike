import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../user/user_main_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import 'register_screen.dart'; // Quên chưa có file này thì tạo sau nhé

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final Color primaryGreen = const Color(0xFF2ECC71);

  // HÀM XỬ LÝ ĐĂNG NHẬP THẬT VỚI FIREBASE
  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Vui lòng nhập đầy đủ Email và Mật khẩu");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Gọi lệnh đăng nhập của Firebase
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Kiểm tra role từ Firestore collection 'users'
      if (mounted && userCredential.user != null) {
        final uid = userCredential.user!.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        final role = userDoc.data()?['role'] ?? 'user';

        if (mounted) {
          if (role == 'admin') {
            // Admin → vào Admin Dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
            );
          } else {
            // User thường → vào màn hình User
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserMainScreen()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError("Tài khoản hoặc mật khẩu không chính xác!");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header trang trí hình cong màu xanh
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryGreen, const Color(0xFF27AE60)]),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(100)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bike, size: 90, color: Colors.white),
                  SizedBox(height: 10),
                  Text("SMART BIKE", 
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text("Di chuyển xanh - Tương lai sạch", 
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Chào mừng trở lại!", 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                  const SizedBox(height: 30),
                  
                  // Ô nhập Email
                  _buildTextField(_emailController, "Email sinh viên", Icons.email_outlined, false),
                  const SizedBox(height: 20),
                  
                  // Ô nhập Mật khẩu
                  _buildTextField(_passwordController, "Mật khẩu", Icons.lock_outline, true),
                  
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () {}, child: const Text("Quên mật khẩu?")),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // NÚT ĐĂNG NHẬP
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("ĐĂNG NHẬP", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  
                  // NÚT DẪN SANG ĐĂNG KÝ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Bạn chưa có tài khoản? "),
                      GestureDetector(
                        onTap: () {
                          // Chuyển sang màn hình Đăng ký (RegisterScreen)
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                        },
                        child: Text("Đăng ký ngay", 
                          style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget dùng chung cho các ô nhập liệu
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryGreen),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primaryGreen, width: 2),
        ),
      ),
    );
  }
}