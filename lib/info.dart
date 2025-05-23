// info.dart
import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';

class VesselWavePage extends StatefulWidget {
  final Function(double, double, double, double, double) onValuesChanged; // Ajout du paramètre course

  const VesselWavePage({super.key, required this.onValuesChanged});

  @override
  State<VesselWavePage> createState() => _VesselWavePageState();
}

class _VesselWavePageState extends State<VesselWavePage> {
  double _length = 0;
  double _wavePeriod = 20;
  double _direction = 0;
  double _speed = 0;
  double _course = 0; // Nouvelle variable pour la course du navire

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          _buildSliderCard(
            iconWidget: const Icon(Icons.speed, size: 40,  color: Color(0xFF012169)),
            label: "Vessel speed",
            unit: "Knots",
            value: _speed,
            min: 0,
            max: 50,
            onChanged: (val) {
              setState(() => _speed = val);
              widget.onValuesChanged(_length, _wavePeriod, _direction, _speed, _course);
            },
          ),
          _buildSliderCard(
            iconWidget: const Icon(Icons.directions_boat, size: 40, color: Color(0xFF012169)),
            label: "Vessel length",
            unit: "m",
            value: _length,
            min: 0,
            max: 200,
            onChanged: (val) {
              setState(() => _length = val);
              widget.onValuesChanged(_length, _wavePeriod, _direction, _speed, _course);
            },
          ),
          _buildSliderCard(
            iconWidget: const Icon(Icons.navigation, size: 40, color: Color(0xFF012169)),
            label: "Course of ship",
            unit: "°",
            value: _course,
            min: 0,
            max: 360,
            onChanged: (val) {
              setState(() => _course = val);
              widget.onValuesChanged(_length, _wavePeriod, _direction, _speed, _course);
            },
          ),
          _buildSliderCard(
            iconWidget: Image.asset('assets/images/direction.png', width: 40, height: 40),
            label: "Wave direction",
            unit: "°",
            value: _direction,
            min: 0,
            max: 360,
            onChanged: (val) {
              setState(() => _direction = val);
              widget.onValuesChanged(_length, _wavePeriod, _direction, _speed, _course);
            },
          ),
          _buildSliderCard(
            iconWidget: const Icon(Icons.waves, size: 40, color: Color(0xFF002868)),
            label: "Waves period",
            unit: "s",
            value: _wavePeriod,
            min: 1,
            max: 60,
            onChanged: (val) {
              setState(() => _wavePeriod = val);
              widget.onValuesChanged(_length, _wavePeriod, _direction, _speed, _course);
            },
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