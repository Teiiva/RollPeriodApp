import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async'; // Importation nécessaire

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  AccelerometerEvent? _accelerometer;
  GyroscopeEvent? _gyroscope;
  MagnetometerEvent? _magnetometer;

  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
  late StreamSubscription<MagnetometerEvent> _magnetometerSubscription;

  bool _isCollectingData = false; // Contrôle si les capteurs sont activés ou non

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Annuler les abonnements pour éviter les fuites de mémoire
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();
    _magnetometerSubscription.cancel();
    super.dispose();
  }

  // Fonction pour démarrer/mettre en pause la collecte des données
  void _toggleDataCollection() {
    setState(() {
      _isCollectingData = !_isCollectingData;
    });

    if (_isCollectingData) {
      // Démarrer la collecte des données
      _accelerometerSubscription = accelerometerEvents.listen((event) {
        setState(() => _accelerometer = event);
      });

      _gyroscopeSubscription = gyroscopeEvents.listen((event) {
        setState(() => _gyroscope = event);
      });

      _magnetometerSubscription = magnetometerEvents.listen((event) {
        setState(() => _magnetometer = event);
      });
    } else {
      // Arrêter la collecte des données
      _accelerometerSubscription.cancel();
      _gyroscopeSubscription.cancel();
      _magnetometerSubscription.cancel();
    }
  }

  // Widget pour afficher les données du capteur
  Widget sensorTile(String label, dynamic event, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: color,
          size: 40.0, // Modifier la taille de l'icône ici
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold, // Rendre le titre en gras
          ),
        ),
        subtitle: Text(event != null
            ? 'x: ${event.x >= 0 ? ' ${event.x.toStringAsFixed(2)}' : event.x.toStringAsFixed(2)}\n'
            + 'y: ${event.y >= 0 ? ' ${event.y.toStringAsFixed(2)}' : event.y.toStringAsFixed(2)}\n'
            + 'z: ${event.z >= 0 ? ' ${event.z.toStringAsFixed(2)}' : event.z.toStringAsFixed(2)}'
            : 'Press Start'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            "Data Sensors",
            style: TextStyle(
              fontWeight: FontWeight.bold, // Rendre le texte en gras
              fontSize: 24.0, // Ajuster la taille du texte si nécessaire
              color: Colors.white, // Couleur du texte en blanc
            ),
          ),
        ),
        backgroundColor: Colors.grey,
      ),
      body: Column(
        children: [
          // Affichage des données des capteurs
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                sensorTile('Accelerometer', _accelerometer, Icons.speed, Colors.grey),
                sensorTile('Gyroscope', _gyroscope, Icons.rotate_right, Colors.grey),
                sensorTile('Magnetometer', _magnetometer, Icons.compass_calibration, Colors.grey),
              ],
            ),
          ),
          // Bouton Start/Pause
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _toggleDataCollection,
              child: Text(
                _isCollectingData ? 'Pause' : 'Start',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey, // Couleur de fond du bouton
                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
