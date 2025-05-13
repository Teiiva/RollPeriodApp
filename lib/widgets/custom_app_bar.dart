import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  // Pas de titre ni d'action ici
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // --- Pas de titre ici ---
      title: null,
      centerTitle: true,

      // --- Logo centré ---
      flexibleSpace: Center(
        child: Image.asset(
          'assets/images/logo_marin.png',
          width: 120,  // Ajuste la taille du logo si nécessaire
          height: 120,
        ),
      ),

      backgroundColor: const Color(0xFF012169),
      elevation: 0,  // Si tu veux enlever l'ombre sous l'AppBar
    );
  }
}
