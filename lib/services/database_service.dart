import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<int> getBalance(String phoneNumber) async {
    try {
      // Tìm user có số điện thoại khớp
      var snapshot = await _db.collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['balance'] ?? 0;
      }
      return 0; // Không tìm thấy thì coi như 0đ
    } catch (e) {
      print("Lỗi đọc Firebase: $e");
      return 0;
    }
  }
}