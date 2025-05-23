// menu.dart
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
  double _boatlength = 0;
  double _wavePeriod = 20;
  double _waveDirection = 0;
  double _boatspeed = 0;
  double _course = 0; // Nouvelle variable pour la course

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const SensorPage(),
      AlertPage(),
      VesselWavePage(
        onValuesChanged: (length, period, direction, speed, course) {
          setState(() {
            _boatlength = length;
            _wavePeriod = period;
            _waveDirection = direction;
            _boatspeed = speed;
            _course = course;
          });
        },
      ),
      NavigationPage(
        boatlength: _boatlength,
        wavePeriod: _wavePeriod,
        waveDirection: _waveDirection,
        speed: _boatspeed,
        course: _course, // Passage de la course
      ),
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
            if (index == 3) {
              _pages[3] = NavigationPage(
                boatlength: _boatlength,
                wavePeriod: _wavePeriod,
                waveDirection: _waveDirection,
                speed: _boatspeed,
                course: _course, // Passage de la course mise à jour
              );
            }
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