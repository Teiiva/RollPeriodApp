// menu.dart
import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'sensor_page.dart';
import 'info.dart';
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
  int _selectedIndex = 1;
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
      name: "LPG Carrier",
      length: 107.0,
      beam: 17.6,
      depth: 9.8,
      loadingConditions: [
        LoadingCondition(
          name: "Ballast",
          gm: 1.2,
          vcg: 6.6,
          draft: 5.4,
        )
      ],
    );

    _currentLoadingCondition = _currentVesselProfile.loadingConditions.first;
    _navigationInfo = NavigationInfo(
      wavePeriod: 10,
      direction: 30,
      speed: 22,
      course: 325,
    );

    _initializePages();
  }

  void _initializePages() {
    _pages = [
      VesselWavePage(
        currentVesselProfile: _currentVesselProfile,
        currentLoadingCondition: _currentLoadingCondition,
        onValuesChanged: (profile, config) {
          setState(() {
            _currentVesselProfile = profile;
            _currentLoadingCondition = config;
            _updatePages();
          });
        },
      ),
      SensorPage(
        vesselProfile: _currentVesselProfile,
        loadingCondition: _currentLoadingCondition,
        onValuesChanged: (profile, condition) {
          setState(() {
            _currentVesselProfile = profile;
            _currentLoadingCondition = condition;
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
        VesselWavePage(
          currentVesselProfile: _currentVesselProfile,
          currentLoadingCondition: _currentLoadingCondition,
          onValuesChanged: (profile, config) {
            setState(() {
              _currentVesselProfile = profile;
              _currentLoadingCondition = config;
              _updatePages();
            });
          },
        ),
        SensorPage(
          vesselProfile: _currentVesselProfile,
          loadingCondition: _currentLoadingCondition,
          onValuesChanged: (profile, condition) {
            setState(() {
              _currentVesselProfile = profile;
              _currentLoadingCondition = condition;
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
              child: Icon(Icons.directions_boat_filled_rounded),
            ),
            label: 'Info',
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
              child: Icon(Icons.timeline),
            ),
            label: 'Prediction',
          ),
        ],

      ),
    );
  }
}