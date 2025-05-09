import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'sensor_page.dart'; // Page qu’on va créer juste après
import 'info.dart'; // Page qu’on va créer juste après

class AlertPage extends StatelessWidget {
  const AlertPage({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Alert"),
      );
  }
}

