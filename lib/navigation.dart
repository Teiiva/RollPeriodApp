// navigation.dart
import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'vessel_wave_painter.dart';
import 'models/vessel_profile.dart';
import 'models/navigation_info.dart';

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
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Transform.rotate(
                angle: 0,
                child: VesselWavePainter(
                  boatlength: widget.vesselProfile.length,
                  waveDirection: widget.navigationInfo.direction,
                  wavePeriod: widget.navigationInfo.wavePeriod,
                  course: widget.navigationInfo.course,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}