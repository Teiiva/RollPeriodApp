// menu.dart
import 'package:flutter/material.dart';
import 'sensor_page.dart';
import 'info.dart';
import 'prediction.dart';
import 'models/vessel_profile.dart';
import 'models/loading_condition.dart';
import 'storage_manager.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  int _selectedIndex = 1;
  VesselProfile? _currentVesselProfile;
  LoadingCondition? _currentLoadingCondition;
  List<Widget>? _pages;

  @override
  void initState() {
    super.initState();
    _loadStoredProfile();
  }

  Future<void> _loadStoredProfile() async {
    final storedProfile = await StorageManager.loadCurrent(
      key: 'currentProfile',
      fromMap: VesselProfile.fromMap,
    );

    final storedConditionName = await StorageManager.loadCurrent(
      key: 'currentConditionName',
      fromMap: (map) => map['name'] as String,
    );

    if (storedProfile != null) {
      setState(() {
        _currentVesselProfile = storedProfile;
        
        // Try to restore the exact condition used last time
        if (storedConditionName != null) {
          _currentLoadingCondition = storedProfile.loadingConditions.firstWhere(
            (c) => c.name == storedConditionName,
            orElse: () => storedProfile.loadingConditions.first,
          );
        } else {
          _currentLoadingCondition = storedProfile.loadingConditions.isNotEmpty
              ? storedProfile.loadingConditions.first
              : LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4);
        }
      });
    } else {
      // Default profile if none stored
      setState(() {
        _currentVesselProfile = VesselProfile(
          name: "LPG Carrier",
          length: 107.0,
          beam: 17.6,
          depth: 9.8,
          loadingConditions: [
            LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4)
          ],
        );
        _currentLoadingCondition = _currentVesselProfile!.loadingConditions.isNotEmpty
            ? _currentVesselProfile!.loadingConditions.first
            : LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4);
      });
    }
    _initializePages();
  }

  Future<void> _saveSelection(VesselProfile profile, LoadingCondition condition) async {
    await StorageManager.saveCurrent(
      key: 'currentProfile',
      item: profile,
      toMap: (p) => p.toMap(),
    );
    await StorageManager.saveCurrent(
      key: 'currentConditionName',
      item: {'name': condition.name},
      toMap: (m) => m,
    );
  }

  void _initializePages() {
    if (_currentVesselProfile == null || _currentLoadingCondition == null) return;
    
    setState(() {
      _pages = [
        VesselWavePage(
          currentVesselProfile: _currentVesselProfile!,
          currentLoadingCondition: _currentLoadingCondition!,
          onValuesChanged: (profile, config) {
            setState(() {
              _currentVesselProfile = profile;
              _currentLoadingCondition = config;
              _saveSelection(profile, config);
              _updatePages();
            });
          },
        ),
        SensorPage(
          vesselProfile: _currentVesselProfile!,
          loadingCondition: _currentLoadingCondition!,
          onValuesChanged: (profile, condition) {
            setState(() {
              _currentVesselProfile = profile;
              _currentLoadingCondition = condition;
              _saveSelection(profile, condition);
              _updatePages();
            });
          },
        ),
        PredictionPage(
          vesselProfile: _currentVesselProfile!,
          loadingCondition: _currentLoadingCondition!,
        ),
      ];
    });
  }

  void _updatePages() {
    _initializePages();
  }

  @override
  Widget build(BuildContext context) {
    if (_pages == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    const basscreenWidth = 411.42857142857144;
    final screenWidth = MediaQuery.of(context).size.width;
    final ratio = screenWidth / basscreenWidth;
    final double paddingValue = 2 * ratio;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages!,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
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
        iconSize: 26.0 * ratio,
        selectedFontSize: 14.0 * ratio,
        unselectedFontSize: 12.0 * ratio,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.directions_boat_filled_rounded), label: 'Info'),
          BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'Measure'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Prediction'),
        ],
      ),
    );
  }
}
