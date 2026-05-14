import 'package:cloud_firestore/cloud_firestore.dart';

class Bike {
  final String id;        // Document ID trên Firestore
  final String bikeId;    // Mã số xe (có thể = id)
  final String bikeName;  // Tên hoặc dòng xe
  String stationId;       // Mã trạm đang đỗ (trống nếu đang thuê)
  String status;          // 'available', 'in_use', 'maintenance'
  final String qrData;          // Nội dung QR (VD: "BIKE_001")
  final String qrImageBase64;   // Ảnh QR dạng Base64
  String? currentUserId;        // ID người đang thuê (null nếu không ai thuê)
  DateTime? unlockTime;         // Thời điểm bắt đầu thuê
  DateTime? lastMaintenanceDate; // Ngày bảo trì gần nhất

  Bike({
    required this.id,
    required this.bikeId,
    this.bikeName = '',
    required this.stationId,
    this.status = 'available',
    this.qrData = '',
    this.qrImageBase64 = '',
    this.currentUserId,
    this.unlockTime,
    this.lastMaintenanceDate,
  });

  factory Bike.fromJson(Map<String, dynamic> json, String id) {
    return Bike(
      id: id,
      bikeId: json['bikeId'] ?? id,
      bikeName: json['bikeName'] ?? '',
      stationId: json['stationId'] ?? json['currentStationId'] ?? '',
      status: json['status'] ?? 'available',
      qrData: json['qrData'] ?? '',
      qrImageBase64: json['qrImageBase64'] ?? '',
      currentUserId: json['currentUserId'],
      unlockTime: json['unlockTime'] != null
          ? (json['unlockTime'] is Timestamp
              ? (json['unlockTime'] as Timestamp).toDate()
              : DateTime.tryParse(json['unlockTime'].toString()))
          : null,
      lastMaintenanceDate: json['lastMaintenanceDate'] != null
          ? (json['lastMaintenanceDate'] is Timestamp
              ? (json['lastMaintenanceDate'] as Timestamp).toDate()
              : DateTime.tryParse(json['lastMaintenanceDate'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bikeId': bikeId,
      'bikeName': bikeName,
      'stationId': stationId,
      'status': status,
      'qrData': qrData,
      'qrImageBase64': qrImageBase64,
      'currentUserId': currentUserId,
      'unlockTime': unlockTime != null ? Timestamp.fromDate(unlockTime!) : null,
      'lastMaintenanceDate': lastMaintenanceDate != null
          ? Timestamp.fromDate(lastMaintenanceDate!)
          : null,
    };
  }
}