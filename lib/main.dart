import 'package:flutter/material.dart';
import 'sensor_page.dart'; // Page qu’on va créer juste après

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,  // Cette ligne supprime la bannière
      title: 'Sensors Kinetics Clone',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'CustomFont',  // Remplacez par le nom de votre famille de police
      ),
      home: const SensorPage(),
    );
  }
}
