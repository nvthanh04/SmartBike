import 'dart:math';
import 'package:flutter/material.dart';

/// Widget hiển thị vị trí giống Google Maps:
/// - Chấm xanh với viền trắng
/// - Hình nón bán trong suốt chỉ hướng di chuyển
/// - Vòng tròn accuracy xung quanh
class LocationIndicator extends StatelessWidget {
  final double heading; // Góc hướng (độ), 0 = Bắc, 90 = Đông
  final double size;

  const LocationIndicator({
    super.key,
    required this.heading,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LocationIndicatorPainter(heading: heading),
      ),
    );
  }
}

class _LocationIndicatorPainter extends CustomPainter {
  final double heading;

  _LocationIndicatorPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Chuyển heading từ độ sang radian
    // heading: 0 = Bắc (lên trên), cần trừ 90 vì canvas 0° = phải
    final headingRad = (heading - 90) * pi / 180;

    // === 1. Vòng tròn accuracy (vòng xanh nhạt lớn) ===
    final accuracyPaint = Paint()
      ..color = const Color(0x1A4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, accuracyPaint);

    // === 2. Hình nón chỉ hướng ===
    final coneLength = radius * 0.85;
    final coneAngle = 40 * pi / 180; // Góc mở 40°

    final conePath = Path();
    conePath.moveTo(center.dx, center.dy);
    conePath.lineTo(
      center.dx + coneLength * cos(headingRad - coneAngle / 2),
      center.dy + coneLength * sin(headingRad - coneAngle / 2),
    );

    // Vẽ cung tròn ở đầu nón
    conePath.arcTo(
      Rect.fromCircle(center: center, radius: coneLength),
      headingRad - coneAngle / 2,
      coneAngle,
      false,
    );
    conePath.close();

    // Gradient cho nón: đậm ở gốc, nhạt dần ra ngoài
    final coneGradient = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x664285F4),
          const Color(0x224285F4),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coneLength));
    canvas.drawPath(conePath, coneGradient);

    // === 3. Viền trắng (vòng ngoài chấm xanh) ===
    final outerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.28, outerDotPaint);

    // Shadow nhẹ
    final shadowPaint = Paint()
      ..color = const Color(0x30000000)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center, radius * 0.27, shadowPaint);

    // === 4. Chấm xanh Google (chấm chính) ===
    final dotPaint = Paint()
      ..color = const Color(0xFF4285F4) // Google Blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.22, dotPaint);

    // Highlight nhỏ trên chấm xanh (tạo hiệu ứng 3D)
    final highlightPaint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.05, center.dy - radius * 0.05),
      radius * 0.10,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LocationIndicatorPainter oldDelegate) {
    return oldDelegate.heading != heading;
  }
}
