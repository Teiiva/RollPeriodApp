import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';

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

class VesselWavePage extends StatelessWidget {
  final TextEditingController lengthController = TextEditingController();
  final TextEditingController wavePeriodController = TextEditingController();
  final TextEditingController directionController = TextEditingController();

  VesselWavePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Vessel & Waves"),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildInputCard(
            const Icon(Icons.directions_boat, size: 40, color: Color(0xFF002868)),
            "Length of vessel",
            "in meters",
            lengthController,
          ),
          _buildInputCard(
            const Icon(Icons.waves, size: 40, color: Color(0xFF002868)),
            "Waves period",
            "in second",
            wavePeriodController,
          ),
          _buildInputCard(
            Image.asset('assets/images/direction.png', width: 40, height: 40),
            "Direction of the waves",
            "in degree",
            directionController,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002868),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            ),
            onPressed: () {
              final length = lengthController.text;
              final wavePeriod = wavePeriodController.text;
              final direction = directionController.text;

              // Utilise ces variables comme tu veux :
              print('Length: $length');
              print('Wave Period: $wavePeriod');
              print('Direction: $direction');
            },
            child: const Text("Send"),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            //child: Image.asset(
              //'assets/ship.png', // Assure-toi que cette image est dans ton dossier assets
              //height: 180,
            //),
          )
        ],
      ),
    );
  }

  Widget _buildInputCard(Widget iconWidget, String label, String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14)),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: hint,
                        border: InputBorder.none,
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
