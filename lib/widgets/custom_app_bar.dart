import 'package:flutter/material.dart';
import 'package:marin/sensor_page.dart';
import '../menu.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onLeadingPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onLeadingPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // --- PNG cliquable à gauche avec padding pour le décaler vers la droite ---
      leading: Transform.translate(
        offset: const Offset(25, 0), // Décalage appliqué à toute la zone cliquable
        child: IconButton(
          padding: EdgeInsets.zero, // Supprime le padding interne par défaut
          constraints: const BoxConstraints(), // Permet à l'IconButton de s'adapter
          icon: Image.asset(
            'assets/images/menu.png',
            width: 24,
            height: 24,
            color: Colors.white,
          ),
          onPressed: onLeadingPressed ?? () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MenuPage()),
            );
          },
        ),
      ),

      // --- Titre centré ---
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24.0,
          color: Colors.white,
        ),
      ),
      centerTitle: true,

      // --- Logo à droite ---
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Image.asset(
            'assets/images/logo.png',
            width: 40,
            height: 40,
          ),
        ),
      ],
      backgroundColor: const Color(0xFF012169),
    );
  }
}