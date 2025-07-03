import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'models/vessel_profile.dart';
import 'models/navigation_info.dart';
import 'vessel_risk_painter.dart';

class NavigationPage extends StatefulWidget {
  final VesselProfile vesselProfile;
  final NavigationInfo navigationInfo;

  const NavigationPage({
    super.key,
    required this.vesselProfile,
    required this.navigationInfo,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: RiskPolarPlot(
              vesselLengthM: widget.vesselProfile.length, // adapte selon ton modèle
              rollNaturalPeriodS: 24,
              periodUncertaintyS: 3, // ou depuis un paramètre
              vesselSpeedKnots: widget.navigationInfo.speed,
              courseDeg: widget.navigationInfo.course,
              waveDirectionDeg: widget.navigationInfo.direction, // valeur fixe ou dynamique
              meanWavePeriodS: widget.navigationInfo.wavePeriod, // idem
            ),
          ),
          // ... autres widgets éventuels
        ],
      ),

    );
  }
}
