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

  void _updateStyles() {
    final screenWidth = MediaQuery.of(context).size.width;
    final ratio = screenWidth / 411.42857142857144;

    setState(() {
      titleStyle = TextStyle(
        fontSize: 16.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      );
      subtitleStyle = TextStyle(
        fontSize: 14.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.black,
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
            : LoadingCondition(name: "Default", gm: 0, vcg: 0, draft: 0);
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
          ElevatedButton(
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
          : [LoadingCondition(name: "Default", gm: 0, vcg: 0, draft: 0)],
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
          ElevatedButton(
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
            name: "Default",
            length: 0,
            beam: 0,
            depth: 0,
            loadingConditions: [LoadingCondition(name: "Default", gm: 0, vcg: 0, draft: 0)],
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
          final defaultCondition = LoadingCondition(name: "Default", gm: 0, vcg: 0, draft: 0);
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

  Widget _buildInputCard({
    required Widget iconWidget,
    required String label,
    required String unit,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final _controller = TextEditingController(text: value.toStringAsFixed(2));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
                      style: subtitleStyle,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: unit,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.number,
                      style: subtitleStyle,
                      onTap: () {
                        // Sélectionne tout le texte lorsque le champ est tapé
                        _controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _controller.text.length,
                        );
                      },
                      onSubmitted: (text) {
                        final parsedValue = double.tryParse(text);
                        if (parsedValue != null) {
                          onChanged(parsedValue);
                        }

                      },
                      onEditingComplete: () {
                        // Valide et met à jour la valeur lorsque l'édition est terminée
                        final parsedValue = double.tryParse(_controller.text);
                        if (parsedValue != null) {
                          onChanged(parsedValue);
                        }
                      },
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      "$label: ${value.toStringAsFixed(2)} $unit",
                      style: subtitleStyle,
                    ),
                    Slider(
                      padding: EdgeInsets.symmetric(horizontal: 10,vertical: 8),
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

  // Puis modifiez la méthode _buildNavigationInfoPage comme suit:
  Widget _buildNavigationInfoPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildWaveAnimationCard(), // Ajoutez cette ligne en premier
          _buildSliderCard(
            iconWidget: Icon(Icons.navigation, size: 40, color: Color(0xFF012169)),
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
            iconWidget: Icon(Icons.waves, size: 40, color: Color(0xFF002868)),
            label: "Waves period",
            unit: "s",
            value: _navigationInfo.wavePeriod,
            onChanged: (val) {
              setState(() => _navigationInfo = _navigationInfo.copyWith(wavePeriod: val));
              _updateValues();
            },
          ),
          _buildInputCard(
            iconWidget: Icon(Icons.speed, size: 40, color: Color(0xFF012169)),
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
    return Card(
      elevation: 2,
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
                  style: titleStyle,
                ),
                IconButton(
                  icon: Icon(Icons.add, color: Color(0xFF012169)),
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
                  style: subtitleStyle.copyWith(color: Colors.grey),
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
                              : Color(0xFF012169)),
                    ),
                    label: Text(profile.name),
                    backgroundColor: _currentVesselProfile.name == profile.name
                        ? Color(0xFF012169)
                        : Colors.white,
                    labelStyle: TextStyle(
                      color: _currentVesselProfile.name == profile.name
                          ? Colors.white
                          : Colors.black,
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
                    deleteIcon: Icon(Icons.close, size: 18,color: _currentVesselProfile.name == profile.name
                    ? Colors.white
                        : Colors.black,),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionManagementSection() {
    return Card(
      elevation: 2,
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
                  style: titleStyle,
                ),
                IconButton(
                  icon: Icon(Icons.add, color: Color(0xFF012169)),
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
                  style: subtitleStyle.copyWith(color: Colors.grey),
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
                              : Color(0xFF012169)),
                    ),
                  label: Text(condition.name),
                  backgroundColor: _currentLoadingCondition.name == condition.name
                  ? Color(0xFF012169)
                      : Colors.grey[200],
                  labelStyle: TextStyle(
                  color: _currentLoadingCondition.name == condition.name
                  ? Colors.white
                      : Colors.black,
                  ),
                  onPressed: () {
                  setState(() {
                  _currentLoadingCondition = condition;
                  });
                  _updateValues();
                  },
                  onDeleted: () => _confirmDeleteCondition(condition),
                    deleteIcon: Icon(Icons.close, size: 18,color: _currentLoadingCondition.name == condition.name
                        ? Colors.white
                        : Colors.black,),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVesselDetailsCard() {
    return Card(
      elevation: 2,
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
                  style: titleStyle,
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Color(0xFF012169)),
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
    return Card(
      elevation: 2,
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
                  style: titleStyle,
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Color(0xFF012169)),
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

  Widget _buildNavigationDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Padding(
        padding: cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Navigation Details",
              style: titleStyle,
            ),
            SizedBox(height: 8),
            _buildNavigationInput(
              icon: Icons.speed,
              label: "Vessel Speed",
              unit: "knots",
              value: _navigationInfo.speed,
              onChanged: (val) {
                setState(() => _navigationInfo = _navigationInfo.copyWith(speed: val));
                _updateValues();
              },
            ),
            _buildNavigationSlider(
              icon: Icons.navigation,
              label: "Course",
              unit: "°",
              value: _navigationInfo.course,
              min: 0,
              max: 360,
              onChanged: (val) {
                setState(() => _navigationInfo = _navigationInfo.copyWith(course: val));
              },
              onChangeEnd: (val) => _updateValues(),
            ),
            _buildNavigationSlider(
              icon: Icons.waves,
              label: "Wave Direction",
              unit: "°",
              value: _navigationInfo.direction,
              min: 0,
              max: 360,
              onChanged: (val) {
                setState(() => _navigationInfo = _navigationInfo.copyWith(direction: val));
              },
              onChangeEnd: (val) => _updateValues(),
            ),
            _buildNavigationInput(
              icon: Icons.timer,
              label: "Wave Period",
              unit: "s",
              value: _navigationInfo.wavePeriod,
              onChanged: (val) {
                setState(() => _navigationInfo = _navigationInfo.copyWith(wavePeriod: val));
                _updateValues();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: subtitleStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: subtitleStyle,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationInput({
    required IconData icon,
    required String label,
    required String unit,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final controller = TextEditingController(text: value.toStringAsFixed(2));

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: Color(0xFF012169)),
          SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "$label ($unit)",
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.check),
                  onPressed: () {
                    final parsedValue = double.tryParse(controller.text);
                    if (parsedValue != null) {
                      onChanged(parsedValue);
                    }
                  },
                ),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (value) {
                final parsedValue = double.tryParse(value);
                if (parsedValue != null) {
                  onChanged(parsedValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationSlider({
    required IconData icon,
    required String label,
    required String unit,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: iconSize, color: Color(0xFF012169)),
              SizedBox(width: 16),
              Text(
                "$label: ${value.toStringAsFixed(1)} $unit",
                style: subtitleStyle,
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }

  Widget _buildWaveAnimationCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 300, // Utilisez la même hauteur que pour votre animation principale
          padding: EdgeInsets.symmetric(horizontal: 30,vertical: 0),
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