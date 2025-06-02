// info.dart
import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'models/vessel_profile.dart';
import 'models/navigation_info.dart';
import 'models/loading_condition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VesselWavePage extends StatefulWidget {
  final VesselProfile currentVesselProfile;
  final LoadingCondition currentLoadingCondition;
  final NavigationInfo navigationInfo;
  final Function(VesselProfile,LoadingCondition, NavigationInfo) onValuesChanged;

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
  List<LoadingCondition> _savedConditions = [];
  int _currentPageIndex = 0; // 0: Vessel, 1: Loading, 2: Navigation
  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _conditionNameController = TextEditingController();
  late LoadingCondition _currentLoadingCondition;

  @override
  void initState() {
    super.initState();
    _currentVesselProfile = widget.currentVesselProfile;
    _navigationInfo = widget.navigationInfo;
    _currentLoadingCondition = widget.currentLoadingCondition;
    _loadSavedProfiles();
    _loadSavedConditions();
  }

  // Charge les profils sauvegardés
  Future<void> _loadSavedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profilesJson = prefs.getString('savedProfiles');

    if (profilesJson != null) {
      final List<dynamic> profilesList = json.decode(profilesJson);
      setState(() {
        _savedProfiles = profilesList
            .map((profile) => VesselProfile.fromMap(profile))
            .toList();
      });
    }
  }

  // Charge les conditions sauvegardées
  Future<void> _loadSavedConditions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? conditionsJson = prefs.getString('savedConditions');

    if (conditionsJson != null) {
      final List<dynamic> conditionsList = json.decode(conditionsJson);
      setState(() {
        _savedConditions = conditionsList
            .map((condition) => LoadingCondition.fromMap(condition))
            .toList();
      });
    }
  }

  // Sauvegarde les profils dans SharedPreferences
  Future<void> _saveProfilesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String profilesJson = json.encode(
      _savedProfiles.map((profile) => profile.toMap()).toList(),
    );
    await prefs.setString('savedProfiles', profilesJson);
  }

  // Sauvegarde les conditions dans SharedPreferences
  Future<void> _saveConditionsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String conditionsJson = json.encode(
      _savedConditions.map((condition) => condition.toMap()).toList(),
    );
    await prefs.setString('savedConditions', conditionsJson);
  }

  void _updateValues() {
    widget.onValuesChanged(_currentVesselProfile, _currentLoadingCondition,_navigationInfo);
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
                );

                setState(() {
                  _savedProfiles.add(newProfile);
                });

                await _saveProfilesToPrefs();
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
        title: const Text("Save Loading Condition"),
        content: TextField(
          controller: _conditionNameController,
          decoration: const InputDecoration(
            labelText: "Condition Name",
            hintText: "Enter condition name",
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
                  _savedConditions.add(newCondition);
                });

                await _saveConditionsToPrefs();
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _loadProfile(VesselProfile profile) {
    setState(() {
      _currentVesselProfile = profile;
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
    });
    await _saveProfilesToPrefs();
  }

  void _deleteCondition(int index) async {
    setState(() {
      _savedConditions.removeAt(index);
    });
    await _saveConditionsToPrefs();
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
          // Page 1: Vessel Info
          _buildVesselInfoPage(),
          // Page 2: Loading Info
          _buildLoadingInfoPage(),
          // Page 3: Navigation Info
          _buildNavigationInfoPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPageIndex,
        onTap: (index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_boat),
            label: 'Vessel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.balance),
            label: 'Loading',
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
            iconWidget: Icon(Icons.crop_landscape, size: 40, color: Color(0xFF012169)),
            label: "Beam (B)",
            unit: "m",
            value: _currentVesselProfile.beam,
            onChanged: (val) {
              setState(() => _currentVesselProfile = _currentVesselProfile.copyWith(beam: val));
              _updateValues();
            },
          ),
          _buildInputCard(
            iconWidget: Icon(Icons.water, size: 40, color: Color(0xFF012169)),
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
              // Met à jour l'état pendant que tu glisses
              setState(() => _navigationInfo = _navigationInfo.copyWith(course: val));
            },
            onChangeEnd: (val) {
              // Appelé seulement quand tu relâches le slider
              _updateValues();
            },
          ),
          _buildSliderCard(
            iconWidget: Image.asset('assets/images/direction.png', width: 40, height: 40),
            label: "Wave direction",
            unit: "°",
            value: _navigationInfo.direction,
            min: 0,
            max: 360,
            onChanged: (val) {
              // Met à jour l'état pendant que tu glisses
              setState(() => _navigationInfo = _navigationInfo.copyWith(direction: val));
            },
            onChangeEnd: (val) {
              // Appelé seulement quand tu relâches le slider
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  icon: const Icon(Icons.save, color: Color(0xFF012169)),
                  onPressed: _saveCurrentVesselProfile,
                  tooltip: "Save current profile",
                ),
              ],
            ),
            if (_savedProfiles.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
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
    );
  }

  Widget _buildConditionManagementSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  "Loading Condition",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.save, color: Color(0xFF012169)),
                  onPressed: _saveCurrentLoadingCondition,
                  tooltip: "Save current condition",
                ),
              ],
            ),
            if (_savedConditions.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _savedConditions.length,
                  itemBuilder: (context, index) {
                    final condition = _savedConditions[index];
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
    ValueChanged<double>? onChangeEnd, // 👈 ajouter ceci
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
                        "$label: ${value.toStringAsFixed(1)} $unit",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: ((max - min) ~/ 1),
                      label: value.toStringAsFixed(1),
                      onChanged: onChanged,
                      onChangeEnd: onChangeEnd, // 👈 ici
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
    final TextEditingController _controller = TextEditingController(text: value.toStringAsFixed(1));
    final FocusNode _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
    });

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

  Widget _buildInputField({
    required String label,
    required String unit,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final TextEditingController _controller = TextEditingController(text: value.toStringAsFixed(1));
    final FocusNode _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
    });

    return Column(
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
    );
  }
}