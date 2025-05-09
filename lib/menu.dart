import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  Widget sensorTileWithSubtitle(String label, IconData icon, Color iconColor, String subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          margin: EdgeInsets.zero, // pour qu’il n’y ait pas d’espace vertical
          child: Container(
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  child: Icon(icon, color: iconColor, size: 40.0),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(12.0),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 14.0),
          ),
        ),
      ],
    );
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Menu"),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                sensorTileWithSubtitle(
                  "Data Sensors",
                  Icons.sensors,
                  Colors.blue,
                  "Dernière mise à jour : 09/05/2025",
                )
              ],
            ),
          ),

        ],
      ),
    );
  }
}
