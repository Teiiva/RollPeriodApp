import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'sensor_page.dart'; // Page qu’on va créer juste après
import 'info.dart'; // Page qu’on va créer juste après
import 'alert.dart'; // Page qu’on va créer juste après
import 'navigation.dart'; // Page qu’on va créer juste après

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  Widget sensorTileWithDescription(BuildContext context, String title, IconData icon, Color iconColor, String description, Widget targetPage) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetPage),
        );
      },
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.blue.withOpacity(0.1),
      highlightColor: Colors.blue.withOpacity(0.05),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Menu"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            sensorTileWithDescription(
              context,
              "Data Sensors",
              Icons.sensors,
              Color(0xFF012169),
              "This page allows you to view real-time sensor data (accelerometer and gyroscope), monitor the phone's roll angle, and calculate its average oscillation period. Press Start to begin recording.",
              const SensorPage(), // Remplacez par votre page cible
            ),
            sensorTileWithDescription(
              context,
              "Vessel & Waves",
              Icons.directions_boat_filled_rounded,
              Color(0xFF012169),
              "This page lets you enter key parameters related to your vessel and the sea state:\n– The length of the vessel,\n– The wave period,\n– And the direction of the waves.\nPress Send to validate the data and use it in risk calculations.",
              const VesselWaveApp(), // Remplacez par votre page cible
            ),
            sensorTileWithDescription(
              context,
              "Navigation",
              Icons.explore,
              Color(0xFF012169),
              "This page displays the different roll zones, whether parametric or resonant, based on the data measured in the Data Sensors page and the parameters entered in the Vessel & Waves page. Based on the analysis, it can also provide heading recommendations to help minimize roll-related risks.",
              const NavigationPage(), // Remplacez par votre page cible
            ),
            sensorTileWithDescription(
              context,
              "Alert",
              Icons.notifications_active,
              Color(0xFF012169),
              "This page allows you to configure personalized alerts when excessive roll is detected. You can choose the type of alert to trigger: sound, visual, and/or mobile notification. You can also view the alert history to keep track of past events.",
              const AlertPage(), // Remplacez par votre page cible
            ),
            // Ajoutez d'autres tuiles cliquables ici
          ],
        ),
      ),
    );
  }
}

