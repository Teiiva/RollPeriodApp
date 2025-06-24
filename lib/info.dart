// info.dart
import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'models/vessel_profile.dart';
import 'models/navigation_info.dart';
import 'models/loading_condition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'storage_manager.dart';

class VesselWavePage extends StatefulWidget {
  final VesselProfile currentVesselProfile;
  final LoadingCondition currentLoadingCondition;
  final NavigationInfo navigationInfo;
  final Function(VesselProfile, LoadingCondition, NavigationInfo) onValuesChanged;

  const VesselWavePage({
    super.key,
    required this.currentVesselProfile,
    required this.currentLoadingCondition,
    required this.navigationInfo,
    required this.onValuesChanged,
  });

  @override
  State<VesselWavePage> createState() => _VesselWavePageState();
}

class _VesselWavePageState extends State<VesselWavePage> {
  late VesselProfile _currentVesselProfile;
  late NavigationInfo _navigationInfo;
  List<VesselProfile> _savedProfiles = [];
  int _currentPageIndex = 0;
  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _conditionNameController = TextEditingController();
  late LoadingCondition _currentLoadingCondition;

  @override
  void initState() {
    super.initState();
    _currentVesselProfile = widget.currentVesselProfile;
    _navigationInfo = widget.navigationInfo;
    _currentLoadingCondition = widget.currentLoadingCondition;
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    // Charger les profils sauvegardés
    _savedProfiles = await StorageManager.loadList(
      key: 'savedProfiles',
      fromMap: VesselProfile.fromMap,
    );

    // Charger le profil courant
    final currentProfile = await StorageManager.loadCurrent(
      key: 'currentProfile',
      fromMap: VesselProfile.fromMap,
    );

    if (currentProfile != null) {
      setState(() {
        _currentVesselProfile = _savedProfiles.firstWhere(
              (p) => p.name == currentProfile.name,
          orElse: () => currentProfile,
        );

        // Charger la première condition ou créer une condition par défaut
        _currentLoadingCondition = _currentVesselProfile.loadingConditions.isNotEmpty
            ? _currentVesselProfile.loadingConditions.first
            : LoadingCondition(name: "Example", gm: 0, vcg: 0);
      });
    }
  }

  Future<void> _saveAllData() async {
    // Mettre à jour la liste des profils avec le profil courant
    final index = _savedProfiles.indexWhere((p) => p.name == _currentVesselProfile.name);
    if (index != -1) {
      _savedProfiles[index] = _currentVesselProfile;
    } else {
      _savedProfiles.add(_currentVesselProfile);
    }

    // Sauvegarder la liste des profils
    await StorageManager.saveList(
      key: 'savedProfiles',
      items: _savedProfiles,
      toMap: (profile) => profile.toMap(),
    );

    // Sauvegarder le profil courant
    await StorageManager.saveCurrent(
      key: 'currentProfile',
      item: _currentVesselProfile,
      toMap: (profile) => profile.toMap(),
    );
  }

  void _updateValues() {
    widget.onValuesChanged(_currentVesselProfile, _currentLoadingCondition, _navigationInfo);
    _saveAllData(); // Sauvegarde automatique à chaque modification
  }

