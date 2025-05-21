import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VesselWavePainter extends StatefulWidget {
  final double waveLength;    // 0 à 200
  final double waveDirection; // en degrés
  final double wavePeriod;    // 1 à 60

  const VesselWavePainter({
    super.key,
    required this.waveLength,
    required this.waveDirection,
    required this.wavePeriod,
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
    return CustomPaint(
      size: const Size(300, 300),
      painter: boatImage == null
          ? null
          : _CompassPainter(
        waveDirection: widget.waveDirection,
        waveLength: widget.waveLength,
        wavePeriod: widget.wavePeriod,
        boatImage: boatImage!,
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double waveDirection;
  final double waveLength;
  final double wavePeriod;
  final ui.Image boatImage;

  _CompassPainter({
    required this.waveDirection,
    required this.waveLength,
    required this.wavePeriod,
    required this.boatImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    final gradient = RadialGradient(
      colors: [Colors.blue.shade100, Colors.white],
      center: Alignment.center,
      radius: 0.85,
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paintCircle = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final paintArrow = Paint()
      ..color = Color(0xFF012169)
      ..style = PaintingStyle.fill;

    final paintWaveLines = Paint()
      ..color = Colors.blue.shade300.withOpacity(0.4)
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
      );
      textPainter.layout();

      // Pour compenser la rotation globale, on applique une rotation inverse au texte
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(pi / 2); // Rotation inverse de 90°
      canvas.translate(-x, -y);
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
      canvas.restore();
    }

    // Masque circulaire pour les lignes de houle
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save(); // Enregistrer l'état du canvas
    canvas.clipPath(clipPath); // Appliquer le masque

    // Direction et espacement de la houle
    final waveAngleForWaves = (waveDirection - 90) * pi / 180;
    final waveAngleForArrow = waveDirection * pi / 180; // flèche inchangée
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

    canvas.restore(); // Restaurer le canvas pour enlever le clip

    // Affichage de l'image du bateau
    final imageWidth = waveLength.clamp(40.0, 200.0);
    final imageHeight = imageWidth * boatImage.height / boatImage.width;

    final dstRect = Rect.fromCenter(
      center: center,
      width: imageWidth,
      height: imageHeight,
    );

    final srcRect = Rect.fromLTWH(0, 0, boatImage.width.toDouble(), boatImage.height.toDouble());

    // Dessiner l'image du bateau
    canvas.drawImageRect(boatImage, srcRect, dstRect, Paint());

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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
