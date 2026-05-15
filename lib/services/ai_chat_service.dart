import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'station_data_provider.dart';

/// Service Chatbot Offline (Rule-based) thay thế cho Gemini để tránh lỗi API/Quota
class AiChatService {
  final StationDataProvider _stationData = StationDataProvider();

  AiChatService();

  void resetConversation() {
    // Không cần reset state cho local bot
  }

  /// Xử lý logic rule-based (tìm từ khóa)
  Future<Map<String, dynamic>> sendMessage(String text) async {
    final lower = text.toLowerCase();
    String response = '';
    bool needsForward = false;

    // 1. Chào hỏi
    if (lower.contains('chào') || lower.contains('hello') || lower.contains('hi')) {
      response = 'Chào bạn! Mình là SmartBike Assistant. Mình có thể giúp gì cho bạn: tìm trạm xe gần nhất, kiểm tra giá vé hay thông tin thành viên?';
    }
    // 2. Hỏi giá vé / thanh toán
    else if (lower.contains('giá') || lower.contains('tiền') || lower.contains('phí') || lower.contains('vé')) {
      response = '💰 Giá thuê xe SmartBike:\n- 10.000đ cho 60 phút đầu tiên.\n- Thêm 3.000đ cho mỗi 15 phút tiếp theo.\n- Vé lượt: 59.000đ/ngày.\n- Vé tháng: 159.000đ/30 ngày.\nLưu ý: Bạn cần có tối thiểu 20.000đ trong số dư để bắt đầu chuyến đi!';
    }
    // 3. Hỏi điểm thưởng / hạng thành viên
    else if (lower.contains('điểm') || lower.contains('hạng') || lower.contains('thành viên') || lower.contains('vip') || lower.contains('kim cương')) {
      response = '⭐ Hệ thống điểm & Ưu đãi hạng:\n- Cơ bản (<1000đ): Không giảm giá\n- Bạc (1000 - 4999đ): Giảm 5% cước phí\n- Vàng (5000 - 9999đ): Giảm 10% cước phí\n- Kim Cương (≥10000đ): Giảm 15% cước phí.\nBạn có thể dùng điểm đổi Voucher giảm 50% (tốn 5000 điểm) hoặc tặng 10.000đ vào ví (tốn 10000 điểm).';
    }
    // 4. Cách thuê xe / trả xe
    else if (lower.contains('thuê') || lower.contains('mở khóa') || lower.contains('quét') || lower.contains('qr') || lower.contains('trả xe')) {
      response = '📱 Hướng dẫn sử dụng:\n- Thuê xe: Nhấn nút "QUÉT ĐỂ THUÊ" trên màn hình chính, quét mã QR trên ổ khóa xe và bấm xác nhận.\n- Trả xe: Đạp xe đến bất kỳ trạm SmartBike nào, chọn "Trả xe" trên ứng dụng và gạt khóa thủ công, hệ thống sẽ tự động tính phí.';
    }
    // 5. Nạp tiền
    else if (lower.contains('nạp')) {
      response = '💳 Hướng dẫn nạp tiền: Vào tab "Tôi" -> Chọn "NẠP TIỀN" -> Chọn mệnh giá và thanh toán dễ dàng qua thẻ ATM (Napas) hoặc ví điện tử MoMo.';
    }
    // 6. Hotline / CSKH
    else if (lower.contains('hotline') || lower.contains('tổng đài') || lower.contains('số điện thoại') || lower.contains('liên hệ') || lower.contains('cskh')) {
      response = '📞 Liên hệ Hỗ trợ Khách hàng SmartBike:\n- Tổng đài: 1900-BIKE (1900-2453)\n- Email: support@smartbike.vn\nBạn cần gọi hỗ trợ khẩn cấp không?';
    }
    // 7. Tìm trạm gần nhất (ưu tiên "trạm gần", "xe gần")
    else if (lower.contains('gần') && (lower.contains('trạm') || lower.contains('xe') || lower.contains('đâu'))) {
      response = await _handleNearestStationRequest();
    }
    // 8. Danh sách tất cả trạm / kiểm tra còn xe không
    else if (lower.contains('trạm') || lower.contains('xe') || lower.contains('còn')) {
      try {
        final summary = await _stationData.getStationSummary();
        if (summary.isNotEmpty) {
          response = '🚲 Đây là thông tin tổng quan các trạm lúc này:\n$summary';
        } else {
          response = 'Xin lỗi, hiện tại mình không lấy được dữ liệu trạm.';
        }
      } catch (e) {
        response = 'Xin lỗi, mình không kết nối được hệ thống trạm lúc này.';
      }
    }
    // 9. Không hiểu -> Forward to Admin
    else {
      response = 'Xin lỗi, câu hỏi "$text" hiện tại hơi khó với mình. Mình đã lưu lại và gửi thẳng trực tiếp đến Admin, bộ phận hỗ trợ sẽ sớm trả lời bạn trong mục "Hỗ trợ" nhé!';
      needsForward = true;
      await _forwardToAdmin(text, response);
    }

    // Giả lập độ trễ phản hồi của AI (cho giống thật)
    await Future.delayed(const Duration(milliseconds: 700));

    return {
      'response': response,
      'needsForward': needsForward,
    };
  }

  /// Lấy vị trí user và tìm trạm gần nhất
  Future<String> _handleNearestStationRequest() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Để tìm trạm gần nhất, bạn cần bật Dịch vụ định vị (GPS) trên thiết bị nhé!';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Bạn chưa cấp quyền vị trí nên mình không biết bạn đang ở đâu. Bạn vui lòng cấp quyền định vị trong máy để mình tìm trạm nhé.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return 'Quyền vị trí bị từ chối vĩnh viễn. Bạn hãy vào Cài đặt điện thoại để mở lại nhé.';
      }

      // Lấy tọa độ hiện tại
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Tính khoảng cách
      final nearestInfo = await _stationData.getNearestStation(
        position.latitude,
        position.longitude,
      );
      
      return '📍 Trạm xe SmartBike gần bạn nhất là:\n$nearestInfo\nBạn có thể tới trạm này để nhận xe ngay nhé!';
    } catch (e) {
      debugPrint('Lỗi tìm trạm gần nhất: $e');
      return 'Xin lỗi, đã xảy ra lỗi khi xác định vị trí của bạn.';
    }
  }

  Future<void> _forwardToAdmin(String question, String botResponse) async {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'Người dùng';
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (doc.exists) {
          userName = (doc.data() as Map<String, dynamic>)['name'] ?? 'Người dùng';
        }
      } catch (_) {}
    }

    try {
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': user?.uid ?? 'anonymous',
        'userName': userName,
        'userEmail': user?.email ?? '',
        'question': question,
        'botResponse': botResponse,
        'adminResponse': null,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'answeredAt': null,
      });
    } catch (e) {
      debugPrint('Lỗi tạo ticket: $e');
    }
  }
}
