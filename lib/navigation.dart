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
          _buildSpeedTile(),
        ],
      ),
    );
  }

  Widget _buildSpeedTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.speed, size: 40, color: Color(0xFF012169)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "Speed: ${widget.navigationInfo.speed.toStringAsFixed(1)} Knots",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}