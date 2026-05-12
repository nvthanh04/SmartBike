import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'active_trip_screen.dart';
import '../map_screen.dart';
import 'package:intl/intl.dart'; 

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _selectedIndex = 0;
  final Color primaryGreen = const Color(0xFF2ECC71); 

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
                      String name = snapshot.hasData && snapshot.data!.exists ? (snapshot.data!['name'] ?? "Nhung ptt") : "Nhung ptt";
                      return Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold));
                    },
                  ),
                  const Text("Hạng: Thành viên Kim cương", style: TextStyle(color: Colors.white70, fontSize: 13)),
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

  void _showTopUpOptions(String userId) {
    int selectedAmount = 20000;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("NẠP TIỀN VÀO VÍ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children: [10000, 20000, 50000, 100000].map((amount) {
                  return ChoiceChip(
                    label: Text("${amount ~/ 1000}k"),
                    selected: selectedAmount == amount,
                    onSelected: (selected) => setModalState(() => selectedAmount = amount),
                    selectedColor: primaryGreen.withOpacity(0.2),
                  );
                }).toList(),
              ),
              const Divider(height: 40),
              ListTile(
                leading: const Icon(Icons.account_balance, color: Colors.blue),
                title: const Text("Ngân hàng (NAPAS)"),
                onTap: () { Navigator.pop(context); _handleTopUp(userId, selectedAmount, "Ngân hàng"); },
              ),
              ListTile(
                leading: const Icon(Icons.wallet, color: Colors.pink),
                title: const Text("Ví MoMo"),
                onTap: () { Navigator.pop(context); _handleTopUp(userId, selectedAmount, "MoMo"); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTopUp(String userId, int amount, String method) {
    FirebaseFirestore.instance.collection('users').doc(userId).update({
      'balance': FieldValue.increment(amount),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Thành công: +$amountđ từ $method")),
    );
  }

  void _handlePurchase(String userId, int price, String itemName) {
    FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
      int currentBalance = doc['balance'] ?? 0;
      if (currentBalance >= price) {
        int bonusPoints = (price / 100).floor();
        doc.reference.update({
          'balance': FieldValue.increment(-price),
          'points': FieldValue.increment(bonusPoints),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã mua $itemName! +$bonusPoints pts"), backgroundColor: primaryGreen),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Số dư ví không đủ!"), backgroundColor: Colors.red),
        );
      }
    });
  }

  Widget _buildSubscriptionSection(String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("GÓI SỬ DỤNG TIẾT KIỆM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          _buildPackageItem(userId, "Vé Lượt Standard", "10.000đ", "60p đầu", Colors.orange, Icons.confirmation_number_outlined, 10000),
          const SizedBox(height: 12),
          _buildPackageItem(userId, "Vé Tháng SmartStep", "79.000đ", "Dùng 30 ngày", const Color(0xFF2ECC71), Icons.calendar_month_outlined, 79000),
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

  Widget _buildPackageItem(String userId, String name, String price, String note, Color color, IconData icon, int priceInt) {
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
            onPressed: () => _handlePurchase(userId, priceInt, name),
            style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
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
            onPressed: () => _handleExchangePoints(userId, cost),
            style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(cost, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _handleExchangePoints(String userId, String costStr) {
    int cost = int.parse(costStr.split(' ')[0]);
    FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
      if (doc.exists) {
        int currentPoints = doc['points'] ?? 0;
        if (currentPoints >= cost) {
          doc.reference.update({'points': FieldValue.increment(-cost)});
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đổi Voucher thành công!")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không đủ điểm!"), backgroundColor: Colors.red));
        }
      }
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
          // .orderBy('startTime', descending: true) // Chỉ bật dòng này nếu đã tạo Index trên Firebase
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState("Bạn chưa có chuyến đi nào");

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return _buildActivityItem(
              title: "Chuyến đi #${data['bikeId'] ?? 'BIKE'}",
              sub: data['startTime'] != null 
                ? DateFormat('HH:mm - dd/MM/yyyy').format((data['startTime'] as Timestamp).toDate())
                : "Đang tính toán...",
              amount: "-${data['cost']}đ",
              color: Colors.redAccent,
              icon: Icons.directions_bike,
              onTap: () => _showTripDetail(data), // Nhấn vào để xem chi tiết tiền
            );
          },
        );
      },
    );
  }

  // --- TAB 2: LỊCH SỬ GIAO DỊCH VÍ (BẢN FULL KẾT NỐI DATA) ---
  Widget _buildTransactionHistory(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          // Nếu bạn đã tạo Index trên Firebase thì bật dòng dưới này để sắp xếp mới nhất lên đầu
          // .orderBy('timestamp', descending: true) 
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.green));
        
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState("Chưa có giao dịch tài chính nào");

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            
            // 1. TỰ ĐỘNG PHÂN LOẠI GIAO DỊCH
            bool isAdd = data['type'] == 'topup'; // Nạp tiền vào ví
            bool isMembership = data['type'] == 'membership_buy'; // Mua gói vé tháng
            bool isTripPayment = data['type'] == 'trip_payment'; // Thanh toán trả xe

            return _buildActivityItem(
              // Tự động nhảy tiêu đề theo loại giao dịch
              title: isMembership 
                  ? "Đăng ký Vé Tháng 79k" 
                  : (isAdd ? "Nạp tiền vào ví" : "Thanh toán chuyến đi"),
              
              // Tự động nhảy ngày tháng (Nếu chưa có thì hiện "Vừa xong")
              sub: data['timestamp'] != null 
                ? DateFormat('HH:mm - dd/MM/yyyy').format((data['timestamp'] as Timestamp).toDate())
                : "Vừa xong",
              
              // Hiện số tiền (+/-)
              amount: "${isAdd ? '+' : '-'}${data['amount']}đ",
              
              // Màu sắc: Nạp (Xanh lá), Vé tháng (Xanh dương), Trả xe (Đỏ)
              color: isAdd ? Colors.green : (isMembership ? Colors.blue : Colors.redAccent),
              
              // Icon tương ứng cho từng loại
              icon: isMembership ? Icons.stars : (isAdd ? Icons.add_card : Icons.receipt_long),
              
              // 2. KẾT NỐI DATA: ẤN VÀO LÀ NHẢY SANG CHI TIẾT
              onTap: () {
                if (isMembership) {
                  // Hiện Popup chi tiết gói cước vé tháng
                  _showMembershipDetail(data); 
                } else if (isTripPayment && data['relatedTripId'] != null) {
                  // Lấy tripId để đi "lùng" thông tin chuyến đi rồi hiện Popup
                  _showTripDetailById(data['relatedTripId']); 
                }
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Chi tiết đăng ký vé", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Gói cước: VÉ THÁNG 79K", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Hình thức: Trừ ví SmartBike"),
            Text("Thời hạn: 30 ngày sử dụng"),
            const Divider(),
            const Text("Quyền lợi: Miễn phí 60p đầu/chuyến", style: TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            Text("Ngày thanh toán: ${data['timestamp'] != null ? DateFormat('dd/MM/yyyy').format((data['timestamp'] as Timestamp).toDate()) : 'Vừa xong'}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))
        ],
      ),
    );
  }

  // --- WIDGET DÙNG CHUNG CHO CÁC DÒNG LỊCH SỬ ---
  Widget _buildActivityItem({
    required String title, 
    required String sub, 
    required String amount, 
    required Color color, 
    required IconData icon, 
    VoidCallback? onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(15), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), 
                  Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                ]
              )
            ),
            Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // --- HÀM HIỂN THỊ CHI TIẾT KHI BẤM VÀO CHUYẾN ĐI ---
  void _showTripDetail(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Chi tiết thanh toán"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Mã xe: ${data['bikeId']}"),
            Text("Thời gian: ${data['duration']} phút"),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tổng cước phí:"),
                Text("${data['cost']}đ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 10),
            const Text("Trạng thái: Đã trừ từ số dư ví", style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))
        ],
      ),
    );
  }

  // --- HIỂN THỊ KHI DANH SÁCH TRỐNG ---
  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(Icons.history_toggle_off, size: 60, color: Colors.grey[300]), 
          const SizedBox(height: 10), 
          Text(msg, style: const TextStyle(color: Colors.grey))
        ]
      )
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
      ),
      body: IndexedStack(index: _selectedIndex, children: _buildPages()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMockScanQRDialog(context),
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

  void _showMockScanQRDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: primaryGreen),
            const SizedBox(height: 16),
            const Text("Tìm thấy xe BIKE-001", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Giá thuê: 1.000đ / phút"),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ActiveTripScreen(bikeId: 'BIKE-001')));
                },
                child: const Text("BẮT ĐẦU CHUYẾN ĐI", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
  
}