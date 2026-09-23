import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vessel_profile.dart';
import '../models/loading_condition.dart';
import '../storage_manager.dart';

class VesselSelectionProvider extends ChangeNotifier {
  List<VesselProfile> _savedProfiles = [];
  VesselProfile? _currentVesselProfile;
  LoadingCondition? _currentLoadingCondition;
  bool _initialized = false;

  List<VesselProfile> get savedProfiles => _savedProfiles;
  VesselProfile? get currentVesselProfile => _currentVesselProfile;
  LoadingCondition? get currentLoadingCondition => _currentLoadingCondition;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadSavedProfiles();
    await _loadStoredProfile();
  }

  Future<void> _loadSavedProfiles() async {
    _savedProfiles = await StorageManager.loadList(
      key: 'savedProfiles',
      fromMap: VesselProfile.fromMap,
    );
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

    if (storedProfile == null) {
      _currentVesselProfile = VesselProfile(
        name: "LPG Carrier",
        length: 107.0,
        beam: 17.6,
        depth: 9.8,
        iso: 0,
        shiptype: "Other",
        loadingConditions: [LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4)],
      );
      _currentLoadingCondition = _currentVesselProfile!.loadingConditions.first;
      notifyListeners();
      return;
    }

    _currentVesselProfile = storedProfile;
    if (!_savedProfiles.any((p) => p.name == storedProfile.name)) {
      _savedProfiles = [..._savedProfiles, storedProfile];
    }

    _currentLoadingCondition = storedConditionName != null
        ? storedProfile.loadingConditions.firstWhere(
          (c) => c.name == storedConditionName,
      orElse: () => storedProfile.loadingConditions.first,
    )
        : (storedProfile.loadingConditions.isNotEmpty
        ? storedProfile.loadingConditions.first
        : LoadingCondition(name: "Ballast", gm: 1.2, vcg: 6.6, draft: 5.4));

    notifyListeners();
  }

  Future<void> selectVessel(VesselProfile profile) async {
    _currentVesselProfile = profile;
    _currentLoadingCondition = profile.loadingConditions.isNotEmpty ? profile.loadingConditions.first : null;
    notifyListeners();
    await _saveAllData();
  }

  Future<void> selectLoadingCondition(LoadingCondition condition) async {
    _currentLoadingCondition = condition;
    notifyListeners();
    await _saveAllData();
  }

  Future<void> _saveAllData() async {
    final index = _savedProfiles.indexWhere((p) => p.name == _currentVesselProfile?.name);
    if (index != -1) {
      _savedProfiles[index] = _currentVesselProfile!;
    } else if (_currentVesselProfile != null) {
      _savedProfiles.add(_currentVesselProfile!);
    }

    await StorageManager.saveList(
      key: 'savedProfiles',
      items: _savedProfiles,
      toMap: (profile) => profile.toMap(),
    );
    await StorageManager.saveCurrent(
      key: 'currentProfile',
      item: _currentVesselProfile,
      toMap: (profile) => profile!.toMap(),
    );
    await StorageManager.saveCurrent(
      key: 'currentCondition',
      item: _currentLoadingCondition,
      toMap: (condition) => condition!.toMap(),
    );
  }

  Future<void> addOrUpdateProfile(VesselProfile profile, {VesselProfile? oldProfile}) async {
    final index = oldProfile != null ? _savedProfiles.indexWhere((p) => p.name == oldProfile.name) : -1;
    _savedProfiles = index != -1
        ? ([..._savedProfiles]..[index] = profile)
        : [..._savedProfiles, profile];

    final wasCurrent = oldProfile != null && _currentVesselProfile?.name == oldProfile.name;
    if (wasCurrent || oldProfile == null) {
      _currentVesselProfile = profile;
      _currentLoadingCondition = profile.loadingConditions.isNotEmpty ? profile.loadingConditions.first : null;
    }

    notifyListeners();
    await _saveAllData();
  }

  Future<void> addOrUpdateLoadingCondition(LoadingCondition condition, {LoadingCondition? oldCondition}) async {
    final profile = _currentVesselProfile;
    if (profile == null) return;

    final conditions = [...profile.loadingConditions];
    final index = oldCondition != null ? conditions.indexWhere((c) => c.name == oldCondition.name) : -1;
    if (index != -1) {
      conditions[index] = condition;
    } else {
      conditions.add(condition);
    }

    final updatedProfile = VesselProfile(
      name: profile.name,
      length: profile.length,
      beam: profile.beam,
      depth: profile.depth,
      iso: profile.iso,
      shiptype: profile.shiptype,
      loadingConditions: conditions,
    );

    _currentVesselProfile = updatedProfile;
    _currentLoadingCondition = condition;

    final profileIndex = _savedProfiles.indexWhere((p) => p.name == profile.name);
    if (profileIndex != -1) {
      _savedProfiles = [..._savedProfiles]..[profileIndex] = updatedProfile;
    }

    notifyListeners();
    await _saveAllData();
  }
}

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? leading;
  final List<Widget>? actions;
  final GlobalKey? vesselButtonKey;
  final GlobalKey? loadingButtonKey;

  const CustomAppBar({super.key, this.leading, this.actions, this.vesselButtonKey, this.loadingButtonKey});

  @override
  Size get preferredSize => const Size.fromHeight(100);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  final _profileFormKey = GlobalKey<FormState>();
  final _profileNameController = TextEditingController();
  final _vesselLengthController = TextEditingController();
  final _vesselBeamController = TextEditingController();
  final _vesselDepthController = TextEditingController();
  final _isoController = TextEditingController();
  String? _selectedShipType;

  final _conditionFormKey = GlobalKey<FormState>();
  final _conditionNameController = TextEditingController();
  final _gmController = TextEditingController();
  final _vcgController = TextEditingController();
  final _draftController = TextEditingController();

  @override
  void dispose() {
    _profileNameController.dispose();
    _vesselLengthController.dispose();
    _vesselBeamController.dispose();
    _vesselDepthController.dispose();
    _isoController.dispose();
    _conditionNameController.dispose();
    _gmController.dispose();
    _vcgController.dispose();
    _draftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final selection = context.watch<VesselSelectionProvider>();

    return AppBar(
      actions: widget.actions,
      centerTitle: true,
      flexibleSpace: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            isDarkMode ? 'assets/images/logo_marin_dark.png' : 'assets/images/logo_marin.png',
            width: 120,
            height: 50,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDropdownMenu<VesselProfile>(
                key: widget.vesselButtonKey,
                icon: Icons.directions_boat,
                label: selection.currentVesselProfile?.name ?? 'No vessel selected',
                items: selection.savedProfiles,
                defaultValue: VesselProfile.defaultVessel,
                labelOf: (p) => p.name,
                onSelected: (profile) => context.read<VesselSelectionProvider>().selectVessel(profile),
                onAddNew: () => _showEditProfileDialog(),
                onEdit: (item) => _showEditProfileDialog(profileToEdit: item),
                addNewLabel: 'New vessel',
                editTooltip: 'Edit vessel',
              ),
              _buildDropdownMenu<LoadingCondition>(
                key: widget.loadingButtonKey,
                icon: Icons.map,
                label: selection.currentLoadingCondition?.name ?? 'No Voyage selected',
                items: selection.currentVesselProfile?.loadingConditions ?? [],
                defaultValue: LoadingCondition.defaultLoading,
                labelOf: (c) => c.name,
                onSelected: (condition) =>
                    context.read<VesselSelectionProvider>().selectLoadingCondition(condition),
                onAddNew: selection.currentVesselProfile == null ? null : () => _showEditConditionDialog(),
                onEdit: (item) => _showEditConditionDialog(conditionToEdit: item),
                addNewLabel: 'New Voyage',
                editTooltip: 'Edit Voyage',
              ),
            ],
          ),
        ],
      ),
      leading: widget.leading,
      backgroundColor: isDarkMode ? Colors.grey[850] : const Color(0xFF012169),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildDropdownMenu<Type>({
    Key? key,
    required IconData icon,
    required String label,
    required List<Type> items,
    required Type defaultValue,
    required String Function(Type) labelOf,
    required ValueChanged<Type> onSelected,
    required VoidCallback? onAddNew,
    required void Function(Type item) onEdit,
    required String addNewLabel,
    required String editTooltip,
  }) {
    final canAddNew = onAddNew != null;

    return PopupMenuButton<Type>(
      key: key,
      onSelected: (value) => value == defaultValue ? onAddNew?.call() : onSelected(value),
      itemBuilder: (context) => [
        ...items.map(
              (item) => PopupMenuItem<Type>(
            value: item,
            child: Row(
              children: [
                Text(labelOf(item)),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF012169), size: 18),
                  tooltip: editTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => onEdit(item),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<Type>(
          value: defaultValue,
          enabled: canAddNew,
          child: Row(
            children: [
              Icon(Icons.add, size: 18, color: canAddNew ? const Color(0xFF012169) : Colors.grey),
              const SizedBox(width: 6),
              Text(addNewLabel, style: TextStyle(color: canAddNew ? const Color(0xFF012169) : Colors.grey)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.white),
        ],
      ),
    );
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return 'Please enter $fieldName';
    if (double.tryParse(value.trim()) == null) return 'Please enter a valid number';
    return null;
  }

  Widget _numberField(TextEditingController controller, String label, String fieldName) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        // Normalize the locale's comma separator so calculations always receive a dot.
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) {
          if (!value.contains(',')) return;
          final normalized = value.replaceAll(',', '.');
          controller.value = controller.value.copyWith(
            text: normalized,
            selection: TextSelection.collapsed(offset: normalized.length),
            composing: TextRange.empty,
          );
        },
        validator: (v) => _validateNumber(v?.replaceAll(',', '.'), fieldName),
      ),
    );
  }

  Widget _nameField({
    required TextEditingController controller,
    required String label,
    required String emptyMessage,
    required String takenMessage,
    required bool Function(String) isTaken,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) return emptyMessage;
        if (isTaken(trimmed)) return takenMessage;
        return null;
      },
    );
  }

  List<Widget> _dialogActions(BuildContext dialogContext, VoidCallback onConfirm, String confirmLabel) {
    return [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
      TextButton(onPressed: onConfirm, child: Text(confirmLabel)),
    ];
  }

  void _showEditProfileDialog({VesselProfile? profileToEdit}) {
    final isEditing = profileToEdit != null;
    final savedProfiles = context.read<VesselSelectionProvider>().savedProfiles;

    if (isEditing) {
      _profileNameController.text = profileToEdit.name;
      _vesselLengthController.text = profileToEdit.length.toStringAsFixed(2);
      _vesselBeamController.text = profileToEdit.beam.toStringAsFixed(2);
      _vesselDepthController.text = profileToEdit.depth.toStringAsFixed(2);
      _isoController.text = profileToEdit.iso?.toString() ?? '';
      _selectedShipType = profileToEdit.shiptype;
    } else {
      _profileNameController.clear();
      _vesselLengthController.text = '0';
      _vesselBeamController.text = '0';
      _vesselDepthController.text = '0';
      _isoController.clear();
      _selectedShipType = null;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEditing ? "Edit Vessel Profile" : "Create New Profile"),
          content: Form(
            key: _profileFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _nameField(
                    controller: _profileNameController,
                    label: "Vessel Name",
                    emptyMessage: 'Please enter a vessel name',
                    takenMessage: 'Vessel name already exists',
                    isTaken: (name) => savedProfiles
                        .any((p) => p.name == name && (!isEditing || p.name != profileToEdit.name)),
                  ),
                  _numberField(_vesselLengthController, "Length (m)", "length"),
                  _numberField(_vesselBeamController, "Beam (m)", "beam"),
                  _numberField(_vesselDepthController, "Depth (m)", "depth"),
                  _numberField(_isoController, "IMO number", "IMO number"),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedShipType,
                      decoration: const InputDecoration(labelText: "Ship type", border: OutlineInputBorder()),
                      items: shipTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (value) => setDialogState(() => _selectedShipType = value),
                    ),
                  )
                ],
              ),
            ),
          ),
          actions: _dialogActions(
            dialogContext,
                () {
              if (_profileFormKey.currentState!.validate()) {
                _saveProfile(isEditing, profileToEdit);
                Navigator.pop(dialogContext);
              }
            },
            isEditing ? "Update" : "Create",
          ),
        ),
      ),
    );
  }

  void _saveProfile(bool isEditing, VesselProfile? profileToEdit) {
    final isoText = _isoController.text.trim();

    final newProfile = VesselProfile(
      name: _profileNameController.text.trim(),
      length: double.parse(_vesselLengthController.text.trim()),
      beam: double.parse(_vesselBeamController.text.trim()),
      depth: double.parse(_vesselDepthController.text.trim()),
      iso: isoText.isEmpty ? null : int.tryParse(isoText),
      shiptype: _selectedShipType,
      loadingConditions: (isEditing && profileToEdit!.loadingConditions.isNotEmpty)
          ? profileToEdit.loadingConditions
          : [LoadingCondition(name: "Default Voyage", gm: 0, vcg: 0, draft: 0)],
    );

    context
        .read<VesselSelectionProvider>()
        .addOrUpdateProfile(newProfile, oldProfile: isEditing ? profileToEdit : null);
  }

  void _showEditConditionDialog({LoadingCondition? conditionToEdit}) {
    final isEditing = conditionToEdit != null;
    final currentProfile = context.read<VesselSelectionProvider>().currentVesselProfile;
    if (currentProfile == null) return;

    if (isEditing) {
      _conditionNameController.text = conditionToEdit.name;
      _gmController.text = conditionToEdit.gm.toStringAsFixed(2);
      _vcgController.text = conditionToEdit.vcg.toStringAsFixed(2);
      _draftController.text = conditionToEdit.draft.toStringAsFixed(2);
    } else {
      _conditionNameController.clear();
      _gmController.text = '0';
      _vcgController.text = '0';
      _draftController.text = '0';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEditing ? "Edit Voyage" : "New Voyage"),
        content: Form(
          key: _conditionFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _nameField(
                  controller: _conditionNameController,
                  label: "Voyage Name",
                  emptyMessage: 'Please enter a Voyage name',
                  takenMessage: 'Voyage name already exists',
                  isTaken: (name) => currentProfile.loadingConditions
                      .any((c) => c.name == name && (!isEditing || c.name != conditionToEdit.name)),
                ),
                _numberField(_draftController, "Draft (m)", "draft"),
                _numberField(_vcgController, "VCG (m)", "VCG"),
                _numberField(_gmController, "GM (m)", "GM"),
              ],
            ),
          ),
        ),
        actions: _dialogActions(
          dialogContext,
              () {
            if (_conditionFormKey.currentState!.validate()) {
              _saveLoadingCondition(isEditing, conditionToEdit);
              Navigator.pop(dialogContext);
            }
          },
          isEditing ? "Update" : "Create",
        ),
      ),
    );
  }

  void _saveLoadingCondition(bool isEditing, LoadingCondition? conditionToEdit) {
    final newCondition = LoadingCondition(
      name: _conditionNameController.text.trim(),
      gm: double.parse(_gmController.text.trim()),
      vcg: double.parse(_vcgController.text.trim()),
      draft: double.parse(_draftController.text.trim()),
    );

    context
        .read<VesselSelectionProvider>()
        .addOrUpdateLoadingCondition(newCondition, oldCondition: isEditing ? conditionToEdit : null);
  }
}