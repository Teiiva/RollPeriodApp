// info.dart
import 'package:flutter/material.dart';
import 'widgets/custom_app_bar.dart';
import 'models/vessel_profile.dart';
import 'models/loading_condition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'storage_manager.dart';

class VesselWavePage extends StatefulWidget {
  final VesselProfile currentVesselProfile;
  final LoadingCondition currentLoadingCondition;
  final Function(VesselProfile, LoadingCondition) onValuesChanged;

  const VesselWavePage({
    super.key,
    required this.currentVesselProfile,
    required this.currentLoadingCondition,
    required this.onValuesChanged,
  });

  @override
  State<VesselWavePage> createState() => _VesselWavePageState();
}

class _VesselWavePageState extends State<VesselWavePage> {
  late VesselProfile _currentVesselProfile;
  List<VesselProfile> _savedProfiles = [];
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

  void _updateStyles() {
    final screenWidth = MediaQuery.of(context).size.width;
    final ratio = screenWidth / 411.42857142857144;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    setState(() {
      titleStyle = TextStyle(
        fontSize: 14.0 * ratio, // Réduit de 16 à 14
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.grey[300] : Colors.black,
      );
      subtitleStyle = TextStyle(
        fontSize: 12.0 * ratio, // Réduit de 14 à 12
        fontWeight: FontWeight.normal,
        color: isDarkMode ? Colors.grey[300] : Colors.black,
      );
      cardRadius = 8 * ratio; // Réduit de 12 à 8
      iconSize = 32.0 * ratio; // Réduit de 40 à 32
      cardPadding = EdgeInsets.all(8 * ratio); // Réduit de 16 à 8
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
    widget.onValuesChanged(_currentVesselProfile, _currentLoadingCondition);
    _saveAllData();
  }

  void _showEditProfileDialog({VesselProfile? profileToEdit}) {
    final isEditing = profileToEdit != null;

    if (isEditing) {
      // Ajout de ! pour indiquer qu'on est sûr que profileToEdit n'est pas null ici
      _profileNameController.text = profileToEdit!.name;
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
          ? profileToEdit?.loadingConditions ??
          [LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4)]
          : [LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4)],
    );

    setState(() {
      if (isEditing && profileToEdit != null) {
        final index = _savedProfiles.indexWhere((p) => p.name == profileToEdit.name);
        if (index != -1) {
          _savedProfiles[index] = newProfile;
        }
        if (_currentVesselProfile.name == profileToEdit.name) {
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

  void _confirmDeleteCondition(LoadingCondition condition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Voyage?"),
        content: Text("Are you sure you want to delete '${condition.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _currentVesselProfile.loadingConditions.removeWhere((c) => c.name == condition.name);

        // Si c'était la dernière condition, créer une nouvelle condition par défaut
        if (_currentVesselProfile.loadingConditions.isEmpty) {
          final defaultCondition = LoadingCondition(
              name: "Default",
              gm: 0,
              vcg: 0,
              draft: 0
          );
          _currentVesselProfile.loadingConditions.add(defaultCondition);
          _currentLoadingCondition = defaultCondition;
        }
        // Sinon, sélectionner la première condition disponible
        else if (_currentLoadingCondition.name == condition.name) {
          _currentLoadingCondition = _currentVesselProfile.loadingConditions.first;
        }
      });
      _updateValues();
    }
  }

  void _confirmDeleteProfile(VesselProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Profile?"),
        content: Text("Are you sure you want to delete '${profile.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _savedProfiles.removeWhere((p) => p.name == profile.name);

        // If we're deleting the current profile, switch to another one if available
        if (_currentVesselProfile.name == profile.name) {
          _currentVesselProfile = _savedProfiles.isNotEmpty
              ? _savedProfiles.first
              : VesselProfile(
            name: "New Vessel",
            length: 0,
            beam: 0,
            depth: 0,
            loadingConditions: [
              LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4)
            ],
          );

          _currentLoadingCondition = _currentVesselProfile.loadingConditions.first;
        }
      });
      _updateValues();
    }
  }

  void _showEditConditionDialog({LoadingCondition? conditionToEdit}) {
    final isEditing = conditionToEdit != null;

    if (isEditing) {
      _conditionNameController.text = conditionToEdit!.name;
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
                    if (!isEditing &&
                        _currentVesselProfile.loadingConditions.any((c) => c.name == value)) {
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
      if (isEditing && conditionToEdit != null) {
        final index = _currentVesselProfile.loadingConditions
            .indexWhere((c) => c.name == conditionToEdit.name);
        if (index != -1) {
          _currentVesselProfile.loadingConditions[index] = newCondition;
        }
        if (_currentLoadingCondition.name == conditionToEdit.name) {
          _currentLoadingCondition = newCondition;
        }
      } else {
        _currentVesselProfile.loadingConditions.add(newCondition);
        _currentLoadingCondition = newCondition;
      }
    });

    _updateValues();
  }

