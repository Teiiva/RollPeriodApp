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
  bool _isBottomBarVisible = true; // Nouvel état pour contrôler la visibilité

  @override
  void initState() {
    super.initState();

    // Initialisation avec un profil par défaut et une condition de chargement par défaut
    _currentVesselProfile = VesselProfile(
      name: "Example",
      length: 100.0,
      beam: 20.0,
      depth: 10.0,
      loadingConditions: [
        LoadingCondition(
          name: "Example",
          gm: 1.0,
          vcg: 10.0,
          draft: 5.0,
        )
      ],
    );

    _currentLoadingCondition = _currentVesselProfile.loadingConditions.first;

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
        onValuesChanged: (profile, condition, navInfo) {
          setState(() {
            _currentVesselProfile = profile;
            _currentLoadingCondition = condition;
            _navigationInfo = navInfo;
            _updatePages();
          });
        },
      ),
      VesselWavePage(
        currentVesselProfile: _currentVesselProfile,
        currentLoadingCondition: _currentLoadingCondition,
        navigationInfo: _navigationInfo,
        onValuesChanged: (profile, config, navInfo) {
          setState(() {
            _currentVesselProfile = profile;
            _currentLoadingCondition = config;
            _navigationInfo = navInfo;
            _updatePages();
          });
        },
      ),
      PredictionPage(
        vesselProfile: _currentVesselProfile,
        loadingCondition: _currentLoadingCondition,
      ),
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
          onValuesChanged: (profile, condition, navInfo) {
            setState(() {
              _currentVesselProfile = profile;
              _currentLoadingCondition = condition;
              _navigationInfo = navInfo;
              _updatePages();
            });
          },
        ),
        VesselWavePage(
          currentVesselProfile: _currentVesselProfile,
          currentLoadingCondition: _currentLoadingCondition,
          navigationInfo: _navigationInfo,
          onValuesChanged: (profile, config, navInfo) {
            setState(() {
              _currentVesselProfile = profile;
              _currentLoadingCondition = config;
              _navigationInfo = navInfo;
              _updatePages();
            });
          },
        ),
        PredictionPage(
          vesselProfile: _currentVesselProfile,
          loadingCondition: _currentLoadingCondition,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final basscreenWidth = 411.42857142857144;
    final screenWidth = MediaQuery.of(context).size.width;
    print('screenWidth: ${screenWidth}');
    final screenHeight = MediaQuery.of(context).size.height;
    print('screenHeight: ${screenHeight}');
    final ratio = screenWidth/basscreenWidth;
    print('ratio: ${ratio}');
    final double padding_value = 2 * ratio;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
        key: const ValueKey('visibleBar'),
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF012169),
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
        iconSize: 26.0 * ratio, // Taille fixe pour les icônes
        selectedFontSize: 14.0 * ratio, // Taille de police pour l'élément sélectionné
        unselectedFontSize: 12.0 * ratio, // Taille de police pour les éléments non sélectionnés
        selectedLabelStyle: TextStyle(height: 0), // Réduire l'espace sous le texte
        unselectedLabelStyle: TextStyle(height: 0), // Réduire l'espace sous le texte
        items: [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: padding_value, bottom: padding_value),
              child: Icon(Icons.explore),
            ),
            label: 'Roll Risk',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: padding_value, bottom: padding_value),
              child: Icon(Icons.notifications_active),
            ),
            label: 'Alert',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: padding_value, bottom: padding_value),
              child: Icon(Icons.sensors),
            ),
            label: 'Measure',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: padding_value, bottom: padding_value),
              child: Icon(Icons.directions_boat_filled_rounded),
            ),
            label: 'Info',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: padding_value, bottom: padding_value),
              child: Icon(Icons.timeline),
            ),
            label: 'Prediction',
          ),
        ],
      ),
    );
  }
}