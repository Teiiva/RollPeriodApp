import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'vessel_wave_painter.dart';

void main() {
  runApp(const VesselWaveApp());
}

class VesselWaveApp extends StatelessWidget {
  const VesselWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VesselWavePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VesselWavePage extends StatefulWidget {
  const VesselWavePage({super.key});

  @override
  State<VesselWavePage> createState() => _VesselWavePageState();
}

class _VesselWavePageState extends State<VesselWavePage> {
  double _length = 50;
  double _wavePeriod = 8;
  double _direction = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Transform.rotate(
              angle: -90 * (3.14159265359 / 180), // Rotation de -90 degrés (en radians)
              child: VesselWavePainter(
                waveLength: _length,
                waveDirection: _direction,
                wavePeriod: _wavePeriod,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSliderCard(
            iconWidget: const Icon(Icons.directions_boat, size: 40, color: Color(0xFF012169)),
            label: "Length of vessel",
            unit: "m",
            value: _length,
            min: 0,
            max: 200,
            onChanged: (val) => setState(() => _length = val),
          ),
          _buildSliderCard(
            iconWidget: const Icon(Icons.waves, size: 40, color: Color(0xFF002868)),
            label: "Waves period",
            unit: "s",
            value: _wavePeriod,
            min: 1,
            max: 60,
            onChanged: (val) => setState(() => _wavePeriod = val),
          ),
          _buildSliderCard(
            iconWidget: Image.asset('assets/images/direction.png', width: 40, height: 40),
            label: "Direction of the waves",
            unit: "°",
            value: _direction,
            min: 0,
            max: 360,
            onChanged: (val) => setState(() => _direction = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderCard({
    required Widget iconWidget,
    required String label,
    required String unit,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "$label: ${value.toStringAsFixed(1)} $unit",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: ((max - min) ~/ 1),
                      label: value.toStringAsFixed(1),
                      onChanged: onChanged,
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