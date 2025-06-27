import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;  // Ajout d'un titre optionnel
  final Widget? leading;
  final List<Widget>? actions;
  final bool showLogo;

  const CustomAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.showLogo = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null ? Text(title!) : null,  // Affichage conditionnel du titre
        actions: actions,
      centerTitle: true,

      // --- Logo centré ---
      flexibleSpace: showLogo
          ? Center(
        child: Padding(
          padding: const EdgeInsets.only(top:25),
          child: Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/images/logo_marin_dark.png'
                : 'assets/images/logo_marin.png',

            width: 120,
            height: 120,
          ),
        ),
      )
          : null,
      leading: leading,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : const Color(0xFF012169),
      surfaceTintColor: Colors.transparent, // empêche les modifications visuelles au scroll
      elevation: 0,
    );
  }
}