import 'package:flutter/material.dart';
import 'sensor_page.dart'; // Page qu’on va créer juste après
import 'menu.dart';
import 'package:flutter/material.dart';
import 'shared_data.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Verrouille l'orientation en portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    // Si tu veux bloquer uniquement le portrait, ne mets que celui-ci.
    // Tu peux aussi ajouter DeviceOrientation.portraitDown si tu veux les deux sens en portrait.
  ]);
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
        fontFamily: 'CustomFont',
        brightness: Brightness.light, // Thème clair par défaut
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'CustomFont',
        brightness: Brightness.dark, // Thème sombre
        // Ajoutez d'autres personnalisations pour le mode sombre ici
      ),
      themeMode: ThemeMode.system, // Suit le paramètre système
      home: const MenuPage(),
    );
  }
}
