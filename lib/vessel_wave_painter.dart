// vessel_wave_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VesselWavePainter extends StatefulWidget {
  final double boatlength;
  final double waveDirection;
  final double wavePeriod;
  final double course;
  final bool isDarkMode; // Nouveau paramètre pour le dark mode

  const VesselWavePainter({
    super.key,
    required this.boatlength,
    required this.waveDirection,
    required this.wavePeriod,
    required this.course,
    required this.isDarkMode, // Ajout du paramètre
  });

  @override
  State<VesselWavePainter> createState() => _VesselWavePainterState();
}

class _VesselWavePainterState extends State<VesselWavePainter> {
  ui.Image? boatImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load('assets/images/boat.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    setState(() {
      boatImage = frame.image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth - 20;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Transform.rotate(
                angle: -90 * (pi / 180),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: boatImage == null
                        ? null
                        : _CompassPainter(
                      waveDirection: widget.waveDirection,
                      boatlength: widget.boatlength,
                      wavePeriod: widget.wavePeriod,
                      course: widget.course,
                      boatImage: boatImage!,
                      isDarkMode: widget.isDarkMode, // Passage du paramètre
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double waveDirection;
  final double boatlength;
  final double wavePeriod;
  final double course;
  final ui.Image boatImage;
  final bool isDarkMode; // Nouveau paramètre

  _CompassPainter({
    required this.waveDirection,
    required this.boatlength,
    required this.wavePeriod,
    required this.course,
    required this.boatImage,
    required this.isDarkMode, // Ajout du paramètre
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Couleurs adaptées au dark mode
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final circleGradientColor1 = isDarkMode ? Colors.grey[800]! : Colors.blue.shade100;
    final circleGradientColor2 = isDarkMode ? Colors.grey[700]! : Colors.white;
    final borderColor = isDarkMode ? Colors.grey[600]! : Colors.grey.shade800;
    final waveLinesColor = isDarkMode
        ? Colors.teal.withOpacity(0.4)
        : Colors.blue.shade300.withOpacity(0.4);
    final textColor = isDarkMode ? Colors.grey[300]! : Colors.black87;
    final mainArrowColor = isDarkMode ? Colors.teal : const Color(0xFF012169);
    final courseArrowColor = Colors.deepPurple; // Gardé en rouge pour la visibilité

    final gradient = RadialGradient(
      colors: [circleGradientColor1, circleGradientColor2],
      center: Alignment.center,
      radius: 0.85,
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paintCircle = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final paintArrow = Paint()
      ..color = mainArrowColor
      ..style = PaintingStyle.fill;

    final paintWaveLines = Paint()
      ..color = waveLinesColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Fond
    canvas.drawCircle(center, radius, paintCircle);
    canvas.drawCircle(center, radius, paintBorder);

    // Marquage des angles toutes les 30°
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < 360; i += 30) {
      final angleRad = i * pi / 180;
      final x = center.dx + cos(angleRad) * (radius + 12);
      final y = center.dy + sin(angleRad) * (radius + 12);

      textPainter.text = TextSpan(
        text: '$i°',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
          color: textColor,
        ),
      );
      textPainter.layout();

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(pi / 2);
      canvas.translate(-x, -y);
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
      canvas.restore();
    }

    // Masque circulaire pour les lignes de houle
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipPath(clipPath);

    // Direction et espacement de la houle
    final waveAngleForWaves = (waveDirection - 90) * pi / 180;
    final waveAngleForArrow = waveDirection * pi / 180;
    final perpAngle = waveAngleForWaves + pi / 2;

    final dx = cos(perpAngle);
    final dy = sin(perpAngle);

    const minSpacing = 3.0;
    const maxSpacing = 60.0;
    final normalizedPeriod = (wavePeriod - 1) / 59;
    final spacing = minSpacing + normalizedPeriod * (maxSpacing - minSpacing);

    final maxOffset = radius * 1.5;
    final lineLength = radius * 2.5;

    for (double offset = -maxOffset; offset <= maxOffset; offset += spacing) {
      final cx = center.dx + dx * offset;
      final cy = center.dy + dy * offset;

      final start = Offset(
        cx - cos(waveAngleForWaves) * lineLength / 2,
        cy - sin(waveAngleForWaves) * lineLength / 2,
      );
      final end = Offset(
        cx + cos(waveAngleForWaves) * lineLength / 2,
        cy + sin(waveAngleForWaves) * lineLength / 2,
      );

      canvas.drawLine(start, end, paintWaveLines);
    }

    canvas.restore();

    // Affichage de l'image du bateau avec rotation selon la course
    final imageWidth = 60.0;
    final imageHeight = imageWidth * boatImage.height / boatImage.width;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((course) * pi / 180);
    canvas.translate(-center.dx, -center.dy);

    final dstRect = Rect.fromCenter(
      center: center,
      width: imageWidth,
      height: imageHeight,
    );

    final srcRect = Rect.fromLTWH(0, 0, boatImage.width.toDouble(), boatImage.height.toDouble());
    canvas.drawImageRect(boatImage, srcRect, dstRect, Paint());
    canvas.restore();

    // Flèche de direction de la houle
    final arrowLength = 20.0;
    final arrowX = center.dx + cos(waveAngleForArrow) * radius;
    final arrowY = center.dy + sin(waveAngleForArrow) * radius;

    final arrowPath = Path()
      ..moveTo(arrowX, arrowY)
      ..lineTo(
        arrowX + arrowLength * cos(waveAngleForArrow - pi / 6),
        arrowY + arrowLength * sin(waveAngleForArrow - pi / 6),
      )
      ..lineTo(
        arrowX + arrowLength * cos(waveAngleForArrow + pi / 6),
        arrowY + arrowLength * sin(waveAngleForArrow + pi / 6),
      )
      ..close();

    canvas.drawPath(arrowPath, paintArrow);

    // Flèche de direction du bateau (course)
    final paintCourseArrow = Paint()
      ..color = courseArrowColor
      ..style = PaintingStyle.fill;

    final courseAngle = course * pi / 180;
    final courseArrowX = center.dx + cos(courseAngle) * (radius);
    final courseArrowY = center.dy + sin(courseAngle) * (radius);

    final courseArrowPath = Path()
      ..moveTo(courseArrowX, courseArrowY)
      ..lineTo(
        courseArrowX + arrowLength * cos(courseAngle + pi - pi / 6),
        courseArrowY + arrowLength * sin(courseAngle + pi - pi / 6),
      )
      ..lineTo(
        courseArrowX + arrowLength * cos(courseAngle + pi + pi / 6),
        courseArrowY + arrowLength * sin(courseAngle + pi + pi / 6),
      )
      ..close();

    canvas.drawPath(courseArrowPath, paintCourseArrow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}