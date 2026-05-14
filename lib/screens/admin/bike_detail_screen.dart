import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bike_model.dart';
import '../../models/station_model.dart';
import '../../services/bike_service.dart';
import '../../services/station_service.dart';

/// Màn hình chi tiết xe — hiển thị QR code từ Base64 và thông tin đầy đủ
class BikeDetailScreen extends StatefulWidget {
  final Bike bike;
  const BikeDetailScreen({super.key, required this.bike});

  @override
  State<BikeDetailScreen> createState() => _BikeDetailScreenState();
}

class _BikeDetailScreenState extends State<BikeDetailScreen> {
  final BikeService _bikeService = BikeService();
  final StationService _stationService = StationService();
  late Bike _bike;
  String _stationName = 'Đang tải...';

  @override
  void initState() {
    super.initState();
    _bike = widget.bike;
    _loadStationName();
  }

  Future<void> _loadStationName() async {
    if (_bike.stationId.isEmpty) {
      if (mounted) setState(() => _stationName = 'Không có (Đang thuê)');
      return;
    }
    try {
      final station = await _stationService.getStationById(_bike.stationId);
      if (mounted) {
        setState(() {
          _stationName = station?.name ?? 'Không tìm thấy trạm';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _stationName = 'Lỗi tải tên trạm');
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    switch (_bike.status) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_bike.bikeName.isNotEmpty ? _bike.bikeName : 'Xe ${_bike.bikeId}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== QR CODE =====
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Mã QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_bike.qrImageBase64.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(_bike.qrImageBase64),
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Chưa có QR', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text('QR Data: ${_bike.qrData.isNotEmpty ? _bike.qrData : "N/A"}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    if (_bike.qrImageBase64.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton.icon(
                          onPressed: _regenerateQr,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tạo lại QR'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ===== THÔNG TIN XE =====
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thông tin xe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _infoRow('Mã xe (bikeId)', _bike.bikeId),
                    _infoRow('Tên xe', _bike.bikeName.isNotEmpty ? _bike.bikeName : 'N/A'),
                    _infoRow('Trạm đỗ', _stationName),
                    _infoRowWidget('Trạng thái', Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor)),
                      child: Text(statusText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor)),
                    )),
                    _infoRow('Người thuê', _bike.currentUserId ?? 'Không có'),
                    _infoRow('Thời gian mở khóa', _bike.unlockTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(_bike.unlockTime!) : 'N/A'),
                    _infoRow('Bảo trì lần cuối', _bike.lastMaintenanceDate != null ? DateFormat('dd/MM/yyyy').format(_bike.lastMaintenanceDate!) : 'N/A'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _infoRowWidget(String label, Widget widget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
          widget,
        ],
      ),
    );
  }

  Future<void> _regenerateQr() async {
    final qrData = _bike.qrData.isNotEmpty ? _bike.qrData : 'BIKE_${_bike.bikeId}';
    try {
      await _bikeService.regenerateQr(_bike.id, qrData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo lại QR'), backgroundColor: Colors.green));
        // Reload bike data
        final updated = await _bikeService.getBikeById(_bike.id);
        if (updated != null && mounted) setState(() => _bike = updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      }
    }
  }

}
