import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Lấy ID người dùng thực tế từ Firebase Auth
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("SMART BIKE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2ECC71),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- PHẦN 1: HEADER USER (Như ảnh Nhung gửi) ---
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF2ECC71),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              padding: const EdgeInsets.only(bottom: 40),
              child: const Column(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 70, color: Color(0xFF2ECC71)),
                  ),
                  SizedBox(height: 15),
                  Text("pham thi thu", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  Text("Hạng: Thành viên Kim cương", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            // --- PHẦN 2: THẺ VÍ & ĐIỂM THƯỞNG ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SỐ DƯ VÍ", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                              builder: (context, snapshot) {
                                String balance = "0";
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  balance = snapshot.data!['balance']?.toString() ?? "0";
                                }
                                return Text("$balanceđ", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF34495E)));
                              },
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            Text("ĐIỂM THƯỞNG", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(height: 5),
                            Text("2180 pts", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ],
                        )
                      ],
                    ),
                    const Divider(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {}, 
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text("NẠP TIỀN VÀO VÍ", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),

            // --- PHẦN 3: GÓI SỬ DỤNG TIẾT KIỆM ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("GÓI SỬ DỤNG TIẾT KIỆM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 15),

                  // THẺ VÉ LƯỢT (CHỈ HIỆN THÔNG TIN)
                  _buildPackageCard(
                    icon: Icons.confirmation_number_outlined,
                    title: "Vé Lượt Standard",
                    sub: "60p đầu",
                    price: "10.000đ",
                    btnColor: Colors.orange,
                    onTap: () => _showTripPriceInfo(context),
                  ),

                  const SizedBox(height: 15),

                  // THẺ VÉ THÁNG (CÓ CHECK TRẠNG THÁI ĐÃ MUA)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                    builder: (context, snapshot) {
                      bool hasTicket = false;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        hasTicket = snapshot.data!['isMonthlyTicket'] ?? false;
                      }
                      return _buildPackageCard(
                        icon: Icons.calendar_today_outlined,
                        title: "Vé Tháng SmartStep",
                        sub: "Dùng 30 ngày",
                        price: hasTicket ? "ĐANG DÙNG" : "79.000đ",
                        btnColor: hasTicket ? Colors.grey : const Color(0xFF2ECC71),
                        onTap: () {
                          if (hasTicket) {
                            _showSnackBar(context, "Bạn đang trong thời gian sử dụng vé tháng!", Colors.blue);
                          } else {
                            _handleBuyMembership(context, userId);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            // Nút Quét mã demo ở giữa như ảnh
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.qr_code_scanner, color: Colors.white),
                  SizedBox(width: 10),
                  Text("QUÉT ĐỂ THUÊ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // --- HÀM 1: XỬ LÝ MUA VÉ THÁNG (TRỪ TIỀN + GHI LỊCH SỬ) ---
  void _handleBuyMembership(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Xác nhận đăng ký?"),
        content: const Text("79.000đ sẽ được trừ từ ví Smart Bike của bạn."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              try {
                // A. Ghi vào transactions để Tab Ví hiện lịch sử
                await FirebaseFirestore.instance.collection('transactions').add({
                  'userId': userId,
                  'amount': 79000,
                  'type': 'membership_buy',
                  'timestamp': FieldValue.serverTimestamp(),
                  'method': 'Ví SmartBike',
                });
                // B. Cập nhật bảng Users
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'balance': FieldValue.increment(-79000),
                  'isMonthlyTicket': true,
                });
                _showSnackBar(context, "Đăng ký thành công!", Colors.green);
              } catch (e) { print(e); }
            },
            child: const Text("Đồng ý", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- HÀM 2: HIỆN THÔNG TIN VÉ LƯỢT (KHÔNG TRỪ TIỀN) ---
  void _showTripPriceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Thông tin vé lượt"),
        content: const Text("Gói Standard (10.000đ) sẽ được tính tự động khi bạn bắt đầu hành trình thuê xe.\nBạn không cần đăng ký trước gói này."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đã hiểu")),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // --- WIDGET VẼ CÁC THẺ GÓI CƯỚC ---
  Widget _buildPackageCard({required IconData icon, required String title, required String sub, required String price, required Color btnColor, required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: Colors.orange, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}