import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/admin_notification_service.dart';
import '../auth/login_screen.dart';
import 'station_management_screen.dart';
import 'bike_management_screen.dart';
import 'statistics_screen.dart';
import 'admin_support_screen.dart';

/// Màn hình tổng quan Admin — điều hướng tới các chức năng quản lý
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminNotificationService _notifService = AdminNotificationService();
  List<StationAlert> _alerts = [];
  int _pendingTickets = 0;
  bool _loadingAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    // Lắng nghe support tickets pending
    _notifService.getPendingTicketsCount().listen((count) {
      if (mounted) setState(() => _pendingTickets = count);
    });
  }

  Future<void> _loadAlerts() async {
    setState(() => _loadingAlerts = true);
    try {
      final alerts = await _notifService.getStationAlerts();
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _loadingAlerts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingAlerts = false);
    }
  }

  int get _totalBadgeCount => _alerts.length + _pendingTickets;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // 🔔 NÚT CHUÔNG THÔNG BÁO
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                tooltip: 'Thông báo cảnh báo',
                onPressed: () => _showNotificationSheet(context),
              ),
              if (_totalBadgeCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _totalBadgeCount > 9 ? '9+' : '$_totalBadgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Admin?'),
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
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text(
                'Quản lý hệ thống SmartBike',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Chọn chức năng quản lý bên dưới',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),

              // ⚠️ Cảnh báo nhanh (nếu có)
              if (_alerts.isNotEmpty) ...[
                _buildAlertSummary(),
                const SizedBox(height: 20),
              ],

              // Card: Quản lý Trạm
              _buildMenuCard(
                context,
                icon: Icons.ev_station,
                title: 'Quản lý Trạm xe',
                subtitle: 'Thêm, sửa, xóa trạm. Lọc & điều phối xe.',
                color: Colors.blueAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StationManagementScreen()),
                ),
              ),
              const SizedBox(height: 16),

              // Card: Quản lý Xe
              _buildMenuCard(
                context,
                icon: Icons.pedal_bike,
                title: 'Quản lý Xe',
                subtitle: 'Thêm xe, tạo QR tự động, quản lý trạng thái và vị trí.',
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BikeManagementScreen()),
                ),
              ),
              const SizedBox(height: 16),

              // Card: Thống kê
              _buildMenuCard(
                context,
                icon: Icons.bar_chart,
                title: 'Thống kê',
                subtitle: 'Xem báo cáo hoạt động, doanh thu.',
                color: Colors.deepPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                ),
              ),
              const SizedBox(height: 16),

              // Card: Hỗ trợ người dùng
              _buildMenuCard(
                context,
                icon: Icons.support_agent,
                title: 'Hỗ trợ người dùng',
                subtitle: 'Xem và trả lời câu hỏi từ chatbot AI.',
                color: Colors.orange,
                badge: _pendingTickets > 0 ? _pendingTickets : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminSupportScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget cảnh báo nhanh ở đầu dashboard
  Widget _buildAlertSummary() {
    int lowCount = _alerts.where((a) => a.alertType == 'low').length;
    int highCount = _alerts.where((a) => a.alertType == 'high').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withOpacity(0.08), Colors.orange.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'Cảnh báo trạm xe',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showNotificationSheet(context),
                child: const Text('Xem tất cả →', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (lowCount > 0) ...[
                _buildAlertChip('🔴 $lowCount trạm thiếu xe', Colors.red),
                const SizedBox(width: 8),
              ],
              if (highCount > 0)
                _buildAlertChip('🔵 $highCount trạm thừa xe', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  /// BottomSheet hiển thị tất cả cảnh báo
  void _showNotificationSheet(BuildContext context) {
    // Refresh data
    _loadAlerts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.indigo, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Thông báo & Cảnh báo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_pendingTickets > 0)
                        ActionChip(
                          label: Text('$_pendingTickets câu hỏi chờ'),
                          avatar: const Icon(Icons.support_agent, size: 18),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminSupportScreen()),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Danh sách cảnh báo
                  if (_loadingAlerts)
                    const Center(child: CircularProgressIndicator())
                  else if (_alerts.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 56, color: Colors.green[300]),
                            const SizedBox(height: 12),
                            const Text('Tất cả trạm hoạt động bình thường!',
                                style: TextStyle(fontSize: 16, color: Colors.green)),
                            Text('Không có cảnh báo nào',
                                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _alerts.length,
                        itemBuilder: (context, index) {
                          final alert = _alerts[index];
                          return _buildAlertCard(alert, ctx);
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

  Widget _buildAlertCard(StationAlert alert, BuildContext sheetCtx) {
    final isLow = alert.alertType == 'low';
    final color = isLow ? Colors.red : Colors.blue;
    final icon = isLow ? Icons.warning_amber_rounded : Icons.inventory_2;
    final label = isLow ? 'THIẾU XE' : 'THỪA XE';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(alert.station.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '${alert.currentBikes}/${alert.station.capacity} xe • ${alert.fillPercent.toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ),
        onTap: () {
          Navigator.pop(sheetCtx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StationManagementScreen(
                initialFilter: isLow ? 'low' : 'high',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    int? badge,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
