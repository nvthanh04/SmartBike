class Trip {
  final String id;
  final String bikeId;
  final String startStationId;
  String? endStationId; // Có thể null vì xe đang đi chưa trả
  final DateTime startTime;
  DateTime? endTime; // Có thể null vì chưa trả xe

  Trip({
    required this.id,
    required this.bikeId,
    required this.startStationId,
    this.endStationId,
    required this.startTime,
    this.endTime,
  });

  factory Trip.fromJson(Map<String, dynamic> json, String id) {
    return Trip(
      id: id,
      bikeId: json['bikeId'] ?? '',
      startStationId: json['startStationId'] ?? '',
      endStationId: json['endStationId'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bikeId': bikeId,
      'startStationId': startStationId,
      'endStationId': endStationId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }
}