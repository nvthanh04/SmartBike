import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'dart:math';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==========================================
  // 1️⃣ TỰ SINH MÃ NGƯỜI DÙNG
  // ==========================================
  
  String _generateUserCode() {
    // 🔹 Tạo mã: USR-2026-5894
    final year = DateTime.now().year;
    final randomNum = Random().nextInt(9000) + 1000;
    return 'USR-$year-$randomNum';
  }

  // ==========================================
  // 2️⃣ KIỂM TRA MÃ CÓ TRÙNG KHÔNG
  // ==========================================
  
  Future<bool> _userCodeExists(String userCode) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('userCode', isEqualTo: userCode)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("❌ Lỗi kiểm tra mã: $e");
      return false;
    }
  }

  // ==========================================
  // 3️⃣ TỰ SINH MÃ DUY NHẤT (KHÔNG TRÙNG)
  // ==========================================
  
  Future<String> _generateUniqueUserCode() async {
    String userCode = '';
    bool exists = true;

    while (exists) {
      userCode = _generateUserCode();
      exists = await _userCodeExists(userCode);
    }

    return userCode;
  }

  // ==========================================
  // 4️⃣ ĐĂNG KÝ USER MỚI (CHÍNH)
  // ==========================================
  
  Future<UserModel?> registerUser({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    try {
      print("\n📝 ===== BẮT ĐẦU ĐĂNG KÝ =====");
      print("📧 Email: $email");
      print("👤 Full Name: $fullName");
      print("📱 Phone: $phoneNumber");

      // 1️⃣ TẠO FIREBASE AUTH ACCOUNT
      print("\n1️⃣ TẠO FIREBASE AUTH ACCOUNT...");
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;
      print("✅ Auth Account Created");
      print("   UID: $uid");

      // 2️⃣ TỰ SINH MÃ ĐỊNH DANH DUY NHẤT
      print("\n2️⃣ TỰ SINH MÃ ĐỊNH DANH DUY NHẤT...");
      String userCode = await _generateUniqueUserCode();

      // 3️⃣ TẠO USER MODEL
      print("\n3️⃣ TẠO USER MODEL...");
      UserModel newUser = UserModel(
        uid: uid,
        fullName: fullName,
        phoneNumber: phoneNumber,
        email: email,
        balance: 10000, // Tặng 10k để đủ điều kiện thuê xe lượt luôn
        points: 0,
        isMonthlyTicket: false,
        expiryDate: DateTime.now().subtract(const Duration(days: 1)), // 🆕 THÊM DÒNG NÀY
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userCode: userCode,
        status: 'active',
      );

      // 4️⃣ CONVERT → FIRESTORE FORMAT
      print("\n4️⃣ CONVERT → FIRESTORE FORMAT...");
      Map<String, dynamic> firestoreData = newUser.toFirestore();
      print("✅ Converted to Firestore format");

      // 5️⃣ LƯU VÀO FIRESTORE COLLECTION 'users'
      print("\n5️⃣ LƯU VÀO FIRESTORE...");
      await _firestore.collection('users').doc(uid).set(firestoreData);
      print("✅ Saved to Firestore collection 'users'");
      print("   Document ID: $uid");

      // 6️⃣ LƯU LOG ĐĂNG KÝ
      print("\n6️⃣ LƯU LOG ĐĂNG KÝ...");
      await _firestore.collection('activity_logs').add({
        'uid': uid,
        'userCode': userCode,
        'action': 'user_registered',
        'timestamp': FieldValue.serverTimestamp(),
        'email': email,
        'phoneNumber': phoneNumber,
        'fullName': fullName,
      });
      print("✅ Activity log saved");

      // 7️⃣ VERIFY CONSISTENCY
      print("\n7️⃣ VERIFY CONSISTENCY...");
      var result = await verifyUserConsistency(uid);
      if (result['isConsistent']) {
        print("✅ Dữ liệu đồng bộ HOÀN HẢO!");
      } else {
        print("⚠️ CẢNH BÁO: Dữ liệu có vấn đề!");
      }

      print("\n✅ ===== ĐĂNG KÝ THÀNH CÔNG =====\n");
      return newUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('❌ Lỗi: Mật khẩu quá yếu');
        return null;
      } else if (e.code == 'email-already-in-use') {
        print('❌ Lỗi: Email đã tồn tại');
        return null;
      }
      print('❌ Lỗi Auth: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Lỗi đăng ký: $e');
      return null;
    }
  }

  // ==========================================
  // 5️⃣ LẤY DỮ LIỆU USER HIỆN TẠI
  // ==========================================
  
  Future<UserModel?> getCurrentUser() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        print("❌ User chưa đăng nhập");
        return null;
      }

      var doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        print("❌ Dữ liệu user không tồn tại trong Firestore");
        return null;
      }

      UserModel user = UserModel.fromFirestore(doc);
      print("✅ Lấy user: ${user.userCode}");
      return user;
    } catch (e) {
      print("❌ Lỗi lấy dữ liệu: $e");
      return null;
    }
  }

  // ==========================================
  // 6️⃣ KIỂM TRA CONSISTENCY (CHÍNH)
  // ==========================================
  
  Future<Map<String, dynamic>> verifyUserConsistency(String uid) async {
    try {
      print("\n🔍 ===== KIỂM TRA CONSISTENCY =====");
      print("Kiểm tra user: $uid");

      // CHECK 1: Auth có user không
      print("\n✓ CHECK 1: Auth có user không?");
      User? authUser = _auth.currentUser;
      bool authExists = authUser?.uid == uid;
      print("  → Auth user exists: $authExists");
      if (!authExists) {
        print("  ❌ FAIL: Auth user không tồn tại!");
      }

      // CHECK 2: Firestore có user không
      print("\n✓ CHECK 2: Firestore có user không?");
      var firestoreDoc = await _firestore.collection('users').doc(uid).get();
      bool firestoreExists = firestoreDoc.exists;
      print("  → Firestore user exists: $firestoreExists");
      if (!firestoreExists) {
        print("  ❌ FAIL: Firestore user không tồn tại!");
      }

      // Nếu một trong hai không tồn tại → FAIL
      if (!authExists || !firestoreExists) {
        print("\n❌ ===== MISMATCH: Dữ liệu không đồng bộ =====\n");
        return {
          'isConsistent': false,
          'authExists': authExists,
          'firestoreExists': firestoreExists,
          'message': 'Dữ liệu không đồng bộ giữa Auth & Firestore',
        };
      }

      // CHECK 3: Field đầy đủ không
      print("\n✓ CHECK 3: Field đầy đủ không?");
      UserModel user = UserModel.fromFirestore(firestoreDoc);
      
      bool hasUid = user.uid.isNotEmpty;
      bool hasUserCode = user.userCode.isNotEmpty;
      bool hasFullName = user.fullName.isNotEmpty;
      bool hasPhone = user.phoneNumber.isNotEmpty;
      bool hasEmail = user.email.isNotEmpty;

      print("  → uid: $hasUid (${user.uid})");
      print("  → userCode: $hasUserCode (${user.userCode})");
      print("  → fullName: $hasFullName (${user.fullName})");
      print("  → phoneNumber: $hasPhone (${user.phoneNumber})");
      print("  → email: $hasEmail (${user.email})");

      bool hasRequiredFields = hasUid && hasUserCode && hasFullName && hasPhone && hasEmail;
      
      if (!hasRequiredFields) {
        print("  ❌ FAIL: Có field trống!");
        print("\n⚠️ ===== CẢNH BÁO: Dữ liệu bị thiếu =====\n");
        return {
          'isConsistent': false,
          'authExists': true,
          'firestoreExists': true,
          'message': 'Dữ liệu bị thiếu field',
        };
      }

      // CHECK 4: Dữ liệu hợp lệ
      print("\n✓ CHECK 4: Dữ liệu hợp lệ?");
      print("  → balance: ${user.balance} (${user.balance >= 0 ? '✅' : '❌'})");
      print("  → points: ${user.points} (${user.points >= 0 ? '✅' : '❌'})");
      print("  → status: ${user.status} (${user.status == 'active' ? '✅' : '⚠️'})");
      print("  → Hạn vé tháng: ${user.expiryDate} (${user.expiryDate != null && user.expiryDate!.isAfter(DateTime.now()) ? 'Còn hạn' : 'Hết hạn'})");
      print("\n✅ ===== TẤT CẢ KIỂM TRA PASS =====");
      print("📊 User Info:");
      print("   🎫 Code: ${user.userCode}");
      print("   👤 Name: ${user.fullName}");
      print("   📱 Phone: ${user.phoneNumber}");
      print("   💰 Balance: ${user.balance}đ");
      print("   ⭐ Points: ${user.points}");
      print("   📅 Created: ${user.createdAt}\n");

      return {
        'isConsistent': true,
        'authExists': true,
        'firestoreExists': true,
        'user': user,
        'message': 'Dữ liệu đồng bộ HOÀN HẢO',
      };
    } catch (e) {
      print("❌ Lỗi kiểm tra: $e");
      return {
        'isConsistent': false,
        'message': 'Lỗi hệ thống: $e',
      };
    }
  }

  // ==========================================
  // 7️⃣ KIỂM TRA PHONE CÓ TRÙNG KHÔNG
  // ==========================================
  
  Future<bool> phoneNumberExists(String phoneNumber) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print("❌ Lỗi kiểm tra phone: $e");
      return false;
    }
  }

  // ==========================================
  // 8️⃣ TÌM USER BẰNG MÃ ĐỊNH DANH
  // ==========================================
  
  Future<UserModel?> findUserByCode(String userCode) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userCode', isEqualTo: userCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print("❌ Không tìm thấy user: $userCode");
        return null;
      }

      UserModel user = UserModel.fromFirestore(snapshot.docs.first);
      print("✅ Tìm thấy user: ${user.fullName}");
      return user;
    } catch (e) {
      print("❌ Lỗi tìm kiếm: $e");
      return null;
    }
  }
  // ==========================================
  // 9️⃣ MUA VÉ THÁNG (149K)
  // ==========================================
  Future<String> purchaseMonthlyTicket() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) return "Chưa đăng nhập";

      DocumentReference userRef = _firestore.collection('users').doc(uid);
      
      return await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return "User không tồn tại";

        int currentBalance = snapshot.get('balance') ?? 0;

        if (currentBalance < 149000) return "Số dư không đủ 149.000đ";

        transaction.update(userRef, {
          'balance': currentBalance - 149000,
          'isMonthlyTicket': true,
          'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))), // Gia hạn 30 ngày
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return "SUCCESS";
      });
    } catch (e) {
      return "Lỗi: $e";
    }
  }
}