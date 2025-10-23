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
    final speeds = List.generate(251, (i) => i * 0.1);
    final angles = List.generate(721, (i) => i * 2 * pi / 720);

    // Masks for different risk levels
    final matchRatio2Mask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));
    final matchRatio19Mask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));
    final matchRatio18Mask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));
    final parametricRiskMask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));
    final matchRatio1Mask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));
    final matchRatio11Mask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));
    final matchRatio12Mask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));
    final resonantRiskMask = List.generate(
        speeds.length, (_) => List.generate(angles.length, (_) => false));

    bool isParametricRiskHead = false;
    bool isParametricRiskFollow = false;
    bool isResonantRisk = false;

    for (int i = 0; i < speeds.length; i++) {
      for (int j = 0; j < angles.length; j++) {
        final courseDeg = angles[j] * 180 / pi;
        final relativeWaveDirectionDeg = (waveDirectionDeg - courseDeg) % 360;
        final waveEncounterPeriodS = 3 * pow(1.198 * meanWavePeriodS, 2) /
            (3 * 1.198 * meanWavePeriodS + speeds[i] * cos(relativeWaveDirectionDeg * pi / 180));

        final ratio = rollNaturalPeriodS / waveEncounterPeriodS;

        final risks = calculateRisks(courseDeg, speeds[i], meanWavePeriodS);

        if (risks.parametricHead || risks.parametricFollow) {
          if (1.99 < ratio && ratio < 2.01) {
            matchRatio2Mask[i][j] = true;
          } else if (1.9 < ratio && ratio < 2.1) {
            matchRatio19Mask[i][j] = true;
          } else if (1.8 < ratio && ratio < 2.2) {
            matchRatio18Mask[i][j] = true;
          } else {
            parametricRiskMask[i][j] = true;
          }
        }

        if (risks.resonant) {
          if (0.99 <= ratio && ratio <= 1.01) {
            matchRatio1Mask[i][j] = true;
          } else if (0.9 <= ratio && ratio <= 1.1) {
            matchRatio11Mask[i][j] = true;
          } else if (0.8 <= ratio && ratio <= 1.2) {
            matchRatio12Mask[i][j] = true;
          } else {
            resonantRiskMask[i][j] = true;
          }
        }
      }
    }

    final risksCurrent = calculateRisks(courseDeg, vesselSpeedKnots, meanWavePeriodS);
    isParametricRiskHead = risksCurrent.parametricHead;
    isParametricRiskFollow = risksCurrent.parametricFollow;
    isResonantRisk = risksCurrent.resonant;
    String riskMessage = "No significant roll risk detected.";
    Color riskColor = Colors.black;

    if (isParametricRiskHead) {
      riskMessage = "⚠️ Parametric roll risk - head seas";
      riskColor = Colors.red;
    } else if (isParametricRiskFollow) {
      riskMessage = "⚠️ Parametric roll risk - following seas";
      riskColor = Colors.red;
    } else if (isResonantRisk) {
      riskMessage = "⚠️ Resonant roll risk";
      riskColor = Colors.orange;
    }

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(350, 350),
              painter: PolarPlotPainter(
                speeds: speeds,
                angles: angles,
                matchRatio2Mask: matchRatio2Mask,
                matchRatio19Mask: matchRatio19Mask,
                matchRatio18Mask: matchRatio18Mask,
                parametricRiskMask: parametricRiskMask,
                matchRatio1Mask: matchRatio1Mask,
                matchRatio11Mask: matchRatio11Mask,
                matchRatio12Mask: matchRatio12Mask,
                resonantRiskMask: resonantRiskMask,
                currentCourseDeg: courseDeg,
                currentSpeed: vesselSpeedKnots,
                isParametricRiskHead: isParametricRiskHead,
                isParametricRiskFollow: isParametricRiskFollow,
                isResonantRisk: isResonantRisk,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                LegendItem(color: Colors.red.withOpacity(0.8), label: "T_roll ≈ 2×T_encounter"),
                LegendItem(color: Colors.red.withOpacity(0.6), label: "T_roll ≈ 1.9×T_encounter"),
                LegendItem(color: Colors.red.withOpacity(0.4), label: "T_roll ≈ 1.8×T_encounter"),
                LegendItem(color: Colors.red.withOpacity(0.3), label: "Parametric roll"),
                LegendItem(color: Colors.orange.withOpacity(0.8), label: "T_roll ≈ T_encounter"),
                LegendItem(color: Colors.orange.withOpacity(0.6), label: "T_roll ≈ 1.1×T_encounter"),
                LegendItem(color: Colors.orange.withOpacity(0.4), label: "T_roll ≈ 1.2×T_encounter"),
                LegendItem(color: Colors.orange.withOpacity(0.3), label: "Resonant roll"),
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
    if (relativeWaveDirectionDeg > 180) {
      relativeWaveDirectionDeg = 360 - relativeWaveDirectionDeg;
    }
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
    double rollWaveRatioTolerance = 0.3;
    double upperRatioLimit = (rollNaturalPeriodS + periodUncertaintyS) / waveEncounterPeriodS + rollWaveRatioTolerance;
    double lowerRollPeriodS = rollNaturalPeriodS - periodUncertaintyS;
    double lowerRatioLimit = (lowerRollPeriodS / waveEncounterPeriodS) - rollWaveRatioTolerance;
    bool conditionRatioResonantRoll = (upperRatioLimit >= 1) && (lowerRatioLimit <= 1);
    bool conditionWaveLengthResonantRoll = waveLengthToShipLengthRatio >= (1 / 3);
    bool riskResonant = conditionRatioResonantRoll && conditionWaveLengthResonantRoll;
    bool conditionRatioParametricRoll = (upperRatioLimit >= 2) && (lowerRatioLimit <= 2);
    bool conditionWaveLengthParametricRoll = (waveLengthToShipLengthRatio >= 0.5) && (waveLengthToShipLengthRatio <= 2);
    bool conditionWaveDirectionHeadSeas = relativeWaveDirectionDeg <= 60;
    bool conditionWaveDirectionFollowingSeas = relativeWaveDirectionDeg >= 105;
    bool riskParametricHead = conditionRatioParametricRoll &&
        conditionWaveLengthParametricRoll &&
        conditionWaveDirectionHeadSeas;
    bool riskParametricFollow = conditionRatioParametricRoll &&
        conditionWaveLengthParametricRoll &&
        conditionWaveDirectionFollowingSeas;
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
      mainAxisSize: MainAxisSize.min,
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
  final List<List<bool>> matchRatio2Mask;
  final List<List<bool>> matchRatio19Mask;
  final List<List<bool>> matchRatio18Mask;
  final List<List<bool>> parametricRiskMask;
  final List<List<bool>> matchRatio1Mask;
  final List<List<bool>> matchRatio11Mask;
  final List<List<bool>> matchRatio12Mask;
  final List<List<bool>> resonantRiskMask;
  final double currentCourseDeg;
  final double currentSpeed;
  final bool isParametricRiskHead;
  final bool isParametricRiskFollow;
  final bool isResonantRisk;

  PolarPlotPainter({
    required this.speeds,
    required this.angles,
    required this.matchRatio2Mask,
    required this.matchRatio19Mask,
    required this.matchRatio18Mask,
    required this.parametricRiskMask,
    required this.matchRatio1Mask,
    required this.matchRatio11Mask,
    required this.matchRatio12Mask,
    required this.resonantRiskMask,
    required this.currentCourseDeg,
    required this.currentSpeed,
    required this.isParametricRiskHead,
    required this.isParametricRiskFollow,
    required this.isResonantRisk,
  });

  final double maxRadius = 25;
  final double margin = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;
    final Paint gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke;

    for (double v = 0; v <= maxRadius; v += 5) {
      double r = (v / maxRadius) * radius;
      canvas.drawCircle(center, r, gridPaint);
      final textPainter = TextPainter(
          text: TextSpan(
              text: "${v.toInt()} kt",
              style: TextStyle(color: Colors.black, fontSize: 8)),
          textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + 5, center.dy - r - 5));
    }
    final List<int> angleLabelsDeg = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330];
    final List<String> angleLabelsText = [
      "North", "30°", "60°", "East", "120°", "150°",
      "South", "210°", "240°", "West", "300°", "330°"
    ];

    final Paint angleLinePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < angleLabelsDeg.length; i++) {
      double angleRad = (angleLabelsDeg[i] - 90) * pi / 180;
      canvas.drawLine(
          center,
          center + Offset(cos(angleRad), sin(angleRad)) * radius,
          angleLinePaint);
      final textPainter = TextPainter(
          text: TextSpan(
              text: angleLabelsText[i],
              style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr);
      textPainter.layout();
      final labelOffset = center + Offset(cos(angleRad), sin(angleRad)) * (radius + 20);
      textPainter.paint(
          canvas,
          labelOffset - Offset(textPainter.width / 2, textPainter.height / 2));
    }
    Offset polarToCartesian(double angleDeg, double speed) {
      double angleRad = (angleDeg - 90) * pi / 180; // north at top
      double r = (speed / maxRadius) * radius;
      return center + Offset(cos(angleRad), sin(angleRad)) * r;
    }
    void drawRiskZone(Canvas canvas, List<List<bool>> mask, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      for (int i = 0; i < speeds.length; i++) {
        for (int j = 0; j < angles.length; j++) {
          if (mask[i][j]) {
            Offset p = polarToCartesian(angles[j] * 180 / pi, speeds[i]);
            canvas.drawCircle(p, 2, paint);
          }
        }
      }
    }
    drawRiskZone(canvas, matchRatio2Mask, Colors.red.withOpacity(0.8));
    drawRiskZone(canvas, matchRatio19Mask, Colors.red.withOpacity(0.6));
    drawRiskZone(canvas, matchRatio18Mask, Colors.red.withOpacity(0.4));
    drawRiskZone(canvas, parametricRiskMask, Colors.red.withOpacity(0.3));
    drawRiskZone(canvas, matchRatio1Mask, Colors.orange.withOpacity(0.8));
    drawRiskZone(canvas, matchRatio11Mask, Colors.orange.withOpacity(0.6));
    drawRiskZone(canvas, matchRatio12Mask, Colors.orange.withOpacity(0.4));
    drawRiskZone(canvas, resonantRiskMask, Colors.orange.withOpacity(0.3));
    final triangleColor = (isParametricRiskHead || isParametricRiskFollow)
        ? Colors.red
        : (isResonantRisk ? Colors.orange : Colors.green);

    Offset centerTriangle = polarToCartesian(currentCourseDeg, currentSpeed);
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

    final Path trianglePath = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(baseLeft.dx, baseLeft.dy)
      ..lineTo(baseRight.dx, baseRight.dy)
      ..close();

    final Paint outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = triangleColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(trianglePath, fillPaint);
    canvas.drawPath(trianglePath, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}