import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ CHECK VÉ THÁNG CÒN HẠN
  Future<bool> hasActiveMembership(String userId) async {
    try {
      var doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        bool isMonthlyTicket = doc['isMonthlyTicket'] ?? false;
        return isMonthlyTicket;
      }
      return false;
    } catch (e) {
      print("❌ Lỗi check membership: $e");
      return false;
    }
  }

  // ✅ TÍNH PHÍ (10k/60p đầu + 3k/15p tiếp theo)
  int calculateCost(int durationMinutes, bool hasMembership) {
    if (hasMembership) return 0; // Miễn phí nếu có vé tháng

    const int FIRST_PERIOD_MINUTES = 60;
    const int FIRST_PERIOD_COST = 10000; // 10k cho 60p đầu
    const int ADDITIONAL_PERIOD_MINUTES = 15;
    const int ADDITIONAL_PERIOD_COST = 3000; // 3k/15p

    if (durationMinutes <= FIRST_PERIOD_MINUTES) {
      return FIRST_PERIOD_COST;
    }

    int remainingMinutes = durationMinutes - FIRST_PERIOD_MINUTES;
    int additionalPeriods = (remainingMinutes / ADDITIONAL_PERIOD_MINUTES).ceil();
    return FIRST_PERIOD_COST + (additionalPeriods * ADDITIONAL_PERIOD_COST);
  }

  // ✅ CHECK BALANCE >= 20k
  Future<bool> canRentBike(String userId) async {
    try {
      var doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        int balance = doc['balance'] ?? 0;
        return balance >= 20000;
      }
      return false;
    } catch (e) {
      print("❌ Lỗi check balance: $e");
      return false;
    }
  }

  // ✅ THANH TOÁN CHUYẾN ĐI (LOGIC CHÍNH)
  Future<Map<String, dynamic>> processTrip({
    required String userId,
    required String bikeId,
    required int durationMinutes,
    required String stationId,
    int? voucherDiscount,
    bool usePoints = false,
  }) async {
    try {
      var userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw Exception("❌ User không tìm thấy");

      // 1️⃣ CHECK VÉ THÁNG
      bool hasMembership = await hasActiveMembership(userId);
      int baseCost = calculateCost(durationMinutes, hasMembership);

      int finalCost = baseCost;
      int voucherDiscountAmount = voucherDiscount ?? 0;
      int pointsUsed = 0;
      int pointsEarned = 0;
      int currentBalance = userDoc['balance'] ?? 0;
      int currentPoints = userDoc['points'] ?? 0;

      print("📊 ===== TÍNH TOÁN THANH TOÁN =====");
      print("⏱️ Thời gian: $durationMinutes phút");
      print("🎟️ Có vé tháng: $hasMembership");
      print("💰 Chi phí gốc: ${baseCost}đ");

      // 2️⃣ NẾU KHÔNG CÓ VÉ THÁNG - TÍNH PHỤ PHÍ & ÁP DỤNG VOUCHER
      if (!hasMembership) {
        // Áp dụng voucher nếu có
        if (voucherDiscountAmount > 0) {
          finalCost -= voucherDiscountAmount;
          if (finalCost < 0) finalCost = 0;
          print("🎁 Giảm giá voucher: -${voucherDiscountAmount}đ");
        }

        // Sử dụng điểm tích lũy (1000 điểm = 1000 VNĐ)
        if (usePoints && finalCost > 0) {
          pointsUsed = min(currentPoints, finalCost);
          finalCost -= pointsUsed;
          print("⭐ Sử dụng điểm: -${pointsUsed}đ");
        }

        // 3️⃣ KIỂM TRA ĐỦ SỐ DƯ
        if (currentBalance < finalCost) {
          throw Exception("❌ Số dư ví không đủ! Thiếu ${finalCost - currentBalance}đ");
        }

        // 4️⃣ TRỪ TIỀN TỪ VÍ
        await _firestore.collection('users').doc(userId).update({
          'balance': FieldValue.increment(-finalCost),
        });
        print("💳 Trừ tiền ví: -${finalCost}đ");
      } else {
        print("✅ Miễn phí vé tháng - không trừ tiền");
      }

      // 5️⃣ TÍNH ĐIỂM TÍCH LŨY (100 điểm / 10k chi tiêu thực tế)
      pointsEarned = (finalCost / 100).floor();
      await _firestore.collection('users').doc(userId).update({
        'points': FieldValue.increment(pointsEarned),
      });
      print("🎯 Tích lũy điểm: +${pointsEarned} pts");

      // 6️⃣ GHI LẠI CHUYẾN ĐI
      var tripRef = _firestore.collection('trips').doc();
      await tripRef.set({
        'id': tripRef.id,
        'userId': userId,
        'bikeId': bikeId,
        'startTime': FieldValue.serverTimestamp(),
        'endTime': FieldValue.serverTimestamp(),
        'duration': durationMinutes,
        'baseCost': baseCost,
        'cost': finalCost,
        'paymentType': hasMembership ? 'membership' : 'wallet',
        'voucherUsed': voucherDiscountAmount,
        'pointsUsed': pointsUsed,
        'pointsEarned': pointsEarned,
        'stationId': stationId,
        'status': 'completed',
        'rating': 0,
        'feedback': '',
      });

      // 7️⃣ GHI LẠI TRANSACTION
      await _firestore.collection('transactions').add({
        'userId': userId,
        'type': hasMembership ? 'membership_benefit' : 'trip_payment',
        'amount': finalCost,
        'timestamp': FieldValue.serverTimestamp(),
        'relatedTripId': tripRef.id,
        'voucherUsed': voucherDiscountAmount,
        'pointsUsed': pointsUsed,
      });

      print("✅ Lưu chuyến đi: ${tripRef.id}");
      print("===============================\n");

      return {
        'success': true,
        'tripId': tripRef.id,
        'baseCost': baseCost,
        'finalCost': finalCost,
        'voucherDiscount': voucherDiscountAmount,
        'pointsUsed': pointsUsed,
        'pointsEarned': pointsEarned,
        'hasMembership': hasMembership,
      };
    } catch (e) {
      print("❌ Lỗi processTrip: $e");
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ✅ CẬP NHẬT RATING & FEEDBACK
  Future<void> submitRating(
    String tripId,
    int rating,
    String feedback,
  ) async {
    try {
      await _firestore.collection('trips').doc(tripId).update({
        'rating': rating,
        'feedback': feedback,
      });
      print("✅ Cập nhật rating: $rating ⭐");
    } catch (e) {
      print("❌ Lỗi cập nhật rating: $e");
    }
  }
}