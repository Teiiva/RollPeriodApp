// info.dart
import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'models/vessel_profile.dart';
import 'models/navigation_info.dart';
import 'models/loading_condition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'storage_manager.dart';
import 'vessel_wave_painter.dart';

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
  late LoadingCondition _currentLoadingCondition;


  // Contrôleurs pour l'édition
  final _profileFormKey = GlobalKey<FormState>();
  final _conditionFormKey = GlobalKey<FormState>();
  final _profileNameController = TextEditingController();
  final _vesselLengthController = TextEditingController();
  final _vesselBeamController = TextEditingController();
  final _vesselDepthController = TextEditingController();
  final _conditionNameController = TextEditingController();
  final _conditionGmController = TextEditingController();
  final _conditionVcgController = TextEditingController();
  final _conditionDraftController = TextEditingController();

  // Styles
  late TextStyle titleStyle;
  late TextStyle subtitleStyle;
  late double cardRadius;
  late double iconSize;
  late EdgeInsets cardPadding;

  @override
  void initState() {
    super.initState();
    _currentVesselProfile = widget.currentVesselProfile;
    _navigationInfo = widget.navigationInfo;
    _currentLoadingCondition = widget.currentLoadingCondition;
    _loadSavedData();
    _initializeControllers();
  }

  void _initializeControllers() {
    _updateProfileControllers();
    _updateConditionControllers();
  }

  void _updateProfileControllers() {
    _profileNameController.text = _currentVesselProfile.name;
    _vesselLengthController.text = _currentVesselProfile.length.toStringAsFixed(2);
    _vesselBeamController.text = _currentVesselProfile.beam.toStringAsFixed(2);
    _vesselDepthController.text = _currentVesselProfile.depth.toStringAsFixed(2);
  }

  void _updateConditionControllers() {
    _conditionNameController.text = _currentLoadingCondition.name;
    _conditionGmController.text = _currentLoadingCondition.gm.toStringAsFixed(2);
    _conditionVcgController.text = _currentLoadingCondition.vcg.toStringAsFixed(2);
    _conditionDraftController.text = _currentLoadingCondition.draft.toStringAsFixed(2);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStyles();
  }


