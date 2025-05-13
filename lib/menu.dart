import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'sensor_page.dart';
import 'info.dart';
import 'alert.dart';
import 'navigation.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  int _selectedIndex = 0;

  // ✅ Instancier une seule fois chaque page
  final SensorPage _sensorPage = const SensorPage();
  final AlertPage _alertPage = AlertPage();
  final VesselWaveApp _vesselWaveApp = const VesselWaveApp();
  final NavigationPage _navigationPage = const NavigationPage();


  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _sensorPage,
      _alertPage,
      _vesselWaveApp,
      _navigationPage,

    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF012169),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: 'Sensors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active),
            label: 'Alert',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_boat_filled_rounded),
            label: 'Vessel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Navigation',
          ),

        ],
      ),
    );
  }
}
