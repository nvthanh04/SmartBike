import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Widget hiển thị icon marker cho trạm xe đạp
/// Hình tròn nền cam, bên trong có icon xe đạp màu đen
class StationMarkerIcon extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;

  const StationMarkerIcon({
    super.key,
    this.size = 32,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          // Gradient cam sáng → cam đậm
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF9800), // Cam sáng
              Color(0xFFF57C00), // Cam đậm
            ],
          ),
          shape: BoxShape.circle,
          // Viền trắng để nổi bật trên bản đồ
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
          // Đổ bóng nhẹ
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.directions_bike,
          color: Colors.black87,
          size: size * 0.6,
        ),
      ),
    );
  }

  /// Tạo BitmapDescriptor từ Canvas để dùng với google_maps_flutter
  /// (Dành cho trường hợp bạn chuyển sang Google Maps sau này)
  ///
  /// Cách dùng:
  /// ```dart
  /// final icon = await StationMarkerIcon.createBitmapDescriptor(size: 80);
  /// Marker(icon: icon, ...);
  /// ```
  static Future<ui.Image> createMarkerImage({double size = 80}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size, size),
        [const Color(0xFFFF9800), const Color(0xFFF57C00)],
      );

    // Vẽ viền trắng
    final borderPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      borderPaint,
    );

    // Vẽ hình tròn cam
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 6,
      paint,
    );

    // Vẽ biểu tượng xe đạp
    final iconPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.035;

    // Vẽ 2 bánh xe
    final wheelRadius = size * 0.13;
    final leftWheelCenter = Offset(size * 0.32, size * 0.62);
    final rightWheelCenter = Offset(size * 0.68, size * 0.62);

    canvas.drawCircle(leftWheelCenter, wheelRadius, iconPaint);
    canvas.drawCircle(rightWheelCenter, wheelRadius, iconPaint);

    // Vẽ khung xe
    final framePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.04
      ..strokeCap = StrokeCap.round;

    final seatTop = Offset(size * 0.42, size * 0.38);
    final handlebar = Offset(size * 0.62, size * 0.38);
    final pedal = Offset(size * 0.50, size * 0.58);

    // Khung chính
    canvas.drawLine(seatTop, pedal, framePaint);
    canvas.drawLine(pedal, rightWheelCenter, framePaint);
    canvas.drawLine(handlebar, rightWheelCenter, framePaint);
    canvas.drawLine(seatTop, leftWheelCenter, framePaint);
    canvas.drawLine(pedal, leftWheelCenter, framePaint);
    canvas.drawLine(seatTop, handlebar, framePaint);

    // Tay lái
    canvas.drawLine(
      handlebar,
      Offset(handlebar.dx + size * 0.04, handlebar.dy - size * 0.06),
      framePaint,
    );

    // Yên xe
    canvas.drawLine(
      seatTop,
      Offset(seatTop.dx - size * 0.04, seatTop.dy - size * 0.02),
      framePaint,
    );

    final picture = recorder.endRecording();
    return picture.toImage(size.toInt(), size.toInt());
  }
}