// Modifiez les styles dans _updateStyles pour prendre en compte le dark mode :
  void _updateStyles() {
    final screenWidth = MediaQuery.of(context).size.width;
    final ratio = screenWidth / 411.42857142857144;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    setState(() {
      titleStyle = TextStyle(
        fontSize: 16.0 * ratio,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.grey[300] : Colors.black,
      );
      subtitleStyle = TextStyle(
        fontSize: 14.0 * ratio,
        fontWeight: FontWeight.normal,
        color: isDarkMode ? Colors.grey[300] : Colors.black,
      );
      cardRadius = 12 * ratio;
      iconSize = 40.0 * ratio;
      cardPadding = EdgeInsets.all(16 * ratio);
    });
  }

  Future<void> _loadSavedData() async {
    _savedProfiles = await StorageManager.loadList(
      key: 'savedProfiles',
      fromMap: VesselProfile.fromMap,
    );

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

        _currentLoadingCondition = _currentVesselProfile.loadingConditions.isNotEmpty
            ? _currentVesselProfile.loadingConditions.first
            : LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4);
      });
      _initializeControllers();
    }
  }

  Future<void> _saveAllData() async {
    final index = _savedProfiles.indexWhere((p) => p.name == _currentVesselProfile.name);
    if (index != -1) {
      _savedProfiles[index] = _currentVesselProfile;
    } else {
      _savedProfiles.add(_currentVesselProfile);
    }

    await StorageManager.saveList(
      key: 'savedProfiles',
      items: _savedProfiles,
      toMap: (profile) => profile.toMap(),
    );

    await StorageManager.saveCurrent(
      key: 'currentProfile',
      item: _currentVesselProfile,
      toMap: (profile) => profile.toMap(),
    );
  }

  void _updateValues() {
    widget.onValuesChanged(_currentVesselProfile, _currentLoadingCondition, _navigationInfo);
    _saveAllData();
  }

  void _showEditProfileDialog({VesselProfile? profileToEdit}) {
    final isEditing = profileToEdit != null;

    if (isEditing) {
      _profileNameController.text = profileToEdit.name;
      _vesselLengthController.text = profileToEdit.length.toStringAsFixed(2);
      _vesselBeamController.text = profileToEdit.beam.toStringAsFixed(2);
      _vesselDepthController.text = profileToEdit.depth.toStringAsFixed(2);
    } else {
      _profileNameController.clear();
      _vesselLengthController.text = '0';
      _vesselBeamController.text = '0';
      _vesselDepthController.text = '0';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? "Edit Vessel Profile" : "Create New Profile"),
        content: Form(
          key: _profileFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _profileNameController,
                  decoration: InputDecoration(
                    labelText: "Profile Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a profile name';
                    }
                    if (!isEditing && _savedProfiles.any((p) => p.name == value)) {
                      return 'Profile name already exists';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _vesselLengthController,
                  decoration: InputDecoration(
                    labelText: "Length (m)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter length';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _vesselBeamController,
                  decoration: InputDecoration(
                    labelText: "Beam (m)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter beam';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _vesselDepthController,
                  decoration: InputDecoration(
                    labelText: "Depth (m)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter depth';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (_profileFormKey.currentState!.validate()) {
                _saveProfile(isEditing, profileToEdit);
                Navigator.pop(context);
              }
            },
            child: Text(isEditing ? "Update" : "Create"),
          ),
        ],
      ),
    );
  }

  void _saveProfile(bool isEditing, VesselProfile? profileToEdit) {
    final newProfile = VesselProfile(
      name: _profileNameController.text.trim(),
      length: double.parse(_vesselLengthController.text),
      beam: double.parse(_vesselBeamController.text),
      depth: double.parse(_vesselDepthController.text),
      loadingConditions: isEditing
          ? profileToEdit!.loadingConditions
          : [LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4)],
    );

    setState(() {
      if (isEditing) {
        final index = _savedProfiles.indexWhere((p) => p.name == profileToEdit!.name);
        _savedProfiles[index] = newProfile;
        if (_currentVesselProfile.name == profileToEdit!.name) {
          _currentVesselProfile = newProfile;
        }
      } else {
        _savedProfiles.add(newProfile);
        _currentVesselProfile = newProfile;
        _currentLoadingCondition = newProfile.loadingConditions.first;
      }
    });

    _updateValues();
  }

  void _showEditConditionDialog({LoadingCondition? conditionToEdit}) {
    final isEditing = conditionToEdit != null;

    if (isEditing) {
      _conditionNameController.text = conditionToEdit.name;
      _conditionGmController.text = conditionToEdit.gm.toStringAsFixed(2);
      _conditionVcgController.text = conditionToEdit.vcg.toStringAsFixed(2);
      _conditionDraftController.text = conditionToEdit.draft.toStringAsFixed(2);
    } else {
      _conditionNameController.clear();
      _conditionGmController.text = '0';
      _conditionVcgController.text = '0';
      _conditionDraftController.text = '0';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? "Edit Voyage" : "Create New Voyage"),
        content: Form(
          key: _conditionFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _conditionNameController,
                  decoration: InputDecoration(
                    labelText: "Voyage Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a voyage name';
                    }
                    if (!isEditing && _currentVesselProfile.loadingConditions.any((c) => c.name == value)) {
                      return 'Voyage name already exists';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _conditionGmController,
                  decoration: InputDecoration(
                    labelText: "GM (m)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter GM';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _conditionVcgController,
                  decoration: InputDecoration(
                    labelText: "VCG (m)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter VCG';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _conditionDraftController,
                  decoration: InputDecoration(
                    labelText: "Draft (m)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter draft';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (_conditionFormKey.currentState!.validate()) {
                _saveCondition(isEditing, conditionToEdit);
                Navigator.pop(context);
              }
            },
            child: Text(isEditing ? "Update" : "Create"),
          ),
        ],
      ),
    );
  }

  void _saveCondition(bool isEditing, LoadingCondition? conditionToEdit) {
    final newCondition = LoadingCondition(
      name: _conditionNameController.text.trim(),
      gm: double.parse(_conditionGmController.text),
      vcg: double.parse(_conditionVcgController.text),
      draft: double.parse(_conditionDraftController.text),
    );

    setState(() {
      if (isEditing) {
        final index = _currentVesselProfile.loadingConditions.indexWhere((c) => c.name == conditionToEdit!.name);
        _currentVesselProfile.loadingConditions[index] = newCondition;
        if (_currentLoadingCondition.name == conditionToEdit!.name) {
          _currentLoadingCondition = newCondition;
        }
      } else {
        _currentVesselProfile.loadingConditions.add(newCondition);
        _currentLoadingCondition = newCondition;
      }
    });

    _updateValues();
  }

  void _confirmDeleteProfile(VesselProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Profile?"),
        content: Text("Are you sure you want to delete '${profile.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _savedProfiles.removeWhere((p) => p.name == profile.name);
        if (_currentVesselProfile.name == profile.name) {
          _currentVesselProfile = _savedProfiles.isNotEmpty
              ? _savedProfiles.first
              : VesselProfile(
            name: "LPG Carrier",
            length: 107.0,
            beam: 17.6,
            depth: 9.8,
            loadingConditions: [LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4)],
          );
          _currentLoadingCondition = _currentVesselProfile.loadingConditions.first;
        }
      });
      _updateValues();
    }
  }

  void _confirmDeleteCondition(LoadingCondition condition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Voyage?"),
        content: Text("Are you sure you want to delete '${condition.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _currentVesselProfile.loadingConditions.removeWhere((c) => c.name == condition.name);

        // Si c'était le dernier voyage, créer un nouveau voyage par défaut
        if (_currentVesselProfile.loadingConditions.isEmpty) {
          final defaultCondition = LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4);
          _currentVesselProfile.loadingConditions.add(defaultCondition);
          _currentLoadingCondition = defaultCondition;
        }
        // Sinon, sélectionner le premier voyage disponible
        else if (_currentLoadingCondition.name == condition.name) {
          _currentLoadingCondition = _currentVesselProfile.loadingConditions.first;
        }
      });
      _updateValues();
    }
  }

  @override
  void dispose() {
    _profileNameController.dispose();
    _vesselLengthController.dispose();
    _vesselBeamController.dispose();
    _vesselDepthController.dispose();
    _conditionNameController.dispose();
    _conditionGmController.dispose();
    _conditionVcgController.dispose();
    _conditionDraftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final basscreenWidth = 411.42857142857144;
    final screenWidth = MediaQuery.of(context).size.width;
    final ratio = screenWidth / basscreenWidth;
    final double paddingValue = 2 * ratio;

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
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: isDarkMode ? Colors.white : const Color(0xFF012169),
        unselectedItemColor: isDarkMode ? Colors.grey[500] : Colors.grey,
        iconSize: 26.0 * ratio,
        selectedFontSize: 14.0 * ratio,
        unselectedFontSize: 12.0 * ratio,
        selectedLabelStyle:  TextStyle(height: 0),
        unselectedLabelStyle:  TextStyle(height: 0),
        items: [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: paddingValue, bottom: paddingValue),
              child: const Icon(Icons.directions_boat),
            ),
            label: 'Vessel',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: paddingValue, bottom: paddingValue),
              child: const Icon(Icons.balance),
            ),
            label: 'Voyage',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: paddingValue, bottom: paddingValue),
              child: const Icon(Icons.navigation),
            ),
            label: 'Navigation',
          ),
        ],
      ),
    );
  }

  Widget _buildVesselInfoPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileManagementSection(),
          SizedBox(height: 16),
          _buildVesselDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildLoadingInfoPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildConditionManagementSection(),
          SizedBox(height: 16),
          _buildConditionDetailsCard(),
        ],
      ),
    );
  }

  // Modifiez _buildInputCard pour le dark mode :
  Widget _buildInputCard({
    required Widget iconWidget,
    required String label,
    required String unit,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final _controller = TextEditingController(text: value.toStringAsFixed(2));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
      child: Card(
        elevation: 1,
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: titleStyle.copyWith(
                            fontWeight: FontWeight.normal,
                            color: isDarkMode ? Colors.grey[300] : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey[700]
                              : const Color(0xFF012169).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[300] : Colors.black,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: value.toStringAsFixed(2),
                            hintStyle: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey.shade500,
                            ),
                            suffixText: unit,
                            suffixStyle: TextStyle(
                              color: isDarkMode ? Colors.grey[300] : Colors.black,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onSubmitted: (text) {
                            final parsedValue = double.tryParse(text);
                            if (parsedValue != null) {
                              onChanged(parsedValue);
                            }
                          },
                        ),
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



  // Modifiez _buildSliderCard pour le dark mode :
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
      child: Card(
        elevation: 1,
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(
                  color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169),
                ),
                child: iconWidget,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$label: ${value.toStringAsFixed(2)} $unit",
                      style: subtitleStyle.copyWith(
                        color: isDarkMode ? Colors.grey[300] : Colors.black,
                      ),
                    ),
                    Slider(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      value: value,
                      min: min,
                      max: max,
                      divisions: ((max - min) ~/ 1),
                      label: value.toStringAsFixed(2),
                      activeColor: isDarkMode ? Colors.white : Color(0xFF012169),
                      inactiveColor: isDarkMode ? Colors.grey[600] : Colors.grey[300],
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

  // Puis modifiez la méthode _buildNavigationInfoPage comme suit:
  Widget _buildNavigationInfoPage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildWaveAnimationCard(), // Ajoutez cette ligne en premier
          _buildSliderCard(
            iconWidget: Icon(Icons.navigation, size: iconSize, color: isDarkMode ? Colors.grey[300] : Color(0xFF012169)),
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
            iconWidget: Image.asset('assets/images/direction.png', width: iconSize, height: iconSize, color: isDarkMode ? Colors.grey[300] : Color(0xFF012169)),
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
            iconWidget: Icon(Icons.waves, size: iconSize, color: isDarkMode ? Colors.grey[300] : Color(0xFF012169)),
            label: "Waves period",
            unit: "s",
            value: _navigationInfo.wavePeriod,
            onChanged: (val) {
              setState(() => _navigationInfo = _navigationInfo.copyWith(wavePeriod: val));
              _updateValues();
            },
          ),
          _buildInputCard(
            iconWidget: Icon(Icons.speed, size: iconSize, color: isDarkMode ? Colors.grey[300] : Color(0xFF012169)),
            label: "Vessel speed",
            unit: "Knots",
            value: _navigationInfo.speed,
            onChanged: (val) {
              setState(() => _navigationInfo = _navigationInfo.copyWith(speed: val));
              _updateValues();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileManagementSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Padding(
        padding: cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Vessel Profiles",
                  style: titleStyle.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add,
                      color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                  onPressed: () => _showEditProfileDialog(),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (_savedProfiles.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "No profiles yet. Create your first vessel profile.",
                  style: subtitleStyle.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey),
                ),
              ),
            if (_savedProfiles.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _savedProfiles.map((profile) {
                  return InputChip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: Icon(
                          Icons.directions_boat,
                          size: 20,
                          color: _currentVesselProfile.name == profile.name
                              ? Colors.white
                              : isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                    ),
                    label: Text(profile.name),
                    backgroundColor: _currentVesselProfile.name == profile.name
                        ? isDarkMode ? Colors.teal : Color(0xFF012169)
                        : isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    labelStyle: TextStyle(
                      color: _currentVesselProfile.name == profile.name
                          ? Colors.white
                          : isDarkMode ? Colors.grey[300] : Colors.black,
                    ),
                    side: BorderSide.none, // 🔥 supprime la bordure
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none, // 🔥 aucun contour visible
                    ),
                    onPressed: () {
                      setState(() {
                        _currentVesselProfile = profile;
                        _currentLoadingCondition = profile.loadingConditions.isNotEmpty
                            ? profile.loadingConditions.first
                            : LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4);
                      });
                      _updateValues();
                    },
                    onDeleted: () => _confirmDeleteProfile(profile),
                    deleteIcon: Icon(Icons.close,
                        size: 18,
                        color: _currentVesselProfile.name == profile.name
                            ? Colors.white
                            : isDarkMode ? Colors.grey[300] : Colors.black),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionManagementSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Padding(
        padding: cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Voyages for ${_currentVesselProfile.name}",
                  style: titleStyle.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add,
                      color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                  onPressed: () => _showEditConditionDialog(),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (_currentVesselProfile.loadingConditions.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "No voyages yet. Create your first voyage for this vessel.",
                  style: subtitleStyle.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey),
                ),
              ),
            if (_currentVesselProfile.loadingConditions.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentVesselProfile.loadingConditions.map((condition) {
                  return InputChip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: Icon(
                          Icons.balance,
                          size: 20,
                          color: _currentLoadingCondition.name == condition.name
                              ? Colors.white
                              : isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                    ),
                    label: Text(condition.name),
                    backgroundColor: _currentLoadingCondition.name == condition.name
                        ? isDarkMode ? Colors.teal : Color(0xFF012169)
                        : isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    labelStyle: TextStyle(
                      color: _currentLoadingCondition.name == condition.name
                          ? Colors.white
                          : isDarkMode ? Colors.grey[300] : Colors.black,
                    ),
                    side: BorderSide.none, // 🔥 supprime la bordure
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none, // 🔥 aucun contour visible
                    ),
                    onPressed: () {
                      setState(() {
                        _currentLoadingCondition = condition;
                      });
                      _updateValues();
                    },
                    onDeleted: () => _confirmDeleteCondition(condition),
                    deleteIcon: Icon(Icons.close,
                        size: 18,
                        color: _currentLoadingCondition.name == condition.name
                            ? Colors.white
                            : isDarkMode ? Colors.grey[300] : Colors.black),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVesselDetailsCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Padding(
        padding: cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Vessel Details",
                  style: titleStyle.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit,
                      color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                  onPressed: () => _showEditProfileDialog(profileToEdit: _currentVesselProfile),
                ),
              ],
            ),
            SizedBox(height: 8),
            _buildDetailRow("Name", _currentVesselProfile.name),
            _buildDetailRow("Length", "${_currentVesselProfile.length.toStringAsFixed(2)} m"),
            _buildDetailRow("Beam", "${_currentVesselProfile.beam.toStringAsFixed(2)} m"),
            _buildDetailRow("Depth", "${_currentVesselProfile.depth.toStringAsFixed(2)} m"),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionDetailsCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Padding(
        padding: cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Voyage Details",
                  style: titleStyle.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit,
                      color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                  onPressed: () => _showEditConditionDialog(conditionToEdit: _currentLoadingCondition),
                ),
              ],
            ),
            SizedBox(height: 8),
            _buildDetailRow("Name", _currentLoadingCondition.name),
            _buildDetailRow("GM", "${_currentLoadingCondition.gm.toStringAsFixed(2)} m"),
            _buildDetailRow("VCG", "${_currentLoadingCondition.vcg.toStringAsFixed(2)} m"),
            _buildDetailRow("Draft", "${_currentLoadingCondition.draft.toStringAsFixed(2)} m"),
          ],
        ),
      ),
    );
  }


  Widget _buildDetailRow(String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: subtitleStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: subtitleStyle.copyWith(
                color: isDarkMode ? Colors.grey[300] : Colors.black,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }



  // Modifiez _buildWaveAnimationCard pour le dark mode :
  Widget _buildWaveAnimationCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(left: 20, top: 8 ,right: 20, bottom: 1),
      child: Card(
        elevation: 1,
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 300,
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Transform.rotate(
                    angle: 0,
                    child: VesselWavePainter(
                      boatlength: _currentVesselProfile.length,
                      waveDirection: _navigationInfo.direction,
                      wavePeriod: _navigationInfo.wavePeriod,
                      course: _navigationInfo.course,
                      isDarkMode: isDarkMode, // Assurez-vous que VesselWavePainter accepte ce paramètre
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}