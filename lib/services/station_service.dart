import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/station_model.dart';

/// Service quản lý dữ liệu trạm xe từ Cloud Firestore
/// Hỗ trợ đầy đủ CRUD và Stream realtime
class StationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Tên collection trên Firestore
  static const String _collectionName = 'stations';

  // ===================== READ =====================

  /// Stream lắng nghe thay đổi realtime từ collection 'stations'
  /// Trả về danh sách [Station] mỗi khi có thay đổi trên Firestore
  Stream<List<Station>> getStationsStream() {
    return _db.collection(_collectionName).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Station.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Lấy danh sách tất cả trạm (one-time, không realtime)
  Future<List<Station>> getAllStations() async {
    final snapshot = await _db.collection(_collectionName).get();
    return snapshot.docs.map((doc) {
      return Station.fromJson(doc.data(), doc.id);
    }).toList();
  }

  /// Lấy thông tin một trạm theo ID
  Future<Station?> getStationById(String stationId) async {
    final doc = await _db.collection(_collectionName).doc(stationId).get();
    if (doc.exists && doc.data() != null) {
      return Station.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  // ===================== CREATE =====================

  /// Thêm một trạm mới vào Firestore
  /// Trả về document ID nếu thành công
  Future<String> addStation(Station station) async {
    final docRef = await _db.collection(_collectionName).add(station.toJson());
    return docRef.id;
  }

  // ===================== UPDATE =====================

  /// Cập nhật thông tin trạm theo document ID
  /// [data] là Map chứa các trường cần cập nhật
  Future<void> updateStation(String docId, Map<String, dynamic> data) async {
    await _db.collection(_collectionName).doc(docId).update(data);
  }

  /// Cập nhật toàn bộ trạm từ object Station
  Future<void> updateStationFull(String docId, Station station) async {
    await _db.collection(_collectionName).doc(docId).set(station.toJson());
  }

  // ===================== DELETE =====================

  /// Xóa trạm theo document ID
  Future<void> deleteStation(String docId) async {
    await _db.collection(_collectionName).doc(docId).delete();
  }
}
