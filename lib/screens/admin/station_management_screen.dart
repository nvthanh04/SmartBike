import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/station_model.dart';
import '../../models/bike_model.dart';
import '../../services/station_service.dart';
import '../../services/bike_service.dart';
import 'admin_map_picker_screen.dart';
import 'package:latlong2/latlong.dart';
class StationManagementScreen extends StatefulWidget {
  const StationManagementScreen({super.key});

  @override
  State<StationManagementScreen> createState() =>
      _StationManagementScreenState();
}

class _StationManagementScreenState extends State<StationManagementScreen> {
  final StationService _stationService = StationService();
  final BikeService _bikeService = BikeService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Trạm xe'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Station>>(
        stream: _stationService.getStationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          final stations = snapshot.data ?? [];
          if (stations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Chưa có trạm nào', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text('Nhấn + để thêm trạm mới', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: stations.length,
            itemBuilder: (context, index) => _buildStationCard(stations[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStationDialog(),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Thêm trạm'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStationCard(Station station) {
    final isActive = station.status == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive ? Colors.green[100] : Colors.orange[100],
                  child: Icon(Icons.ev_station, color: isActive ? Colors.green[800] : Colors.orange[800]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(station.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (station.address.isNotEmpty)
                        Text(station.address, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isActive ? Colors.green : Colors.orange),
                  ),
                  child: Text(
                    isActive ? 'Hoạt động' : 'Bảo trì',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.green[800] : Colors.orange[800]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.directions_bike, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                // Đếm số xe thực tế từ Firestore
                StreamBuilder<List<Bike>>(
                  stream: _bikeService.getBikesByStationStream(station.id),
                  builder: (context, bikeSnap) {
                    final count = bikeSnap.data?.length ?? 0;
                    final isWarning = count > station.capacity || count <= 5;
                    
                    return Row(
                      children: [
                        Text(
                          '$count/${station.capacity} xe',
                          style: TextStyle(
                            fontSize: 13,
                            color: isWarning ? Colors.red : Colors.grey[700],
                            fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isWarning) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Text(
                              count < 5 ? 'ÍT XE' : 'QUÁ TẢI',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(width: 16),
                Icon(Icons.pin_drop, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${station.latitude.toStringAsFixed(4)}, ${station.longitude.toStringAsFixed(4)}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showStationDialog(station: station),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Sửa'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmDelete(station),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Xóa'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStationDialog({Station? station}) {
    final isEdit = station != null;
    final nameCtrl = TextEditingController(text: station?.name ?? '');
    final addressCtrl = TextEditingController(text: station?.address ?? '');
    final stationIdCtrl = TextEditingController(text: station?.stationId ?? '');
    final capacityCtrl = TextEditingController(text: station?.capacity.toString() ?? '20');
    final latCtrl = TextEditingController(text: station?.latitude.toString() ?? '21.0285');
    final lngCtrl = TextEditingController(text: station?.longitude.toString() ?? '105.8542');
    String selectedStatus = station?.status ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Sửa trạm' : 'Thêm trạm mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: stationIdCtrl, decoration: const InputDecoration(labelText: 'Mã trạm', prefixIcon: Icon(Icons.tag), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên trạm *', prefixIcon: Icon(Icons.location_city), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Địa chỉ', prefixIcon: Icon(Icons.map), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: capacityCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sức chứa', prefixIcon: Icon(Icons.people), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: latCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: lngCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final lat = double.tryParse(latCtrl.text) ?? 21.0285;
                      final lng = double.tryParse(lngCtrl.text) ?? 105.8542;
                      final selectedLocation = await Navigator.push<LatLng>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminMapPickerScreen(initialLocation: LatLng(lat, lng)),
                        ),
                      );
                      if (selectedLocation != null) {
                        setDialogState(() {
                          latCtrl.text = selectedLocation.latitude.toStringAsFixed(6);
                          lngCtrl.text = selectedLocation.longitude.toStringAsFixed(6);
                        });
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Chọn vị trí trên bản đồ'),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Trạng thái', prefixIcon: Icon(Icons.info_outline), border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Hoạt động')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Bảo trì')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedStatus = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () => _saveStation(ctx, isEdit, station, nameCtrl, addressCtrl, stationIdCtrl, capacityCtrl, latCtrl, lngCtrl, selectedStatus),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: Text(isEdit ? 'Lưu' : 'Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveStation(BuildContext ctx, bool isEdit, Station? station, TextEditingController nameCtrl, TextEditingController addressCtrl, TextEditingController stationIdCtrl, TextEditingController capacityCtrl, TextEditingController latCtrl, TextEditingController lngCtrl, String status) async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên trạm')));
      return;
    }
    final newStation = Station(
      id: station?.id ?? '',
      stationId: stationIdCtrl.text.trim(),
      name: nameCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      latitude: double.tryParse(latCtrl.text.trim()) ?? 21.0285,
      longitude: double.tryParse(lngCtrl.text.trim()) ?? 105.8542,
      capacity: int.tryParse(capacityCtrl.text.trim()) ?? 20,
      currentBikes: station?.currentBikes ?? 0,
      status: status,
    );
    try {
      if (isEdit) {
        await _stationService.updateStationFull(station!.id, newStation);
      } else {
        await _stationService.addStation(newStation);
      }
      if (mounted) Navigator.pop(ctx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Đã cập nhật trạm' : 'Đã thêm trạm mới'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _confirmDelete(Station station) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa trạm "${station.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _stationService.deleteStation(station.id);
                if (mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa trạm'), backgroundColor: Colors.orange));
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