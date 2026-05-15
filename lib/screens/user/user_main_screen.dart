import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'active_trip_screen.dart';
import '../../services/payment_service.dart';
import '../map_screen.dart';
import 'package:intl/intl.dart'; 
import 'qr_scanner_screen.dart';
import '../auth/login_screen.dart';
import '../../providers/chatbot_provider.dart';
import '../../widgets/chat_bubble_widget.dart';
class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _selectedIndex = 0;
  final Color primaryGreen = const Color(0xFF2ECC71);
  final ChatbotProvider _chatbotProvider = ChatbotProvider();

  List<Widget> _buildPages() {
    return [
      const MapScreen(),      
      _buildHistoryTab(),    
      _buildProfileTab(),    
    ];
  }

  // --- TAB TÀI KHOẢN (VÍ TIỀN & ƯU ĐÃI) ---
  Widget _buildProfileTab() {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "user_test";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Header Profile - CẬP NHẬT LẤY TÊN THẬT
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2ECC71), Color(0xFF27AE60)]),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: Column(
                children: [
                  const CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Icon(Icons.person, size: 45, color: Color(0xFF2ECC71))),
                  const SizedBox(height: 12),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                    builder: (context, snapshot) {
                      String name = "SmartBike User";
                      String tierName = "Thành viên Cơ bản";
                      Color tierColor = Colors.white70;
                      int points = 0;

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        name = data['name'] ?? "SmartBike User";
                        points = data['points'] ?? 0;
                        
                        if (points >= 10000) {
                          tierName = "Thành viên Kim cương";
                          tierColor = const Color(0xFF00E5FF); // Cyan
                        } else if (points >= 5000) {
                          tierName = "Thành viên Vàng";
                          tierColor = const Color(0xFFFFD700); // Gold
                        } else if (points >= 1000) {
                          tierName = "Thành viên Bạc";
                          tierColor = const Color(0xFFE0E0E0); // Silver
                        }
                      }
                      
                      return Column(
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _showMembershipBenefitsDialog(points, tierName, tierColor),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Hạng: $tierName", style: TextStyle(color: tierColor, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.info_outline, color: tierColor, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // 2. THẺ VÍ TIỀN & ĐIỂM THƯỞNG
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SỐ DƯ VÍ", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                              builder: (context, snapshot) {
                                String balance = snapshot.hasData && snapshot.data!.exists ? snapshot.data!['balance'].toString() : "0";
                                return Text("$balanceđ", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF2D3436)));
                              },
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("ĐIỂM THƯỞNG", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                              builder: (context, snapshot) {
                                String points = snapshot.hasData && snapshot.data!.exists ? (snapshot.data!['points'] ?? 0).toString() : "0";
                                return Text("$points pts", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFAD33)));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    ElevatedButton.icon(
                      onPressed: () => _showTopUpOptions(userId), 
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                      label: const Text("NẠP TIỀN VÀO VÍ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    )
                  ],
                ),
              ),
            ),

            _buildSubscriptionSection(userId),
            _buildRewardExchange(userId),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // --- CÁC HÀM BỔ TRỢ GIAO DIỆN & LOGIC ---

  double _getMembershipDiscount(int points) {
    if (points >= 10000) return 0.15; // Kim cương
    if (points >= 5000) return 0.10;  // Vàng
    if (points >= 1000) return 0.05;  // Bạc
    return 0.0;                       // Cơ bản
  }

  void _showMembershipBenefitsDialog(int points, String currentTierName, Color currentTierColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.star, color: currentTierColor, size: 28),
            const SizedBox(width: 8),
            const Text("Quyền lợi hạng", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hạng hiện tại: $currentTierName", style: TextStyle(fontWeight: FontWeight.bold, color: currentTierColor, fontSize: 16)),
            Text("Điểm tích lũy: $points pts", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            _buildBenefitRow("Cơ bản (< 1.000)", "Không giảm giá"),
            _buildBenefitRow("Bạc (1.000 - 4.999)", "Giảm 5% khi mua Vé Lượt/Tháng", isHighlight: points >= 1000 && points < 5000),
            _buildBenefitRow("Vàng (5.000 - 9.999)", "Giảm 10% khi mua Vé Lượt/Tháng", isHighlight: points >= 5000 && points < 10000),
            _buildBenefitRow("Kim cương (>= 10.000)", "Giảm 15% Vé\nHoàn tiền 5% chuyến đi lẻ", isHighlight: points >= 10000),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng", style: TextStyle(color: Colors.green))),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String tier, String benefit, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: isHighlight ? Colors.green : Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isHighlight ? Colors.black87 : Colors.grey[600])),
                Text(benefit, style: TextStyle(fontSize: 12, color: isHighlight ? Colors.black87 : Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTopUpOptions(String userId) {
    TextEditingController amountController = TextEditingController(text: "20000");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("NẠP TIỀN VÀO VÍ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Số tiền muốn nạp (VNĐ)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 10,
                children: [20000, 50000, 100000, 200000].map((amount) {
                  return ActionChip(
                    label: Text("${amount ~/ 1000}k"),
                    onPressed: () {
                      amountController.text = amount.toString();
                    },
                    backgroundColor: Colors.grey[100],
                  );
                }).toList(),
              ),
              const Divider(height: 30),
              ListTile(
                leading: const Icon(Icons.account_balance, color: Colors.blue),
                title: const Text("Ngân hàng (NAPAS)"),
                onTap: () {
                  int val = int.tryParse(amountController.text) ?? 0;
                  if (val > 0) {
                    Navigator.pop(context);
                    _handleTopUp(userId, val, "Ngân hàng");
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập số tiền hợp lệ")));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.wallet, color: Colors.pink),
                title: const Text("Ví MoMo"),
                onTap: () {
                  int val = int.tryParse(amountController.text) ?? 0;
                  if (val > 0) {
                    Navigator.pop(context);
                    _handleTopUp(userId, val, "MoMo");
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập số tiền hợp lệ")));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTopUp(String userId, int amount, String method) {
    final now = Timestamp.now();
    FirebaseFirestore.instance.collection('users').doc(userId).update({
      'balance': FieldValue.increment(amount),
    });
    // 📝 GHI LỊCH SỬ GIAO DỊCH
    FirebaseFirestore.instance.collection('transactions').add({
      'userId': userId,
      'type': 'topup',
      'amount': amount,
      'method': method,
      'timestamp': now,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Thành công: +${amount}đ từ $method")),
    );
  }

  void _handlePurchase(String userId, int price, String itemName) {
    FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Không tìm thấy tài khoản!"), backgroundColor: Colors.red),
        );
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      int currentBalance = data['balance'] ?? 0;
      
      // 🔴 KIỂM TRA VÉ THÁNG CÒN HẠN - CHẶN MUA CẢ VÉ THÁNG LẪN VÉ LƯỢT
      var membershipData = data['monthlyTicket'];
      if (membershipData != null && membershipData is Map) {
        final membership = Map<String, dynamic>.from(membershipData as Map);
        
        if (membership['expiryDate'] != null) {
          DateTime expiryDate = (membership['expiryDate'] as Timestamp).toDate();
          
          if (expiryDate.isAfter(DateTime.now())) {
            // ⚠️ ĐÃ CÓ VÉ THÁNG CÒN HẠN - HIỆN POPUP THÔNG BÁO
            _showActiveTicketDialog("Vé Tháng SmartStep", expiryDate);
            return; // 🛑 DỪNG - KHÔNG CHO MUA BẤT KỲ VÉ NÀO
          }
        }
      }

      // 2️⃣ KIỂM TRA SỐ DƯ
      if (currentBalance >= price) {
        int bonusPoints = (price / 100).floor();
        
        // 🟢 NẾU LÀ VÉ THÁNG - LƯU THÔNG TIN VÉ
        if (itemName.contains("Tháng")) {
          DateTime now = DateTime.now();
          DateTime expiry = now.add(const Duration(days: 30));
          
          doc.reference.update({
            'balance': FieldValue.increment(-price),
            'points': FieldValue.increment(bonusPoints),
            'monthlyTicket': {
              'name': itemName,
              'purchaseDate': Timestamp.fromDate(now),
              'expiryDate': Timestamp.fromDate(expiry),
              'price': price,
              'status': 'active',
            },
          });
          // 📝 GHI LỊCH SỬ GIAO DỊCH VÀO COLLECTION
          FirebaseFirestore.instance.collection('transactions').add({
            'userId': userId,
            'type': 'membership_buy',
            'amount': price,
            'itemName': itemName,
            'expiryDate': Timestamp.fromDate(expiry),
            'timestamp': Timestamp.fromDate(now),
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Đã mua $itemName! Có hiệu lực đến ${DateFormat('dd/MM/yyyy').format(expiry)}"),
              backgroundColor: primaryGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // 🟡 VÉ LƯỢT - HẾT HẠN CUỐI NGÀY HÔM ĐÓ
          DateTime now = DateTime.now();
          DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

          doc.reference.update({
            'balance': FieldValue.increment(-price),
            'points': FieldValue.increment(bonusPoints),
            'dailyTicket': {
              'name': itemName,
              'purchaseDate': Timestamp.fromDate(now),
              'expiryDate': Timestamp.fromDate(endOfDay),
              'price': price,
              'status': 'active',
            },
          });
          // 📝 GHI LỊCH SỬ GIAO DỊCH VÀO COLLECTION
          FirebaseFirestore.instance.collection('transactions').add({
            'userId': userId,
            'type': 'daily_ticket_buy',
            'amount': price,
            'itemName': itemName,
            'expiryDate': Timestamp.fromDate(endOfDay),
            'timestamp': Timestamp.fromDate(now),
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Đã mua $itemName! Hết hạn lúc 23:59 hôm nay. +$bonusPoints pts"),
              backgroundColor: primaryGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Số dư ví không đủ!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }).catchError((error) {
      print("❌ Lỗi _handlePurchase: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Có lỗi xảy ra: $error"),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  Widget _buildSubscriptionSection(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        int points = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          points = (snapshot.data!.data() as Map<String, dynamic>)['points'] ?? 0;
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("GÓI SỬ DỤNG TIẾT KIỆM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),
              _buildPackageItem(userId, "Vé Lượt Standard", "59.000đ", "Dùng trong ngày", Colors.orange, Icons.confirmation_number_outlined, 59000, points),
              const SizedBox(height: 12),
              _buildPackageItem(userId, "Vé Tháng SmartStep", "159.000đ", "Dùng 30 ngày", const Color(0xFF2ECC71), Icons.calendar_month_outlined, 159000, points),
            ],
          ),
        );
      }
    );
  }
  // --- HÀM THÔNG BÁO ĐÃ CÓ VÉ CÒN HẠN ---
  void _showActiveTicketDialog(String ticketName, DateTime expiryDate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.orange[50],
        title: const Icon(
          Icons.check_circle,
          color: Colors.orange,
          size: 50,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "BẠN ĐÃ CÓ VÉ SỬ DỤNG",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    "📅 $ticketName",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "⏰ Hết hạn: ${DateFormat('dd/MM/yyyy HH:mm').format(expiryDate)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Vui lòng chờ đến hết hạn vé để mua vé mới",
              style: TextStyle(
                fontSize: 13,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đóng", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardExchange(String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ĐỔI ĐIỂM NHẬN ƯU ĐÃI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          _buildVoucherItem(userId, "Voucher Giảm 50%", "5000 pts", "Áp dụng vé lượt", Colors.redAccent, Icons.card_giftcard),
          const SizedBox(height: 12),
          _buildVoucherItem(userId, "Tặng 10.000đ vào ví", "10000 pts", "Đổi điểm lấy tiền", Colors.blueAccent, Icons.monetization_on_outlined),
        ],
      ),
    );
  }

  Widget _buildPackageItem(String userId, String name, String price, String note, Color color, IconData icon, int originalPriceInt, int points) {
    double discount = _getMembershipDiscount(points);
    int finalPriceInt = (originalPriceInt * (1 - discount)).round();
    String finalPriceStr = finalPriceInt == originalPriceInt 
        ? price 
        : "${NumberFormat('#,###').format(finalPriceInt).replaceAll(',', '.')}đ";

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(note, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // 🆕 HIỆN POP-UP CHI TIẾT TRƯỚC, RỒI MỚI THANH TOÁN
              _showPackageDetailDialog(userId, name, finalPriceStr, finalPriceInt, originalPriceStr: discount > 0 ? price : null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (discount > 0)
                  Text(price, style: const TextStyle(color: Colors.white70, fontSize: 10, decoration: TextDecoration.lineThrough)),
                Text(finalPriceStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
  void _showPackageDetailDialog(String userId, String packageName, String priceStr, int priceInt, {String? originalPriceStr}) async {
    // 🔄 Hiện loading trong khi kiểm tra vé tháng
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading

      bool hasMonthlyTicket = false;
      DateTime? monthlyExpiry;
      bool hasDailyTicket = false;
      DateTime? dailyExpiry;

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Kiểm tra vé tháng
        var monthlyData = data['monthlyTicket'];
        if (monthlyData != null && monthlyData is Map && monthlyData['expiryDate'] != null) {
          monthlyExpiry = (monthlyData['expiryDate'] as Timestamp).toDate();
          if (monthlyExpiry.isAfter(DateTime.now())) hasMonthlyTicket = true;
        }

        // Kiểm tra vé lượt
        var dailyData = data['dailyTicket'];
        if (dailyData != null && dailyData is Map && dailyData['expiryDate'] != null) {
          dailyExpiry = (dailyData['expiryDate'] as Timestamp).toDate();
          if (dailyExpiry.isAfter(DateTime.now())) hasDailyTicket = true;
        }
      }

      bool isBuyingMonthly = packageName.contains("Tháng");
      bool isBuyingDaily = packageName.contains("Lượt");

      if (isBuyingMonthly && hasMonthlyTicket && monthlyExpiry != null) {
        _showActiveTicketDialog("Vé Tháng SmartStep", monthlyExpiry);
      } else if (isBuyingDaily && hasMonthlyTicket && monthlyExpiry != null) {
        _showActiveTicketDialog("Vé Tháng SmartStep", monthlyExpiry);
      } else if (isBuyingDaily && hasDailyTicket && dailyExpiry != null) {
        _showActiveTicketDialog("Vé Lượt Standard", dailyExpiry);
      } else {
        // 🟢 CHƯA CÓ VÉ HOẶC ĐÃ HẾT HẠN → HIỆN DIALOG CHI TIẾT CHO MUA
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Chi tiết gói sử dụng", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        packageName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (originalPriceStr != null)
                        Text(
                          originalPriceStr,
                          style: const TextStyle(
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                      Text(
                        priceStr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "📋 Quyền lợi:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                packageName.contains("Standard")
                    ? const Text("• Miễn phí 2 tiếng/chuyến\n• Không giới hạn số chuyến trong ngày\n• Hỗ trợ 24/7")
                    : const Text("• Miễn phí 5 tiếng/chuyến\n• Không giới hạn số chuyến\n• Sử dụng trong 30 ngày\n• Hỗ trợ ưu tiên"),
                const SizedBox(height: 16),
                Text(
                  "Hình thức: Trừ từ ví SmartBike",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Hủy"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handlePurchase(userId, priceInt, packageName); // ✅ GỌI THANH TOÁN
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Xác nhận mua", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading nếu lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi kiểm tra vé: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildVoucherItem(String userId, String title, String cost, String sub, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleExchangePoints(userId, cost, title),
            style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(cost, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _handleExchangePoints(String userId, String costStr, String voucherTitle) {
    int cost = int.parse(costStr.split(' ')[0]);
    bool isCashReward = voucherTitle.contains("10.000"); // Loại tặng tiền vào ví

    FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
      if (!doc.exists) return;

      int currentPoints = doc['points'] ?? 0;

      if (currentPoints < cost) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Không đủ điểm! Bạn có $currentPoints pts, cần $cost pts."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ✅ ĐỦ ĐIỂM → THỰC HIỆN ĐỔI
      Map<String, dynamic> updateData = {
        'points': FieldValue.increment(-cost),
      };

      if (isCashReward) {
        // 💰 TẶNG 10.000đ → CỘNG VÀO VÍ
        updateData['balance'] = FieldValue.increment(10000);
      }

      final now = Timestamp.now();
      doc.reference.update(updateData).then((_) {
        // 📝 GHI LỊCH SỬ GIAO DỊCH VÀO COLLECTION
        FirebaseFirestore.instance.collection('transactions').add({
          'userId': userId,
          'type': 'points_exchange',
          'amount': isCashReward ? 10000 : 0,
          'pointsUsed': cost,
          'voucherTitle': voucherTitle,
          'timestamp': now,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCashReward
                  ? "✅ Đổi thành công! +10.000đ đã vào ví của bạn."
                  : "✅ Đổi Voucher Giảm 50% thành công! Áp dụng cho vé lượt kế tiếp.",
            ),
            backgroundColor: primaryGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi đổi điểm: $e"), backgroundColor: Colors.red),
      );
    });
  }

  // --- TAB HOẠT ĐỘNG ---
  Widget _buildHistoryTab() {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "user_test";

    return DefaultTabController(
      length: 2, // 2 Tab: Chuyến đi và Giao dịch
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          toolbarHeight: 0, // Ẩn phần title để Tab sát lên trên cho đẹp
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryGreen,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "Chuyến đi"),
              Tab(text: "Giao dịch ví"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTripHistory(userId),        // Tab 1: Đổ data từ trips
            _buildTransactionHistory(userId), // Tab 2: Đổ data từ transactions
          ],
        ),
      ),
    );
  }
  // --- TAB 1: LỊCH SỬ CHUYẾN ĐI (LẤY TỪ FIRESTORE) ---
  Widget _buildTripHistory(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        
        var docs = snapshot.data!.docs.toList();
        if (docs.isEmpty) return _buildEmptyState(Icons.directions_bike_outlined, "Bạn chưa có chuyến đi nào", "Hãy quét mã QR để bắt đầu chuyến đi đầu tiên!");

        // ⏰ SẮP XẾP MỚI NHẤT LÊN ĐẦU
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['startTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (bData['startTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            final distance = data['distance'] != null ? "${data['distance']} km" : null;
            final duration = data['duration'] != null ? "${data['duration']} phút" : null;
            final sub2 = [distance, duration].where((e) => e != null).join(' • ');
            return _buildRichCard(
              title: "Chuyến đi #${data['bikeId'] ?? 'BIKE'}",
              time: data['startTime'] != null
                  ? DateFormat('HH:mm - dd/MM/yyyy').format((data['startTime'] as Timestamp).toDate())
                  : "Đang tính toán...",
              subtitle: sub2.isNotEmpty ? sub2 : "Nhấn để xem chi tiết",
              amount: "-${data['cost'] ?? 0}đ",
              amountColor: Colors.redAccent,
              color: Colors.redAccent,
              icon: Icons.directions_bike,
              onTap: () => _showTripDetail(data),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: LỊCH SỬ GIAO DỊCH VÍ ---
  Widget _buildTransactionHistory(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.green));
        
        var docs = snapshot.data!.docs.toList();
        if (docs.isEmpty) return _buildEmptyState(Icons.receipt_long_outlined, "Chưa có giao dịch nào", "Nạp tiền hoặc mua vé để bắt đầu!");

        // ⏰ SẮP XẾP MỚI NHẤT LÊN ĐẦU (client-side, không cần Firebase Index)
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (bData['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            final type = data['type'] ?? '';
            bool isTopup       = type == 'topup';
            bool isMembership  = type == 'membership_buy';
            bool isDailyTicket = type == 'daily_ticket_buy';
            bool isTripPayment = type == 'trip_payment';
            bool isExchange    = type == 'points_exchange';

            String title;
            if (isTopup)            title = "Nạp tiền vào ví";
            else if (isMembership)  title = "Mua Vé Tháng SmartStep";
            else if (isDailyTicket) title = "Mua Vé Lượt Standard";
            else if (isTripPayment) title = "Thanh toán chuyến đi";
            else if (isExchange)    title = data['voucherTitle'] ?? "Đổi điểm ưu đãi";
            else                    title = "Giao dịch";

            String subtitle;
            if (isTopup)            subtitle = "Phương thức: ${data['method'] ?? 'Ví điện tử'}";
            else if (isMembership)  subtitle = data['expiryDate'] != null ? "Hết hạn: ${DateFormat('dd/MM/yyyy').format((data['expiryDate'] as Timestamp).toDate())}" : "Hiệu lực 30 ngày";
            else if (isDailyTicket) subtitle = data['expiryDate'] != null ? "Hết hạn: ${DateFormat('dd/MM/yyyy').format((data['expiryDate'] as Timestamp).toDate())} lúc 23:59" : "Dùng trong ngày";
            else if (isTripPayment) subtitle = "Thanh toán từ ví SmartBike";
            else if (isExchange)    subtitle = "Điểm đã dùng: ${data['pointsUsed'] ?? 0} pts";
            else                    subtitle = "Nhấn để xem chi tiết";

            String amount;
            Color amountColor;
            if (isTopup) { amount = "+${data['amount']}đ"; amountColor = Colors.green; }
            else if (isExchange && (data['amount'] ?? 0) > 0) { amount = "+${data['amount']}đ"; amountColor = Colors.green; }
            else if (isExchange) { amount = "-${data['pointsUsed']} pts"; amountColor = Colors.purple; }
            else { amount = "-${data['amount']}đ"; amountColor = Colors.redAccent; }

            Color color;
            if (isTopup)            color = Colors.green;
            else if (isMembership)  color = Colors.blue;
            else if (isDailyTicket) color = Colors.orange;
            else if (isExchange)    color = Colors.purple;
            else                    color = Colors.redAccent;

            IconData icon;
            if (isTopup)            icon = Icons.add_card;
            else if (isMembership)  icon = Icons.calendar_month;
            else if (isDailyTicket) icon = Icons.confirmation_number_outlined;
            else if (isExchange)    icon = Icons.card_giftcard;
            else                    icon = Icons.receipt_long;

            return _buildRichCard(
              title: title,
              time: data['timestamp'] != null
                  ? DateFormat('HH:mm - dd/MM/yyyy').format((data['timestamp'] as Timestamp).toDate())
                  : "Vừa xong",
              subtitle: subtitle,
              amount: amount,
              amountColor: amountColor,
              color: color,
              icon: icon,
              onTap: () {
                if (isMembership) _showMembershipDetail(data);
                else if (isTripPayment && data['relatedTripId'] != null) _showTripDetailById(data['relatedTripId']);
                else _showTransactionDetail(data, title, amount, amountColor);
              },
            );
          },
        );
      },
    );
  }

  // --- HÀM BỔ TRỢ 1: TÌM CHUYẾN ĐI TỪ ID GIAO DỊCH ---
  void _showTripDetailById(String tripId) async {
    try {
      var tripDoc = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
      if (tripDoc.exists) {
        _showTripDetail(tripDoc.data() as Map<String, dynamic>);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không tìm thấy dữ liệu chuyến đi liên kết.")),
        );
      }
    } catch (e) {
      print("Lỗi truy xuất: $e");
    }
  }

  // --- HÀM BỔ TRỢ 2: HIỆN CHI TIẾT VÉ THÁNG ---
  void _showMembershipDetail(Map<String, dynamic> data) {
    final paidDate = data['timestamp'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format((data['timestamp'] as Timestamp).toDate())
        : 'N/A';
    final expiry = data['expiryDate'] != null
        ? DateFormat('dd/MM/yyyy').format((data['expiryDate'] as Timestamp).toDate())
        : '30 ngày từ ngày mua';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.calendar_month, color: Colors.blue)),
            const SizedBox(width: 10),
            const Text("Chi tiết vé tháng", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow(Icons.confirmation_number, "Gói", data['itemName'] ?? "Vé Tháng SmartStep", Colors.blue),
            _detailRow(Icons.payments_outlined, "Giá", "${data['amount'] ?? 159000}đ", Colors.redAccent, bold: true),
            _detailRow(Icons.calendar_today, "Ngày mua", paidDate, Colors.orange),
            _detailRow(Icons.event_available, "Hết hạn", expiry, Colors.green),
            const Divider(height: 20),
            _detailRow(Icons.payment, "Hình thức", "Trừ ví SmartBike", Colors.grey),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
              child: const Row(
                children: [
                  Icon(Icons.star, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text("Miễn phí 5 tiếng đầu mỗi chuyến đi", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blue))),
                ],
              ),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))],
      ),
    );
  }

  // --- CARD ĐẸP CHO LỊCH SỬ ---
  Widget _buildRichCard({
    required String title,
    required String time,
    required String subtitle,
    required String amount,
    required Color amountColor,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon bên trái
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              // Nội dung giữa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ),
              // Số tiền + mũi tên
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amount, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: amountColor)),
                  const SizedBox(height: 6),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey[300]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HÀM HIỂN THỊ CHI TIẾT CHUYẾN ĐI (ĐẦY ĐỦ THÔNG TIN) ---
  void _showTripDetail(Map<String, dynamic> data) {
    final startTime = data['startTime'] != null ? DateFormat('HH:mm dd/MM/yyyy').format((data['startTime'] as Timestamp).toDate()) : 'N/A';
    final endTime = data['endTime'] != null ? DateFormat('HH:mm dd/MM/yyyy').format((data['endTime'] as Timestamp).toDate()) : 'N/A';
    final startLoc = data['startLocation'] ?? 'Không xác định';
    final endLoc = data['endLocation'] ?? 'Đang di chuyển';
    final duration = data['duration'] ?? 0;
    final distance = (data['distance'] ?? 0).toDouble();
    final cost = data['cost'] ?? 0;
    final status = data['status'] ?? 'Unknown';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.directions_bike, color: Colors.redAccent)),
            const SizedBox(width: 10),
            const Text("Chi tiết chuyến đi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow(Icons.pedal_bike, "Mã xe", data['bikeId']?.toString() ?? 'N/A', Colors.blue),
              
              // Trạng thái
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: status == 'Completed' ? Colors.green : Colors.orange),
                    const SizedBox(width: 10),
                    const Text("Trạng thái", style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'Completed' ? Colors.green[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status == 'Completed' ? '✓ Hoàn thành' : '● Đang đi',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: status == 'Completed' ? Colors.green : Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 16),
              
              // Lộ trình đẹp
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        const Text("Điểm đi:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(startLoc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 2)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(width: 2, height: 20, color: Colors.grey[300]),
                      ),
                    ),
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        const Text("Điểm đến:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(endLoc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 2)),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Thời gian
              _detailRow(Icons.play_circle_outline, "Bắt đầu", startTime, Colors.green),
              _detailRow(Icons.stop_circle_outlined, "Kết thúc", endTime, Colors.red),
              
              const Divider(height: 16),
              
              // Thống kê
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
                          const SizedBox(height: 4),
                          Text("$duration phút", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
                          const Text("Thời gian", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          const Icon(Icons.route, color: Colors.teal, size: 20),
                          const SizedBox(height: 4),
                          Text("${distance.toStringAsFixed(2)} km", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                          const Text("Quãng đường", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          const Icon(Icons.payments_outlined, color: Colors.redAccent, size: 20),
                          const SizedBox(height: 4),
                          Text("${cost}đ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
                          const Text("Chi phí", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 14),
                    SizedBox(width: 6),
                    Text("Đã trừ từ ví SmartBike", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))],
      ),
    );
  }

  // --- WIDGET HÀNG THÔNG TIN CHI TIẾT ---
  Widget _detailRow(IconData icon, String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: bold ? color : Colors.black87), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  // --- DIALOG CHI TIẾT GIAO DỊCH TỔNG QUÁT ---
  void _showTransactionDetail(Map<String, dynamic> data, String title, String amount, Color amountColor) {
    final timestamp = data['timestamp'] != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format((data['timestamp'] as Timestamp).toDate())
        : 'N/A';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow(Icons.access_time, "Thời gian", timestamp, Colors.blue),
            if (data['method'] != null)
              _detailRow(Icons.payment, "Phương thức", data['method'], Colors.orange),
            if (data['itemName'] != null)
              _detailRow(Icons.label_outline, "Gói", data['itemName'], Colors.teal),
            if (data['pointsUsed'] != null)
              _detailRow(Icons.stars, "Điểm đã dùng", "${data['pointsUsed']} pts", Colors.purple),
            if (data['expiryDate'] != null)
              _detailRow(Icons.event_available, "Hết hạn", DateFormat('dd/MM/yyyy').format((data['expiryDate'] as Timestamp).toDate()), Colors.green),
            const Divider(),
            _detailRow(Icons.payments_outlined, "Số tiền", amount, amountColor, bold: true),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))],
      ),
    );
  }

  // --- HIỂN THỊ KHI DANH SÁCH TRỐNG ---
  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(icon, size: 52, color: Colors.grey[350]),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMART BIKE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi Smart Bike?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: _buildPages()),
          // 💬 Bong bóng chatbot AI (draggable, voice + text)
          ChatBubbleWidget(provider: _chatbotProvider),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startQRScanFlow(context),
        backgroundColor: const Color(0xFFFF9800), 
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('QUÉT ĐỂ THUÊ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Tìm xe'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Hoạt động'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), label: 'Tôi'),
        ],
      ),
    );
  }

   void _startQRScanFlow(BuildContext context) async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "user_test";
    final paymentService = PaymentService(); 
    
    // ✅ CHECK BALANCE >= 20k
    bool canRent = await paymentService.canRentBike(userId);
    
    if (!canRent) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Ví phải có ít nhất 20.000đ để thuê xe!"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // 📸 MỞ MÀN HÌNH QUÉT MÃ QR
    if (!mounted) return;
    final scannedData = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    // 🔍 NẾU QUÉT THÀNH CÔNG VÀ TRẢ VỀ DỮ LIỆU
    if (scannedData != null && scannedData is String) {
      if (!mounted) return;

      // HIỆN LOADING KHI ĐANG TÌM XE
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // TÌM XE TRONG FIRESTORE DỰA TRÊN MÃ QR (qrData hoặc bikeId)
        final querySnapshot = await FirebaseFirestore.instance
            .collection('bikes')
            .where('qrData', isEqualTo: scannedData)
            .get();

        if (!mounted) return;
        Navigator.pop(context); // Đóng loading

        if (querySnapshot.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Không tìm thấy xe với mã QR này!"), backgroundColor: Colors.red),
          );
          return;
        }

        final bikeDoc = querySnapshot.docs.first;
        final bikeData = bikeDoc.data();
        final bikeId = bikeData['bikeId'] ?? bikeDoc.id;
        final status = bikeData['status'] ?? 'unknown';

        // KIỂM TRA TRẠNG THÁI XE
        if (status != 'available') {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Xe này hiện không khả dụng (Đang $status)!"), backgroundColor: Colors.orange),
          );
           return;
        }

        // XE SẴN SÀNG -> HIỂN THỊ DIALOG XÁC NHẬN BẮT ĐẦU CHUYẾN ĐI
        _showConfirmRentDialog(bikeId);

      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Đóng loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Có lỗi xảy ra khi kiểm tra xe: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showConfirmRentDialog(String bikeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 80,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text("✓ Tìm thấy xe $bikeId",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                children: [
                  Text(
                    "💰 Giá thuê tiêu chuẩn",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text("10.000đ / 60p đầu",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      )),
                  SizedBox(height: 5),
                  Text("+ 3.000đ / 15p tiếp theo",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // Đóng dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActiveTripScreen(bikeId: bikeId),
                    ),
                  );
                },
                child: const Text(
                  "🚴 BẮT ĐẦU CHUYẾN ĐI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
  
}