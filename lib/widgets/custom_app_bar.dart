import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;  // Ajout d'un titre optionnel

  const CustomAppBar({super.key, this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null ? Text(title!) : null,  // Affichage conditionnel du titre
      centerTitle: true,

      // --- Logo centré ---
      flexibleSpace: Center(
        child: Image.asset(
          'assets/images/logo_marin.png',
          width: 120,
          height: 120,
        ),
      ),

      backgroundColor: const Color(0xFF012169),
      elevation: 0,
    );
  }
}