import 'dart:async';
import 'package:flutter/material.dart';
import 'invoice_screen.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActiveTripScreen extends StatefulWidget {
  final String bikeId; 
  
  const ActiveTripScreen({super.key, required this.bikeId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  int _secondsElapsed = 0; 
  Timer? _timer;
  bool _isMonthlyTicket = false; 

  @override
  void initState() {
    super.initState();
    _checkUserStatus(); 
    _startTimer();
  }

  // 1. Kiểm tra trạng thái vé tháng của người dùng
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 2. Logic tính tiền chuẩn: 10k giờ đầu, 3k/10p sau
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ĐANG DI CHUYỂN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.green[600],
        automaticallyImplyLeading: false, 
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon xe đạp chuyển động nhẹ (UI Decor)
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 10),
              duration: const Duration(seconds: 1),
              builder: (context, double value, child) {
                return Padding(
                  padding: EdgeInsets.only(bottom: value),
                  child: Icon(Icons.directions_bike, size: 120, color: Colors.green[600]),
                );
              },
              onEnd: () => setState(() {}), // Tạo hiệu ứng nhún nhảy
            ),
            
            const SizedBox(height: 10),
            Text('Mã xe: ${widget.bikeId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black54)),
            
            if (_isMonthlyTicket)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified, color: Colors.blue, size: 16),
                    SizedBox(width: 5),
                    Text("Ưu đãi Vé Tháng", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            const SizedBox(height: 40),
            const Text('THỜI GIAN ĐÃ ĐI', style: TextStyle(fontSize: 14, letterSpacing: 1.2, color: Colors.grey)),
            const SizedBox(height: 5),
            Text(
              _formatTime(_secondsElapsed),
              style: const TextStyle(fontSize: 70, fontWeight: FontWeight.bold, color: Colors.black87, fontFeatures: [FontFeature.tabularFigures()]),
            ),

            const SizedBox(height: 30),
            const Text('TẠM TÍNH', style: TextStyle(fontSize: 14, letterSpacing: 1.2, color: Colors.grey)),
            Text(
              '${_calculateCost()} VNĐ',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange[800]),
            ),

            const SizedBox(height: 80),
            
            // Nút trả xe thiết kế bo tròn xịn xò
            GestureDetector(
              onTap: () => _showReturnBikeDialog(context),
              child: Container(
                width: 240,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade700]),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                  ],
                ),
                child: const Center(
                  child: Text('KẾT THÚC CHUYẾN ĐI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Popup Xử lý Trả xe & Liên kết Database
  void _showReturnBikeDialog(BuildContext context) {
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

              // Hiện Loading chặn màn hình
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)),
              );

              try {
                // A. TẠO ID DUY NHẤT ĐỂ LIÊN KẾT GIỮA TRIP VÀ TRANSACTION
                String tripId = FirebaseFirestore.instance.collection('trips').doc().id;

                // B. LƯU VÀO COLLECTION 'trips'
                await FirebaseFirestore.instance.collection('trips').doc(tripId).set({
                  'tripId': tripId,
                  'userId': userId,
                  'bikeId': widget.bikeId,
                  'duration': (_secondsElapsed / 60).ceil(),
                  'cost': finalCost,
                  'endLocation': 'ĐH Thủy Lợi',
                  'startTime': FieldValue.serverTimestamp(),
                  'status': 'Completed',
                });

                // C. LƯU VÀO COLLECTION 'transactions' (Gắn tripId vào đây)
                await FirebaseFirestore.instance.collection('transactions').add({
                  'userId': userId,
                  'amount': finalCost,
                  'type': 'trip_payment',
                  'relatedTripId': tripId, // <--- ĐÂY LÀ SỢI DÂY LIÊN KẾT
                  'method': _isMonthlyTicket ? 'Vé tháng' : 'Ví SmartBike',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                // D. CẬP NHẬT TRỪ TIỀN TRONG VÍ (Vì balance là Double/Number)
                if (finalCost > 0) {
                  await FirebaseFirestore.instance.collection('users').doc(userId).update({
                    'balance': FieldValue.increment(-finalCost),
                  });
                }

                if (!mounted) return;
                Navigator.pop(context); // Tắt loading
                Navigator.pop(context); // Đóng popup xác nhận

                // 4. Chuyển sang màn hình hóa đơn
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
}