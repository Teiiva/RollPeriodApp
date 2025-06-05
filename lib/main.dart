import 'package:flutter/material.dart';
import 'sensor_page.dart'; // Page qu’on va créer juste après
import 'menu.dart';
import 'package:flutter/material.dart';
import 'shared_data.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => SharedData(),
      child: const MyApp(),
    ),
  );
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
      home: const MenuPage(),
    );
  }
}
