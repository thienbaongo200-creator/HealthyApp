import 'dart:math';
import 'package:flutter/material.dart';

/// CustomPainter vẽ nền bầu trời gradient + mây trắng + lá cây trang trí
class SkyBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawSkyGradient(canvas, size);
    _drawClouds(canvas, size);
    _drawLeaves(canvas, size);
    _drawSunGlow(canvas, size);
  }

  void _drawSkyGradient(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(
          0xFF81C784,
        ).withValues(alpha: 0.3), // Xanh lá pastel trên cùng
        const Color(0xFFA5D6A7).withValues(alpha: 0.25),
        const Color(0xFFC8E6C9).withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.15),
        const Color(0xFFE8F5E9).withValues(alpha: 0.1),
      ],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawClouds(Canvas canvas, Size size) {
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Mây lớn trên đỉnh - bên trái
    _drawCloud(canvas, size.width * 0.1, size.height * 0.08, 60, cloudPaint);
    // Mây lớn trên đỉnh - bên phải
    _drawCloud(canvas, size.width * 0.65, size.height * 0.12, 50, cloudPaint);
    // Mây nhỏ giữa
    _drawCloud(canvas, size.width * 0.35, size.height * 0.18, 35, cloudPaint);
    // Mây nhỏ dưới
    _drawCloud(canvas, size.width * 0.75, size.height * 0.28, 30, cloudPaint);
    // Mây siêu nhỏ xa
    _drawCloud(canvas, size.width * 0.5, size.height * 0.05, 25, cloudPaint);
  }

  void _drawCloud(Canvas canvas, double x, double y, double size, Paint paint) {
    canvas.drawCircle(Offset(x, y), size * 0.5, paint);
    canvas.drawCircle(
      Offset(x + size * 0.4, y - size * 0.15),
      size * 0.35,
      paint,
    );
    canvas.drawCircle(
      Offset(x - size * 0.3, y + size * 0.1),
      size * 0.3,
      paint,
    );
    canvas.drawCircle(
      Offset(x + size * 0.2, y + size * 0.15),
      size * 0.25,
      paint,
    );
    canvas.drawCircle(
      Offset(x + size * 0.6, y + size * 0.05),
      size * 0.28,
      paint,
    );

    // Làm mịn phần dưới đám mây
    final rect = Rect.fromLTWH(x - size * 0.4, y, size * 1.2, size * 0.3);
    canvas.drawRect(rect, paint);
  }

  void _drawLeaves(Canvas canvas, Size size) {
    final random = Random(42); // Fixed seed để vẽ nhất quán
    final leafPaint = Paint()..style = PaintingStyle.fill;

    // Danh sách màu xanh lá cho lá
    const leafColors = [
      Color(0xFF4CAF50),
      Color(0xFF66BB6A),
      Color(0xFF43A047),
      Color(0xFF388E3C),
      Color(0xFF2E7D32),
      Color(0xFF81C784),
    ];

    // Vẽ lá cây ở các góc
    final leafPositions = [
      // Góc trên bên phải
      Offset(size.width * 0.85, size.height * 0.02),
      Offset(size.width * 0.92, size.height * 0.06),
      Offset(size.width * 0.88, size.height * 0.1),
      // Góc dưới bên trái
      Offset(size.width * 0.05, size.height * 0.85),
      Offset(size.width * 0.02, size.height * 0.92),
      Offset(size.width * 0.1, size.height * 0.88),
      // Góc dưới bên phải
      Offset(size.width * 0.92, size.height * 0.85),
      Offset(size.width * 0.88, size.height * 0.92),
      // Góc trên bên trái
      Offset(size.width * 0.08, size.height * 0.02),
      Offset(size.width * 0.15, size.height * 0.05),
    ];

    for (int i = 0; i < leafPositions.length; i++) {
      final pos = leafPositions[i];
      final color = leafColors[i % leafColors.length];
      leafPaint.color = color.withValues(
        alpha: 0.25 + random.nextDouble() * 0.25,
      );

      final leafSize = 14.0 + random.nextDouble() * 18;
      final angle = random.nextDouble() * pi * 2;
      final curve = random.nextDouble() * 0.5 + 0.3;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      _drawSingleLeaf(canvas, leafSize, curve, leafPaint);
      canvas.restore();
    }
  }

  void _drawSingleLeaf(Canvas canvas, double size, double curve, Paint paint) {
    final path = Path();
    path.moveTo(0, 0);
    path.cubicTo(size * 0.3, -size * curve, size * 0.7, -size * curve, size, 0);
    path.cubicTo(
      size * 0.7,
      size * curve * 0.5,
      size * 0.3,
      size * curve * 0.5,
      0,
      0,
    );
    canvas.drawPath(path, paint);

    // Vẽ gân lá
    final veinPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final veinPath = Path();
    veinPath.moveTo(0, 0);
    veinPath.quadraticBezierTo(size * 0.5, -size * 0.1, size, 0);
    canvas.drawPath(veinPath, veinPaint);
  }

  void _drawSunGlow(Canvas canvas, Size size) {
    // Vẽ hiệu ứng ánh sáng dịu từ góc trên phải
    final glowCenter = Offset(size.width * 0.85, size.height * 0.05);
    final glowGradient = RadialGradient(
      colors: [
        const Color(0xFFFFF9C4).withValues(alpha: 0.3), // Ánh nắng vàng nhạt
        const Color(0xFFFFF9C4).withValues(alpha: 0.1),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    );

    final glowPaint = Paint()
      ..shader = glowGradient.createShader(
        Rect.fromCircle(center: glowCenter, radius: 200),
      );
    canvas.drawCircle(glowCenter, 200, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget nền bầu trời có thể dùng lại
class SkyBackground extends StatelessWidget {
  final Widget child;

  const SkyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Nền gradient chính
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE8F5E9), // Xanh lá siêu nhạt (trên)
                Color(0xFFC8E6C9), // Xanh lá pastel
                Color(0xFFA5D6A7), // Xanh lá nhạt
                Color(0xFF81C784), // Xanh lá tươi
                Color(0xFF66BB6A), // Xanh lá trung bình
              ],
            ),
          ),
        ),
        // Hiệu ứng mây và lá
        CustomPaint(painter: SkyBackgroundPainter(), size: Size.infinite),
        // Nội dung chính
        child,
      ],
    );
  }
}
