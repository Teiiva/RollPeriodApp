// menu.dart
import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'sensor_page.dart';
import 'info.dart';
import 'alert.dart';
import 'navigation.dart';
import 'prediction.dart';
import 'models/vessel_profile.dart';
import 'models/loading_condition.dart';
import 'models/navigation_info.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  int _selectedIndex = 2;
  late VesselProfile _currentVesselProfile;
  late LoadingCondition _currentLoadingCondition;
  late NavigationInfo _navigationInfo;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Dans menu.dart, modifiez l'initialisation du profil
    _currentVesselProfile = VesselProfile(
      name: "Default",
      length: 0, // Initialisez à 0 ou une valeur par défaut
      beam: 0, // Initialisez à 0 ou une valeur par défaut
      depth: 0, // Initialisez à 0 ou une valeur par défaut
    );

    _currentLoadingCondition = LoadingCondition(
      name: "Default",
      gm: 0, // Initialisez à 0 ou une valeur par défaut
      vcg: 0, // Initialisez à 0 ou une valeur par défaut
    );

    _navigationInfo = NavigationInfo(
      wavePeriod: 20,
      direction: 0,
      speed: 0,
      course: 0,
    );

    _initializePages();
  }

  void _initializePages() {
    _pages = [
      NavigationPage(
        vesselProfile: _currentVesselProfile,
        navigationInfo: _navigationInfo,
      ),
      AlertPage(),
      SensorPage(
        vesselProfile: _currentVesselProfile,
        loadingCondition: _currentLoadingCondition,
        navigationInfo: _navigationInfo,
      ),
      VesselWavePage(
        currentVesselProfile: _currentVesselProfile,
        currentLoadingCondition: _currentLoadingCondition,
        navigationInfo: _navigationInfo,
        onValuesChanged: (profile,config, navInfo) {
          setState(() {
            _currentVesselProfile = profile;
            _currentLoadingCondition = config;
            _navigationInfo = navInfo;
            _updatePages();
          });
        },
      ),
      PredictionPage(vesselProfile: _currentVesselProfile, loadingCondition: _currentLoadingCondition,),
    ];
  }

  void _updatePages() {
    setState(() {
      _pages = [
        NavigationPage(
          vesselProfile: _currentVesselProfile,
          navigationInfo: _navigationInfo,
        ),
        AlertPage(),
        SensorPage(
          vesselProfile: _currentVesselProfile,
          loadingCondition: _currentLoadingCondition,
          navigationInfo: _navigationInfo,
        ),
        VesselWavePage(
          currentVesselProfile: _currentVesselProfile,
          currentLoadingCondition: _currentLoadingCondition,
          navigationInfo: _navigationInfo,
          onValuesChanged: (profile,config, navInfo) {
            setState(() {
              _currentVesselProfile = profile;
              _currentLoadingCondition = config;
              _navigationInfo = navInfo;
              _updatePages();
            });
          },
        ),
        PredictionPage(vesselProfile: _currentVesselProfile, loadingCondition: _currentLoadingCondition,),
      ];
    });
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
            if (index == 0) {
              _pages[0] = NavigationPage(
                vesselProfile: _currentVesselProfile,
                navigationInfo: _navigationInfo,
              );
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Navigation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active),
            label: 'Alert',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: 'Sensors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_boat_filled_rounded),
            label: 'Info',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Prediction',
          ),
        ],
      ),
    );
  }
}