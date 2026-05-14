import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AdminMapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const AdminMapPickerScreen({super.key, required this.initialLocation});

  @override
  State<AdminMapPickerScreen> createState() => _AdminMapPickerScreenState();
}

class _AdminMapPickerScreenState extends State<AdminMapPickerScreen> {
  late MapController _mapController;
  late LatLng _currentLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLocation = widget.initialLocation;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn vị trí trạm'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentLocation,
              zoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (position.center != null) {
                  setState(() {
                    _currentLocation = position.center!;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.smartbike',
              ),
            ],
          ),
          // Marker ghim ở giữa màn hình
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0), // Đẩy lên để điểm nhọn của ghim chỉ đúng giữa
              child: Icon(
                Icons.location_on,
                size: 50,
                color: Colors.redAccent,
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, _currentLocation);
              },
              child: const Text(
                'Xác nhận vị trí này',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
