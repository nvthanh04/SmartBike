import 'package:flutter/material.dart';
import '../../models/bike_model.dart';
import '../../models/station_model.dart';
import '../../services/bike_service.dart';
import '../../services/station_service.dart';
import 'bike_detail_screen.dart';

class BikeManagementScreen extends StatefulWidget {
  const BikeManagementScreen({super.key});

  @override
  State<BikeManagementScreen> createState() => _BikeManagementScreenState();
}

class _BikeManagementScreenState extends State<BikeManagementScreen> {
  final BikeService _bikeService = BikeService();
  final StationService _stationService = StationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Xe'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Bike>>(
        stream: _bikeService.getBikesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          final bikes = snapshot.data ?? [];
          if (bikes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pedal_bike, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Chưa có xe nào', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text('Nhấn + để thêm xe mới', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bikes.length,
            itemBuilder: (context, index) => _buildBikeCard(bikes[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBikeDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm xe'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBikeCard(Bike bike) {
    Color statusColor;
    String statusText;
    switch (bike.status) {
      case 'in_use':
        statusColor = Colors.blue;
        statusText = 'Đang thuê';
        break;
      case 'maintenance':
        statusColor = Colors.orange;
        statusText = 'Bảo trì';
        break;
      default:
        statusColor = Colors.green;
        statusText = 'Sẵn sàng';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BikeDetailScreen(bike: bike))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Icon(Icons.pedal_bike, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bike.bikeName.isNotEmpty ? bike.bikeName : bike.bikeId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('ID: ${bike.bikeId}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.ev_station, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  FutureBuilder<Station?>(
                    future: bike.stationId.isNotEmpty ? _stationService.getStationById(bike.stationId) : Future.value(null),
                    builder: (context, stationSnap) {
                      String sName = 'N/A';
                      if (stationSnap.connectionState == ConnectionState.waiting) {
                        sName = '...';
                      } else if (stationSnap.hasData && stationSnap.data != null) {
                        sName = stationSnap.data!.name;
                      } else if (bike.stationId.isNotEmpty) {
                        sName = 'Không tìm thấy';
                      }
                      return Text('Trạm: $sName', style: TextStyle(fontSize: 13, color: Colors.grey[700]));
                    },
                  ),
                  if (bike.currentUserId != null && bike.currentUserId!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('User: ${bike.currentUserId}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ],
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BikeDetailScreen(bike: bike))),
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text('QR'),
                    style: TextButton.styleFrom(foregroundColor: Colors.purple),
                  ),
                  TextButton.icon(
                    onPressed: () => _showBikeDialog(bike: bike),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Sửa'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(bike),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Xóa'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBikeDialog({Bike? bike}) {
    final isEdit = bike != null;
    final bikeIdCtrl = TextEditingController(text: bike?.bikeId ?? '');
    final bikeNameCtrl = TextEditingController(text: bike?.bikeName ?? '');
    final qrDataCtrl = TextEditingController(text: bike?.qrData ?? '');
    String selectedStatus = bike?.status ?? 'available';
    String? selectedStationId = bike?.stationId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Sửa xe' : 'Thêm xe mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bikeIdCtrl,
                  enabled: !isEdit,
                  decoration: const InputDecoration(labelText: 'Mã xe (bikeId) *', prefixIcon: Icon(Icons.tag), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bikeNameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên xe / Dòng xe', prefixIcon: Icon(Icons.pedal_bike), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                // Dropdown chọn trạm từ Firestore
                FutureBuilder<List<Station>>(
                  future: _stationService.getAllStations(),
                  builder: (context, snap) {
                    final stations = snap.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: selectedStationId != null && stations.any((s) => s.id == selectedStationId) ? selectedStationId : null,
                      decoration: const InputDecoration(labelText: 'Trạm đỗ', prefixIcon: Icon(Icons.ev_station), border: OutlineInputBorder()),
                      items: stations.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (val) => setDialogState(() => selectedStationId = val),
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Trạng thái', prefixIcon: Icon(Icons.info_outline), border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'available', child: Text('Sẵn sàng')),
                    DropdownMenuItem(value: 'in_use', child: Text('Đang thuê')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Bảo trì')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedStatus = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qrDataCtrl,
                  decoration: InputDecoration(
                    labelText: 'QR Data (tự động nếu trống)',
                    prefixIcon: const Icon(Icons.qr_code),
                    border: const OutlineInputBorder(),
                    hintText: isEdit ? '' : 'VD: BIKE_001',
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Text('Đang tạo QR code...', style: TextStyle(color: Colors.grey)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (bikeIdCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập mã xe')));
                  return;
                }
                setDialogState(() => isLoading = true);
                try {
                  if (isEdit) {
                    await _bikeService.updateBike(bike!.id, {
                      'bikeId': bikeIdCtrl.text.trim(),
                      'bikeName': bikeNameCtrl.text.trim(),
                      'stationId': selectedStationId ?? '',
                      'status': selectedStatus,
                    });
                  } else {
                    final newBike = Bike(
                      id: '',
                      bikeId: bikeIdCtrl.text.trim(),
                      bikeName: bikeNameCtrl.text.trim(),
                      stationId: selectedStationId ?? '',
                      status: selectedStatus,
                      qrData: qrDataCtrl.text.trim(),
                    );
                    await _bikeService.addBike(newBike);
                  }
                  if (mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Đã cập nhật xe' : 'Đã thêm xe + tạo QR'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  setDialogState(() => isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: Text(isEdit ? 'Lưu' : 'Thêm + Tạo QR'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Bike bike) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa xe "${bike.bikeName.isNotEmpty ? bike.bikeName : bike.bikeId}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _bikeService.deleteBike(bike.id);
                if (mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa xe'), backgroundColor: Colors.orange));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
