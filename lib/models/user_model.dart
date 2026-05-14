import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String phoneNumber;
  final String email;
  final int balance;
  final int points;
  final bool isMonthlyTicket;
  final DateTime? expiryDate; // 🆕 Thêm trường ngày hết hạn
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userCode;
  final String status;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.phoneNumber,
    required this.email,
    required this.balance,
    required this.points,
    required this.isMonthlyTicket,
    this.expiryDate, // 🆕 Có thể null nếu chưa mua bao giờ
    required this.createdAt,
    required this.updatedAt,
    required this.userCode,
    required this.status,
  });

  // Chuyển từ Firestore Document về Object trong Code
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? '',
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
      balance: data['balance'] ?? 0,
      points: data['points'] ?? 0,
      isMonthlyTicket: data['isMonthlyTicket'] ?? false,
      expiryDate: data['expiryDate'] != null 
          ? (data['expiryDate'] as Timestamp).toDate() 
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      userCode: data['userCode'] ?? '',
      status: data['status'] ?? 'active',
    );
  }

  // Chuyển từ Object trong Code để lưu lên Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'email': email,
      'balance': balance,
      'points': points,
      'isMonthlyTicket': isMonthlyTicket,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'userCode': userCode,
      'status': status,
    };
  }
}