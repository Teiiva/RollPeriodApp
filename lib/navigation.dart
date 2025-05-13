import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';

void main() {
  runApp(const MaterialApp(
    home: NavigationPage(),
    debugShowCheckedModeBanner: false, // Cette ligne enlève la barre de débogage
  ));
}

class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Center( // Affiche un texte centré
        child: Text('Contenu de la page'),
      ),
    );
  }
}