  void _saveCurrentVesselProfile() {
    _profileNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Vessel Profile"),
        content: TextField(
          controller: _profileNameController,
          decoration: const InputDecoration(
            labelText: "Profile Name",
            hintText: "Enter profile name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (_profileNameController.text.trim().isNotEmpty) {
                final newProfile = VesselProfile(
                  name: _profileNameController.text.trim(),
                  length: _currentVesselProfile.length,
                  beam: _currentVesselProfile.beam,
                  depth: _currentVesselProfile.depth,
                  loadingConditions: [
                    LoadingCondition(
                      name: "Example",
                      gm: _currentLoadingCondition.gm,
                      vcg: _currentLoadingCondition.vcg,
                    )
                  ],
                );

                setState(() {
                  _savedProfiles.add(newProfile);
                  _currentVesselProfile = newProfile;
                  _currentLoadingCondition = newProfile.loadingConditions.first;
                });

                await _saveAllData();
                _updateValues();
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _saveCurrentLoadingCondition() {
    _conditionNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save voyage"),
        content: TextField(
          controller: _conditionNameController,
          decoration: const InputDecoration(
            labelText: "Voyage Name",
            hintText: "Enter voyage name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (_conditionNameController.text.trim().isNotEmpty) {
                final newCondition = LoadingCondition(
                  name: _conditionNameController.text.trim(),
                  gm: _currentLoadingCondition.gm,
                  vcg: _currentLoadingCondition.vcg,
                );

                setState(() {
                  final newConditions = List<LoadingCondition>.from(_currentVesselProfile.loadingConditions);
                  newConditions.add(newCondition);
                  _currentVesselProfile = _currentVesselProfile.copyWith(loadingConditions: newConditions);
                  _currentLoadingCondition = newCondition;
                });

                await _saveAllData();
                _updateValues();
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _loadProfile(VesselProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Sauvegarder le profil courant avant de changer
    final currentProfileIndex = _savedProfiles.indexWhere((p) => p.name == _currentVesselProfile.name);
    if (currentProfileIndex != -1) {
      _savedProfiles[currentProfileIndex] = _currentVesselProfile;
    } else {
      _savedProfiles.add(_currentVesselProfile);
    }

    // 2. Sauvegarder la liste mise à jour des profils
    await prefs.setString(
      'savedProfiles',
      json.encode(_savedProfiles.map((p) => p.toMap()).toList()),
    );

    // 3. Charger le nouveau profil sélectionné
    await prefs.setString(
      'currentProfile',
      json.encode(profile.toMap()),
    );

    // 4. Mettre à jour l'état local
    setState(() {
      _currentVesselProfile = profile;
      // Charger la première condition si elle existe
      if (profile.loadingConditions.isNotEmpty) {
        _currentLoadingCondition = profile.loadingConditions.first;
      } else {
        // Créer une condition par défaut si aucune n'existe
        _currentLoadingCondition = LoadingCondition(
          name: "Example",
          gm: 0,
          vcg: 0,
        );
      }
      _updateValues();
    });
  }

  void _loadCondition(LoadingCondition condition) {
    setState(() {
      _currentLoadingCondition = condition;
      _updateValues();
    });
  }

  void _deleteProfile(int index) async {
    setState(() {
      _savedProfiles.removeAt(index);
      // Si on supprime le profil courant, charger le premier profil disponible ou créer un profil par défaut
      if (_savedProfiles.isNotEmpty) {
        _currentVesselProfile = _savedProfiles.first;
        _currentLoadingCondition = _currentVesselProfile.loadingConditions.firstOrNull ??
            LoadingCondition(name: "Example", gm: 0, vcg: 0);
      } else {
        _currentVesselProfile = VesselProfile(
          name: "Example",
          length: 0,
          beam: 0,
          depth: 0,
          loadingConditions: [LoadingCondition(name: "Example", gm: 0, vcg: 0)],
        );
        _currentLoadingCondition = _currentVesselProfile.loadingConditions.first;
      }
    });

    await _saveAllData();
    _updateValues();
  }

  void _deleteCondition(int index) async {
    setState(() {
      final newConditions = List<LoadingCondition>.from(_currentVesselProfile.loadingConditions);
      newConditions.removeAt(index);

      _currentVesselProfile = _currentVesselProfile.copyWith(loadingConditions: newConditions);

      // Si on supprime la condition actuelle ou s'il ne reste plus de conditions
      if (newConditions.isEmpty || _currentLoadingCondition == _currentVesselProfile.loadingConditions[index]) {
        _currentLoadingCondition = newConditions.isNotEmpty
            ? newConditions.first
            : LoadingCondition(name: "Example", gm: 0, vcg: 0);

        if (newConditions.isEmpty) {
          _currentVesselProfile = _currentVesselProfile.copyWith(
            loadingConditions: [_currentLoadingCondition],
          );
        }
      }
    });

    await _saveAllData();
    _updateValues();
  }

  @override
  void dispose() {
    _profileNameController.dispose();
    _conditionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: IndexedStack(
        index: _currentPageIndex,
        children: [
          _buildVesselInfoPage(),
          _buildLoadingInfoPage(),
          _buildNavigationInfoPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPageIndex,
        onTap: (index) => setState(() => _currentPageIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_boat),
            label: 'Vessel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.balance),
            label: 'Voyage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.navigation),
            label: 'Navigation',
          ),
        ],
        selectedItemColor: const Color(0xFF012169),
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _buildVesselInfoPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileManagementSection(),
          _buildInputCard(
            iconWidget: Icon(Icons.directions_boat, size: 40, color: Color(0xFF012169)),
            label: "Vessel length",
            unit: "m",
            value: _currentVesselProfile.length,
            onChanged: (val) {
              setState(() => _currentVesselProfile = _currentVesselProfile.copyWith(length: val));
              _updateValues();
            },
          ),
          _buildInputCard(
            iconWidget: Icon(Icons.swap_horiz, size: 40, color: Color(0xFF012169)),
            label: "Beam (B)",
            unit: "m",
            value: _currentVesselProfile.beam,
            onChanged: (val) {
              setState(() => _currentVesselProfile = _currentVesselProfile.copyWith(beam: val));
              _updateValues();
            },
          ),
          _buildInputCard(
            iconWidget: Icon(Icons.swap_vert, size: 40, color: Color(0xFF012169)),
            label: "Depth (D)",
            unit: "m",
            value: _currentVesselProfile.depth,
            onChanged: (val) {
              setState(() => _currentVesselProfile = _currentVesselProfile.copyWith(depth: val));
              _updateValues();
            },
          ),
        ],
      ),
    );
  }

  // Dans la méthode _buildLoadingInfoPage() de info.dart
  Widget _buildLoadingInfoPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildConditionManagementSection(),
          _buildInputCard(
            iconWidget: Icon(Icons.straighten, size: 40, color: Color(0xFF012169)),
            label: "GM",
            unit: "m",
            value: _currentLoadingCondition.gm,
            onChanged: (val) {
              setState(() => _currentLoadingCondition = _currentLoadingCondition.copyWith(gm: val));
              _updateValues();
            },
          ),
          _buildInputCard(
            iconWidget: Icon(Icons.height, size: 40, color: Color(0xFF012169)),
            label: "VCG",
            unit: "m",
            value: _currentLoadingCondition.vcg,
            onChanged: (val) {
              setState(() => _currentLoadingCondition = _currentLoadingCondition.copyWith(vcg: val));
              _updateValues();
            },
          ),
          _buildInputCard( // Nouveau champ
            iconWidget: Icon(Icons.water, size: 40, color: Color(0xFF012169)),
            label: "Draft",
            unit: "m",
            value: _currentLoadingCondition.draft,
            onChanged: (val) {
              setState(() => _currentLoadingCondition = _currentLoadingCondition.copyWith(draft: val));
              _updateValues();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationInfoPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildInputCard(
            iconWidget: const Icon(Icons.speed, size: 40, color: Color(0xFF012169)),
            label: "Vessel speed",
            unit: "Knots",
            value: _navigationInfo.speed,
            onChanged: (val) {
              setState(() => _navigationInfo = _navigationInfo.copyWith(speed: val));
              _updateValues();
            },
          ),
          _buildSliderCard(
            iconWidget: const Icon(Icons.navigation, size: 40, color: Color(0xFF012169)),
            label: "Course of ship",
            unit: "°",
            value: _navigationInfo.course,
            min: 0,
            max: 360,
            onChanged: (val) {
              setState(() => _navigationInfo = _navigationInfo.copyWith(course: val));
            },
            onChangeEnd: (val) {
              _updateValues();
            },
          ),
          _buildSliderCard(
            iconWidget: Image.asset('assets/images/direction.png', width: 40, height: 40),
            label: "Waves direction",
            unit: "°",
            value: _navigationInfo.direction,
            min: 0,
            max: 360,
            onChanged: (val) {
              setState(() => _navigationInfo = _navigationInfo.copyWith(direction: val));
            },
            onChangeEnd: (val) {
              _updateValues();
            },
          ),
          _buildInputCard(
            iconWidget: const Icon(Icons.waves, size: 40, color: Color(0xFF002868)),
            label: "Waves period",
            unit: "s",
            value: _navigationInfo.wavePeriod,
            onChanged: (val) {
              setState(() => _navigationInfo = _navigationInfo.copyWith(wavePeriod: val));
              _updateValues();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileManagementSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Vessel Profile",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.create_new_folder, color: Color(0xFF012169)),
                    onPressed: _saveCurrentVesselProfile,
                    tooltip: "Save current profile",
                  ),
                ],
              ),
              if (_savedProfiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 50, // Hauteur fixe
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _savedProfiles.length,
                    itemBuilder: (context, index) {
                      final profile = _savedProfiles[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InputChip(
                          label: Text(profile.name),
                          selected: profile.name == _currentVesselProfile.name,
                          onSelected: (_) => _loadProfile(profile),
                          onDeleted: () => _deleteProfile(index),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: profile.name == _currentVesselProfile.name
                              ? const Color(0xFF012169).withOpacity(0.2)
                              : Colors.grey[200],
                          labelStyle: TextStyle(
                            color: profile.name == _currentVesselProfile.name
                                ? const Color(0xFF012169)
                                : Colors.black,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConditionManagementSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                      "Voyage",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.save, color: Color(0xFF012169)),
                    onPressed: _saveCurrentLoadingCondition,
                    tooltip: "Save current voyage",
                  ),
                ],
              ),
              if (_currentVesselProfile.loadingConditions.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _currentVesselProfile.loadingConditions.length,
                    itemBuilder: (context, index) {
                      final condition = _currentVesselProfile.loadingConditions[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InputChip(
                          label: Text(condition.name),
                          selected: condition.name == _currentLoadingCondition.name,
                          onSelected: (_) => _loadCondition(condition),
                          onDeleted: () => _deleteCondition(index),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: condition.name == _currentLoadingCondition.name
                              ? const Color(0xFF012169).withOpacity(0.2)
                              : Colors.grey[200],
                          labelStyle: TextStyle(
                            color: condition.name == _currentLoadingCondition.name
                                ? const Color(0xFF012169)
                                : Colors.black,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderCard({
    required Widget iconWidget,
    required String label,
    required String unit,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "$label: ${value.toStringAsFixed(2)} $unit",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: ((max - min) ~/ 1),
                      label: value.toStringAsFixed(2),
                      onChanged: onChanged,
                      onChangeEnd: onChangeEnd,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required Widget iconWidget,
    required String label,
    required String unit,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final TextEditingController _controller = TextEditingController(text: value.toStringAsFixed(2));
    final FocusNode _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) {
                          final parsedValue = double.tryParse(_controller.text);
                          if (parsedValue != null) {
                            onChanged(parsedValue);
                          }
                        }
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          suffixText: unit,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
