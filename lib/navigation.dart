// navigation.dart
import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'vessel_wave_painter.dart';

class NavigationPage extends StatefulWidget {
  final double boatlength;
  final double wavePeriod;
  final double waveDirection;
  final double speed;
  final double course; // Nouveau paramètre pour la course

  const NavigationPage({
    super.key,
    this.boatlength = 0,
    this.wavePeriod = 20,
    this.waveDirection = 0,
    this.speed = 0,
    this.course = 0, // Valeur par défaut
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
                  boatlength: widget.boatlength,
                  waveDirection: widget.waveDirection,
                  wavePeriod: widget.wavePeriod,
                  course: widget.course, // Passage de la course
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
                        "Speed: ${widget.speed.toStringAsFixed(1)} Knots",
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