import 'dart:math';
import 'package:flutter/material.dart';

class RiskPolarPlot extends StatelessWidget {
  final double vesselLengthM;
  final double rollNaturalPeriodS;
  final double periodUncertaintyS;
  final double vesselSpeedKnots;
  final double courseDeg;
  final double waveDirectionDeg;
  final double meanWavePeriodS;

  const RiskPolarPlot({
    super.key,
    required this.vesselLengthM,
    required this.rollNaturalPeriodS,
    required this.periodUncertaintyS,
    required this.vesselSpeedKnots,
    required this.courseDeg,
    required this.waveDirectionDeg,
    required this.meanWavePeriodS,
  });

  @override
  Widget build(BuildContext context) {
    final speeds = List.generate(251, (i) => i * 0.1); // 0.0 à 25.0
    final angles = List.generate(721, (i) => i * 2 * pi / 720); // 0 à 2pi

    final parametricRiskMask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));
    final resonantRiskMask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));

    bool isParametricRiskHead = false;
    bool isParametricRiskFollow = false;
    bool isResonantRisk = false;

    for (int i = 0; i < speeds.length; i++) {
      for (int j = 0; j < angles.length; j++) {
        final risks = calculateRisks(angles[j] * 180 / pi, speeds[i], meanWavePeriodS);
        if (risks.parametricHead || risks.parametricFollow) {
          parametricRiskMask[i][j] = true;
        }
        if (risks.resonant) {
          resonantRiskMask[i][j] = true;
        }
      }
    }

    final risksCurrent = calculateRisks(courseDeg, vesselSpeedKnots, meanWavePeriodS);
    isParametricRiskHead = risksCurrent.parametricHead;
    isParametricRiskFollow = risksCurrent.parametricFollow;
    isResonantRisk = risksCurrent.resonant;

    // Déterminer message et couleur
    String riskMessage = "No significant roll risk detected.";
    Color riskColor = Colors.black;

    if (isParametricRiskHead) {
      riskMessage = "⚠️ Parametric roll risk - head seas";
      riskColor = Colors.deepPurple;
    } else if (isParametricRiskFollow) {
      riskMessage = "⚠️ Parametric roll risk - following seas";
      riskColor = Colors.deepPurple;
    } else if (isResonantRisk) {
      riskMessage = "⚠️ Resonant roll risk";
      riskColor = Colors.teal;
    }

    return Center( // <--- Centre horizontalement et verticalement
      child: SingleChildScrollView( // au cas où le contenu dépasse verticalement
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // <--- Centrage vertical
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(350, 350),
              painter: PolarPlotPainter(
                speeds: speeds,
                angles: angles,
                parametricRiskMask: parametricRiskMask,
                resonantRiskMask: resonantRiskMask,
                currentCourseDeg: courseDeg,
                currentSpeed: vesselSpeedKnots,
                isParametricRiskHead: isParametricRiskHead,
                isParametricRiskFollow: isParametricRiskFollow,
                isResonantRisk: isResonantRisk,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LegendItem(color: Colors.deepPurple.withOpacity(0.6), label: "Parametric roll risk"),
                const SizedBox(width: 16),
                LegendItem(color: Colors.teal.withOpacity(0.6), label: "Resonant roll risk"),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              riskMessage,
              style: TextStyle(fontSize: 14, color: riskColor, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }




  RiskResults calculateRisks(double courseDeg, double vesselSpeedKnots, double meanWavePeriodS) {
    double relativeWaveDirectionDeg = (waveDirectionDeg - courseDeg) % 360;

    double effectiveWaveLengthM;
    if (relativeWaveDirectionDeg < 89 || relativeWaveDirectionDeg > 91) {
      effectiveWaveLengthM = 1.56 *
          pow(1.198 * meanWavePeriodS, 2) /
          (cos(relativeWaveDirectionDeg * pi / 180)).abs();
    } else {
      effectiveWaveLengthM = 1000;
    }

    double waveEncounterPeriodS = 3 * pow(1.198 * meanWavePeriodS, 2) /
        (3 * 1.198 * meanWavePeriodS + vesselSpeedKnots * cos(relativeWaveDirectionDeg * pi / 180));

    double rollToEncounterPeriodRatio = rollNaturalPeriodS / waveEncounterPeriodS;
    double waveLengthToShipLengthRatio = effectiveWaveLengthM / vesselLengthM;

    double upperRatioLimit = (rollNaturalPeriodS + periodUncertaintyS) / waveEncounterPeriodS + 0.3;
    double lowerRollPeriodS = rollNaturalPeriodS - periodUncertaintyS;
    double lowerRatioLimit = (lowerRollPeriodS / waveEncounterPeriodS) - 0.3;

    bool conditionRatioResonantRoll = (upperRatioLimit >= 1) && (lowerRatioLimit <= 1);
    bool conditionWaveLengthResonantRoll = waveLengthToShipLengthRatio >= (1 / 3);
    bool riskResonant = conditionRatioResonantRoll && conditionWaveLengthResonantRoll;

    bool conditionRatioParametricRoll = (upperRatioLimit >= 2) && (lowerRatioLimit <= 2);
    bool conditionWaveLengthParametricRoll = waveLengthToShipLengthRatio >= 0.5 && waveLengthToShipLengthRatio <= 2;

    bool conditionWaveDirectionHeadSeas = relativeWaveDirectionDeg <= 60;
    bool conditionWaveDirectionFollowingSeas = relativeWaveDirectionDeg >= 105;

    bool riskParametricHead = conditionRatioParametricRoll && conditionWaveLengthParametricRoll && conditionWaveDirectionHeadSeas;
    bool riskParametricFollow = conditionRatioParametricRoll && conditionWaveLengthParametricRoll && conditionWaveDirectionFollowingSeas;

    return RiskResults(riskParametricHead, riskParametricFollow, riskResonant);
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}


class RiskResults {
  final bool parametricHead;
  final bool parametricFollow;
  final bool resonant;

  RiskResults(this.parametricHead, this.parametricFollow, this.resonant);
}

class PolarPlotPainter extends CustomPainter {
  final List<double> speeds;
  final List<double> angles;
  final List<List<bool>> parametricRiskMask;
  final List<List<bool>> resonantRiskMask;
  final double currentCourseDeg;
  final double currentSpeed;
  final bool isParametricRiskHead;
  final bool isParametricRiskFollow;
  final bool isResonantRisk;

  PolarPlotPainter({
    required this.speeds,
    required this.angles,
    required this.parametricRiskMask,
    required this.resonantRiskMask,
    required this.currentCourseDeg,
    required this.currentSpeed,
    required this.isParametricRiskHead,
    required this.isParametricRiskFollow,
    required this.isResonantRisk,
  });

  final double maxRadius = 25; // max vitesse noeuds
  final double margin = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;  // exemple

    // Dessiner cercles concentriques (grilles radiales)
    final Paint gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke;

    for (double v = 0; v <= maxRadius; v += 5) {
      double r = (v / maxRadius) * radius;
      canvas.drawCircle(center, r, gridPaint);

      // Etiquettes vitesse
      final textPainter = TextPainter(
          text: TextSpan(
              text: "${v.toInt()} kt",
              style: TextStyle(color: Colors.black, fontSize: 8)),
          textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + 5, center.dy - r - 5));
    }

    // Dessiner lignes angulaires et labels (12 labels)
    final List<int> angleLabelsDeg = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330];
    final List<String> angleLabelsText = [
      "North", "30°", "60°", "East", "120°", "150°",
      "South", "210°", "240°", "West", "300°", "330°"
    ];

    final Paint angleLinePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < angleLabelsDeg.length; i++) {
      double angleRad = (angleLabelsDeg[i] - 90) * pi / 180; // Nord en haut

      // Ligne du centre vers extérieur
      canvas.drawLine(
          center,
          center + Offset(cos(angleRad), sin(angleRad)) * radius,
          angleLinePaint);

      // Texte à l'extérieur
      final textPainter = TextPainter(
          text: TextSpan(
              text: angleLabelsText[i],
              style: TextStyle(color: Colors.black, fontSize: 12,fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr);
      textPainter.layout();

      final labelOffset = center + Offset(cos(angleRad), sin(angleRad)) * (radius + 20);

      textPainter.paint(
          canvas,
          labelOffset - Offset(textPainter.width / 2, textPainter.height / 2));
    }

    // Fonction pour convertir (angle en degrés, vitesse) en Offset
    Offset polarToCartesian(double angleDeg, double speed) {
      double angleRad = (angleDeg - 90) * pi / 180; // nord en haut
      double r = (speed / maxRadius) * radius;
      return center + Offset(cos(angleRad), sin(angleRad)) * r;
    }

    // Afficher zones de risque

    // Parametric roll (rouge translucide)
    Paint parametricPaint = Paint()
      ..color = Colors.deepPurple.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Resonant roll (orange translucide)
    Paint resonantPaint = Paint()
      ..color = Colors.teal.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Dessiner zones sous forme de petits polygones (carte de pixels)
    // Pour performance on peut dessiner des cercles ou points

    double stepAngle = 2 * pi / (angles.length - 1);
    double stepSpeed = maxRadius / (speeds.length - 1);

    // Pour éviter trop de dessin, on dessine par groupes (ex: chaque 5 index)

    void drawRiskZone(Canvas canvas, List<List<bool>> mask, Paint paint) {
      for (int j = 0; j < angles.length - 1; j++) {
        Path path = Path();
        bool started = false;

        for (int i = 0; i < speeds.length; i++) {
          if (mask[i][j]) {
            Offset p = polarToCartesian(angles[j] * 180 / pi, speeds[i]);
            if (!started) {
              path.moveTo(p.dx, p.dy);
              started = true;
            } else {
              path.lineTo(p.dx, p.dy);
            }
          }
        }

        // Redescendre pour fermer la forme (si besoin)
        for (int i = speeds.length - 1; i >= 0; i--) {
          if (mask[i][j + 1]) {
            Offset p = polarToCartesian(angles[j + 1] * 180 / pi, speeds[i]);
            path.lineTo(p.dx, p.dy);
          }
        }

        if (started) {
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }

    drawRiskZone(canvas, parametricRiskMask, parametricPaint);
    drawRiskZone(canvas, resonantRiskMask, resonantPaint);


    // Dessiner triangle pour la position actuelle

    Paint trianglePaint = Paint()
      ..color = (isParametricRiskHead || isParametricRiskFollow)
          ? Colors.deepPurple
          : (isResonantRisk ? Colors.teal : Colors.green)
      ..style = PaintingStyle.fill;

    Paint triangleStroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    Offset centerTriangle = polarToCartesian(currentCourseDeg, currentSpeed);

    // Dessiner triangle pointant vers le cap (rotation)

    // paramètres de taille et de forme
    final double triangleHeight = 16;
    final double triangleBase = 14;

    final double angleRad = (currentCourseDeg - 90) * pi / 180;
    final Offset apex = centerTriangle + Offset(
      triangleHeight * cos(angleRad),
      triangleHeight * sin(angleRad),
    );
    final Offset baseLeft = centerTriangle + Offset(
      -triangleBase / 2 * sin(angleRad),
      triangleBase / 2 * cos(angleRad),
    );
    final Offset baseRight = centerTriangle + Offset(
      triangleBase / 2 * sin(angleRad),
      -triangleBase / 2 * cos(angleRad),
    );

// Path du triangle isocèle
    final Path trianglePath = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(baseLeft.dx, baseLeft.dy)
      ..lineTo(baseRight.dx, baseRight.dy)
      ..close();

// Contour noir plus épais et doux
    final Paint outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

// Remplissage coloré
    final Paint fillPaint = Paint()
      ..color = (isParametricRiskHead || isParametricRiskFollow)
          ? Colors.deepPurple
          : (isResonantRisk ? Colors.teal : Colors.green)
      ..style = PaintingStyle.fill;

// Dessin sur le canvas
    canvas.drawPath(trianglePath, fillPaint);
    canvas.drawPath(trianglePath, outlinePaint);



  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}