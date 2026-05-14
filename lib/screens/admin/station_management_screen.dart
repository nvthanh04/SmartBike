import 'package:flutter/material.dart';
// Đảm bảo đường dẫn import model này khớp với cấu trúc thư mục của bạn
import '../../models/station_model.dart'; 

class StationManagementScreen extends StatefulWidget {
  const StationManagementScreen({Key? key}) : super(key: key);
  @override
  _StationManagementScreenState createState() => _StationManagementScreenState();
}

class _StationManagementScreenState extends State<StationManagementScreen> {
  // 1. Tạo một list dữ liệu giả (Mock Data) để test UI
  List<Station> stations = [
    Station(
      id: 's1', 
      name: 'Trạm Đại học Bách Khoa', 
      latitude: 21.0056, 
      longitude: 105.8434, 
      capacity: 20, 
      currentBikes: 15
    ),
    Station(
      id: 's2', 
      name: 'Trạm Công viên Thống Nhất', 
      latitude: 21.0182, 
      longitude: 105.8413, 
      capacity: 30, 
      currentBikes: 5
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Trạm xe'),
        backgroundColor: Colors.blueAccent,
      ),
      // 2. Dùng ListView.builder để hiển thị danh sách trạm
      body: ListView.builder(
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final station = stations[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[100],
                child: Icon(Icons.directions_bike, color: Colors.green[800]),
              ),
              title: Text(station.name, style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Sức chứa: ${station.currentBikes} / ${station.capacity} xe'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nút Sửa
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue), 
                    onPressed: () {
                      // TODO: Xử lý mở form sửa trạm
                      print('Sửa trạm: ${station.name}');
                    }
                  ),
                  // Nút Xóa
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red), 
                    onPressed: () {
                      // TODO: Xử lý xóa trạm
                      setState(() {
                        stations.removeAt(index);
                      });
                    }
                  ),
                ],
              ),
            ),
          );
        },
      ),
      // 3. Nút Thêm trạm mới
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Mở Dialog hoặc chuyển trang để nhập thông tin trạm mới
          print('Mở form thêm trạm mới');
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}