  Widget _buildInputCard({
    required Widget iconWidget,
    required String label,
    required String unit,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        label,
                        style: titleStyle.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          style: TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            labelText: label,  // Added this line to fix the error
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(text: value.toStringAsFixed(2)),
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

  Widget _buildProfileManagementSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16,top: 4, bottom: 8), // Augmenté le padding horizontal
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "VESSEL PROFILES",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.add,
                      color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                  onPressed: () => _showEditProfileDialog(),
                ),
              ],
            ),
            if (_savedProfiles.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  "No profiles yet. Create your first vessel profile.",
                  style: subtitleStyle.copyWith(
                      fontSize: 11,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey),
                ),
              ),
            if (_savedProfiles.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 100,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _savedProfiles.map((profile) {
                      return InputChip(
                        avatar: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: Icon(
                            Icons.directions_boat,
                            size: 18, // Icône plus petite
                            color: _currentVesselProfile.name == profile.name
                                ? Colors.white
                                : isDarkMode ? Colors.grey[300] : const Color(0xFF012169),
                          ),
                        ),
                        label: Text(
                          profile.name,
                          style: TextStyle(fontSize: 11), // Texte plus petit
                        ),
                        backgroundColor: _currentVesselProfile.name == profile.name
                            ? isDarkMode ? Colors.teal : Color(0xFF012169)
                            : isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        labelStyle: TextStyle(
                          color: _currentVesselProfile.name == profile.name
                              ? Colors.white
                              : isDarkMode ? Colors.grey[300] : Colors.black,
                        ),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onPressed: () {
                          setState(() {
                            _currentVesselProfile = profile;
                            _currentLoadingCondition = profile.loadingConditions.isNotEmpty
                                ? profile.loadingConditions.first
                                : LoadingCondition(name: "Default", gm: 0, vcg: 0, draft: 0);
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
                ),
              ),],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(8), // Réduit de 16 à 8
        child: Column(
          children: [
            _buildProfileManagementSection(),
            SizedBox(height: 6), // Réduit de 16 à 8
            _buildVesselDetailsCard(),
            SizedBox(height: 6), // Réduit de 24 à 12
            _buildConditionManagementSection(),
            SizedBox(height: 6), // Réduit de 16 à 8
            _buildConditionDetailsCard(),
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
    ValueChanged<double>? onChangeEnd,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    const double step = 1.0;

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
                      "$label: ${value.toStringAsFixed(0)} $unit",
                      style: subtitleStyle.copyWith(
                        color: isDarkMode ? Colors.grey[300] : Colors.black,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Slider(
                            value: value,
                            min: min,
                            max: max,
                            divisions: ((max - min) ~/ step),
                            label: value.toStringAsFixed(0),
                            activeColor: isDarkMode ? Colors.white : const Color(0xFF012169),
                            inactiveColor: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                            onChanged: onChanged,
                            onChangeEnd: onChangeEnd,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                double newValue = (value + step).clamp(min, max);
                                onChanged(newValue);
                                if (onChangeEnd != null) onChangeEnd(newValue);
                              },
                              child: Icon(
                                Icons.add,
                                size: 16,
                                color: isDarkMode ? Colors.grey[300] : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2), // très petit espace
                            GestureDetector(
                              onTap: () {
                                double newValue = (value - step).clamp(min, max);
                                onChanged(newValue);
                                if (onChangeEnd != null) onChangeEnd(newValue);
                              },
                              child: Icon(
                                Icons.remove,
                                size: 16,
                                color: isDarkMode ? Colors.grey[300] : Colors.black,
                              ),
                            ),
                          ],
                        ),


                      ],
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



  Widget _buildConditionManagementSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16,top: 4, bottom: 8), // Augmenté le padding horizontal
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "VOYAGE FOR ${_currentVesselProfile.name.toUpperCase()}",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add,
                      color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                  onPressed: () => _showEditConditionDialog(),
                ),
              ],
            ),
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
        padding: EdgeInsets.only(left: 16, right: 16,top: 4, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "VESSEL DETAILS",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit,
                      color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                  onPressed: () => _showEditProfileDialog(profileToEdit: _currentVesselProfile),
                ),
              ],
            ),
            _buildDetailRow("Vessel name", _currentVesselProfile.name),
            _buildDetailRow("Over all length", "${_currentVesselProfile.length.toStringAsFixed(2)} m"),
            _buildDetailRow("Max beam", "${_currentVesselProfile.beam.toStringAsFixed(2)} m"),
            _buildDetailRow("To main deck depth", "${_currentVesselProfile.depth.toStringAsFixed(2)} m"),
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
        padding: EdgeInsets.only(left: 16, right: 16,top: 4, bottom: 8), // Augmenté le padding horizontal
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "VOYAGE DETAILS",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit,
                      color: isDarkMode ? Colors.grey[300] : const Color(0xFF012169)),
                  onPressed: () => _showEditConditionDialog(conditionToEdit: _currentLoadingCondition),
                ),
              ],
            ),
            _buildDetailRow("Voyage name", _currentLoadingCondition.name),
            _buildDetailRow("GM without FSC", "${_currentLoadingCondition.gm.toStringAsFixed(2)} m"),
            _buildDetailRow("VCG without FSC", "${_currentLoadingCondition.vcg.toStringAsFixed(2)} m"),
            _buildDetailRow("Mean Draft", "${_currentLoadingCondition.draft.toStringAsFixed(2)} m"),
            Text(
              "FSC = Free Surface Correction",
              style: titleStyle.copyWith(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                fontStyle: FontStyle.italic,
                fontSize: 9,
              ),
            )

          ],
        ),
      ),
    );
  }


  Widget _buildDetailRow(String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4), // Réduit de 8 à 4
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: subtitleStyle.copyWith(
                fontSize: 12, // Texte plus petit
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: subtitleStyle.copyWith(
                fontSize: 12, // Texte plus petit
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

}