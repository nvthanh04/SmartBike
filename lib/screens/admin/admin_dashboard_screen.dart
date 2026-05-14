import 'package:flutter/material.dart';
import 'station_management_screen.dart';
import 'admin_dashboard_screen.dart'; // Though it is the same file, maybe check other imports
import 'bike_management_screen.dart';
import 'statistics_screen.dart';

/// Màn hình tổng quan Admin — điều hướng tới các chức năng quản lý
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Padding(
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
            const SizedBox(height: 24),

            // Card: Quản lý Trạm
            _buildMenuCard(
              context,
              icon: Icons.ev_station,
              title: 'Quản lý Trạm xe',
              subtitle: 'Thêm, sửa, xóa trạm. Quản lý sức chứa và trạng thái.',
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

            // Card placeholder: Thống kê (mở rộng sau)
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
          ],
        ),
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
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
