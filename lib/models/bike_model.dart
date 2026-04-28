class Bike {
  final String id;
  String currentStationId; // Đang nằm ở trạm nào (nếu bị mượn thì để trống)
  String status; // 'available' (sẵn sàng), 'in_use' (đang thuê), 'maintenance' (bảo trì)

  Bike({
    required this.id,
    required this.currentStationId,
    this.status = 'available',
  });

  factory Bike.fromJson(Map<String, dynamic> json, String id) {
    return Bike(
      id: id,
      currentStationId: json['currentStationId'] ?? '',
      status: json['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentStationId': currentStationId,
      'status': status,
    };
  }
}