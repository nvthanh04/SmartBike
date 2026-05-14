import 'package:flutter/material.dart';
// Nhớ import trang chủ của bạn vào đây, ví dụ:
import 'user_main_screen.dart'; 

class InvoiceScreen extends StatelessWidget {
  final String bikeId;
  final String duration;
  final int totalCost;

  const InvoiceScreen({
    super.key,
    required this.bikeId,
    required this.duration,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // Dùng return để không cho quay lại màn hình đang đi xe (vì đã trả xe rồi)
      appBar: AppBar(
        title: const Text('Hóa đơn chuyến đi'), 
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false, // Ẩn nút quay lại ở AppBar
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text('Cảm ơn bạn đã sử dụng dịch vụ!', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), 
                textAlign: TextAlign.center
              ),
              const Divider(height: 40),
              _buildRow('Mã xe:', bikeId),
              _buildRow('Thời gian di chuyển:', duration),
              _buildRow('Đơn giá:', '10.000 VNĐ /60 phút'), // xem sửa chỗ này như nào để báo đang sử dụng gói dịch vụ gì
              const Divider(height: 40),
              _buildRow('TỔNG CỘNG:', '$totalCost VNĐ', isBold: true),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () {
                    // Lệnh này cực kỳ quan trọng: Xóa hết các màn hình cũ (Đang đi xe, Popup...)
                    // Đưa Nhung thẳng về Trang chủ mà không bị logout.
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const UserMainScreen()),
                      (route) => false, 
                    );
                  },
                  child: const Text('QUAY VỀ TRANG CHỦ', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(value, style: TextStyle(
            fontSize: 15, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal, 
            color: isBold ? Colors.red : Colors.black
          )),
        ],
      ),
    );
  }
}