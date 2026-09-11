import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'dart:math';
import 'fft_processor.dart';
import 'widgets/custom_app_bar.dart';
import 'models/vessel_profile.dart';
import 'models/loading_condition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/saved_measurement.dart';
import 'package:provider/provider.dart';
import 'shared_data.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class Dataspage extends StatefulWidget {
  final VesselProfile vesselProfile;
  final LoadingCondition loadingCondition;

  const Dataspage({
    super.key,
    required this.vesselProfile,
    required this.loadingCondition,
  });

  @override
  State<Dataspage> createState() => _DataspageState();
}

class _DataspageState extends State<Dataspage> {
  double rollCoefficient = 0.4;
  bool _isLoaded = false; // Added to handle initial load

  String _selectedVessel = 'All';
  bool _sortAscending = false;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  late TextStyle titleStyle;
  late TextStyle subtitleStyle;
  late TextStyle axesLegend;
  late TextStyle chartlabel;
  late double iconSize;

  final Set<SavedMeasurement> _selectedMeasurements = {};
  bool _isSelectionMode = false;

  final ScrollController _scrollController = ScrollController();
  late TutorialCoachMark tutorialCoachMark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStyles();
  }

  @override
  void initState() {
    super.initState();
    _loadRollCoefficient();
    _selectedEndDate = DateTime.now();
    _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
  }

  Future<void> _loadRollCoefficient() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      rollCoefficient = prefs.getDouble('rollCoefficient') ?? 0.4;
      _isLoaded = true; // Mark as loaded
    });
  }

  void _updateStyles() {
    const basscreenWidth = 411.42857142857144;
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final ratio = screenWidth / basscreenWidth;
    iconSize = 40.0 * ratio;

    setState(() {
      titleStyle = TextStyle(
        fontSize: 14.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      );
      subtitleStyle = TextStyle(
        fontSize: 12.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      );
      axesLegend = TextStyle(
        fontSize: 12.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );
      chartlabel = TextStyle(
        fontSize: 10.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );
    });
  }

  @override
  void didUpdateWidget(Dataspage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vesselProfile != oldWidget.vesselProfile ||
        widget.loadingCondition != oldWidget.loadingCondition) {
      _updateVesselWidget();
    }
  }

  Future<void> _updateVesselWidget() async {
    try {
      _selectedVessel = widget.vesselProfile.name;
      final prefs = await SharedPreferences.getInstance();
      final vesselData = {
        'vesselProfile': {
          'name': widget.vesselProfile.name,
          'length': widget.vesselProfile.length,
          'beam': widget.vesselProfile.beam,
          'depth': widget.vesselProfile.depth,
        },
        'Voyage': {
          'name': widget.loadingCondition.name,
          'gm': widget.loadingCondition.gm,
          'vcg': widget.loadingCondition.vcg,
        }
      };
      await prefs.setString('vesselData', jsonEncode(vesselData));
      const channel = MethodChannel('com.rollperiod.rollperiod/vessel_widget');
      await channel.invokeMethod('updateVesselWidget');
    } catch (e) {
      debugPrint('Error updating vessel widget: $e');
    }
  }

  double calculateRollPeriod(double gm) {
    if (gm < 0.5) return 0;
    final beam = widget.vesselProfile.beam;
    final result = 2 * rollCoefficient * beam / sqrt(gm);
    return result;
  }

  Future<void> _shareData(SavedMeasurement measurement) async {
    try {
      final buffer = StringBuffer();
      final now = DateTime.now();

      final vessel = measurement.vesselProfile;
      final loading = measurement.loadingCondition;

      /*ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${measurement.predictedRollPeriods}')),
      );*/

      final metadata = [
        'Export Time: ${now.toIso8601String()}',
        'Date: ${measurement.timestamp.toIso8601String()}',
        'Duration (s): ${measurement.duration?.toStringAsFixed(2) ?? 'N/A'}',
        'Roll Period (FFT)(s): ${measurement.rollPeriodFFT?.toStringAsFixed(
            2) ?? 'N/A'}',
        'Pitch Period (FFT)(s): ${measurement.pitchPeriodFFT?.toStringAsFixed(
            2) ?? 'N/A'}',
        'Max Roll (deg): ${measurement.maxRoll?.toStringAsFixed(2) ?? 'N/A'}',
        'Max Pitch (deg): ${measurement.maxPitch?.toStringAsFixed(2) ?? 'N/A'}',
        'RMS Roll (deg): ${measurement.rmsRoll?.toStringAsFixed(2) ?? 'N/A'}',
        'RMS Pitch (deg): ${measurement.rmsPitch?.toStringAsFixed(2) ?? 'N/A'}',
        'Vessel Profile: ${vessel.name}',
        'Length (m): ${vessel.length}',
        'Beam (m): ${vessel.beam}',
        'Depth (m): ${vessel.depth}',
        'Voyage Condition: ${loading.name}',
        'GM (m): ${loading.gm}',
        'VCG (m): ${loading.vcg}',
        'Draft (m): ${loading.draft}',
      ];

      buffer.writeln('parameter,value');
      for (final line in metadata) {
        final separatorIndex = line.indexOf(':');
        if (separatorIndex != -1) {
          final key = line.substring(0, separatorIndex).trim();
          final value = line.substring(separatorIndex + 1).trim();
          buffer.writeln('$key,$value');
        } else {
          buffer.writeln(line);
        }
      }

      buffer.writeln();
      buffer.writeln('prediction_method,predicted_period_s');
      for (final entry in measurement.predictedRollPeriods.entries) {
        buffer.writeln('${entry.key},${entry.value.toStringAsFixed(2)}');
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${measurement.vesselProfile.name}_'
          '${DateFormat("yyMMddHHmm").format(measurement.timestamp)}.csv');

      await file.writeAsString(buffer.toString());

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Exported Measurement Data',
          subject: 'Measurement Export - ${vessel.name} / ${loading.name}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog(SavedMeasurement measurement) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text(
              'Are you sure you want to delete this measurement? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteMeasurement(measurement);
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteMeasurement(SavedMeasurement measurement) async {
    try {
      final sharedData = Provider.of<SharedData>(context, listen: false);
      await sharedData.deleteMeasurement(measurement);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Measurement deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete measurement: $e')),
        );
      }
    }
  }

  Widget gmRollPeriodPairsTile({required List<SavedMeasurement> measurements}) {
    final isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;

    if (measurements.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              "No saved measurements yet",
              style: axesLegend,
            ),
          ),
        ],
      );
    }

    final vesselNames = [
      'All',
      ...measurements.map((m) => m.vesselProfile.name).toSet()
    ];
    final loadingCondition = [
      'All',
      ...measurements.map((m) => m.loadingCondition.name).toSet()
    ];

    if (!vesselNames.contains(_selectedVessel)) {
      _selectedVessel = 'All';
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('vessel_$_selectedVessel'),
                  initialValue: _selectedVessel,
                  decoration: InputDecoration(
                    labelText: 'Vessel',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  items: vesselNames.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedVessel = value!;
                    });
                  },
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedStartDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: _selectedEndDate ?? DateTime.now(),
                          );
                          if (selectedDate != null) {
                            setState(() {
                              _selectedStartDate = selectedDate;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedStartDate != null
                                ? 'From: ${DateFormat('dd/MM/yyyy').format(
                                _selectedStartDate!)}'
                                : 'Select start date',
                            style: subtitleStyle.copyWith(
                                color: isDarkMode ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedEndDate ?? DateTime.now(),
                            firstDate: _selectedStartDate ?? DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (selectedDate != null) {
                            setState(() {
                              _selectedEndDate = selectedDate;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedEndDate != null
                                ? 'To: ${DateFormat('dd/MM/yyyy').format(
                                _selectedEndDate!)}'
                                : 'Select end date',
                            style: subtitleStyle.copyWith(
                                color: isDarkMode ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                          _sortAscending ? Icons.arrow_upward : Icons
                              .arrow_downward,
                          size: 16,
                          color: isDarkMode ?
                                  const Color(0xFF008EF3) :
                                  const Color(0xFF012169),
                      ),
                      label: Text(
                        _sortAscending ? 'Oldest first' : 'Newest first',
                        style : TextStyle(color : isDarkMode ?
                                                    Color(0xFF008EF3) :
                                                    Color(0xFF012169))
                      ),
                      onPressed: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                        });
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedStartDate = null;
                          _selectedEndDate = null;
                          _selectedVessel = 'All';
                        });
                      },
                      child: const Text(
                        'Clear filters',
                        style: TextStyle(color: Colors.red),
                      ),

                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_isSelectionMode)
            Card(
              margin: const EdgeInsets.symmetric(
                  vertical: 4.0, horizontal: 0),
              color: isDarkMode ? Colors.grey[800] : const Color(0xFFe5e8f0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: Text(
                      '${_selectedMeasurements.length} selected',
                      style: titleStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(
                            0xFF012169),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                            Icons.ios_share, color: Color(0xFF012169)),
                        onPressed: _selectedMeasurements.isEmpty
                            ? null
                            : () => _shareSelectedMeasurements(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _selectedMeasurements.isEmpty
                            ? null
                            : () => _showBulkDeleteConfirmationDialog(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _exitSelectionMode,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),

          Scrollbar(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: measurements.where((m) {
                final matchesVessel = _selectedVessel == 'All' ||
                    m.vesselProfile.name == _selectedVessel;
                final matchesDateRange =
                    (_selectedStartDate == null || m.timestamp.isAfter(
                        _selectedStartDate!.subtract(
                            const Duration(days: 1)))) &&
                        (_selectedEndDate == null || m.timestamp.isBefore(
                            _selectedEndDate!.add(const Duration(days: 1))));
                return matchesVessel && matchesDateRange;
              }).length,
              itemBuilder: (context, index) {
                final filteredMeasurements = measurements.where((m) {
                  final matchesVessel = _selectedVessel == 'All' ||
                      m.vesselProfile.name == _selectedVessel;
                  final matchesDateRange =
                      (_selectedStartDate == null || m.timestamp.isAfter(
                          _selectedStartDate!.subtract(const Duration(
                              days: 1)))) &&
                          (_selectedEndDate == null || m.timestamp.isBefore(
                              _selectedEndDate!.add(const Duration(days: 1))));
                  return matchesVessel && matchesDateRange;
                }).toList()
                  ..sort((a, b) =>
                  _sortAscending
                      ? a.timestamp.compareTo(b.timestamp)
                      : b.timestamp.compareTo(a.timestamp));

                final measurement = filteredMeasurements[index];
                final isSelected = _selectedMeasurements.contains(measurement);

                final cardKey         = ValueKey('card_${measurement.timestamp}_$index');
                final shareButtonKey = ValueKey('share_${measurement.timestamp}_$index');
                final deleteButtonKey = ValueKey('delete_${measurement.timestamp}_$index');

                return Card(
                  key: cardKey, //There is a problem because a single key is associated to multiple elements
                  margin: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 0),
                  color: isSelected
                      ? (isDarkMode ? Colors.deepPurple[900] : const Color(
                      0xFFc5cce0))
                      : (isDarkMode ? Colors.grey[700] : const Color(
                      0xFFe5e8f0)),
                  elevation: 1,
                  child: ListTile(
                    leading: _isSelectionMode
                        ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(measurement),
                    )
                        : null,
                    title: Text(
                      "${measurement.vesselProfile.name} - ${measurement
                          .loadingCondition.name}",
                      style: titleStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(
                            0xFF012169),
                      ),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy').format(
                          measurement.timestamp)} - ${measurement.timestamp.hour
                          .toString().padLeft(2, '0')}:${measurement.timestamp
                          .minute.toString().padLeft(2, '0')}',
                      style: subtitleStyle.copyWith(
                          color: isDarkMode ? Colors.grey[500] : Colors.black),
                    ),
                    trailing: _isSelectionMode
                        ? null
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key : shareButtonKey,
                          icon: const Icon(Icons.ios_share, color: Color(
                              0xFF012169)),
                          onPressed: () => _shareData(measurement),
                        ),
                        IconButton(
                          key : deleteButtonKey,
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _showDeleteConfirmationDialog(measurement),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(measurement);
                      } else {
                        _showMeasurementDetails(context, measurement);
                      }
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedMeasurements.add(measurement);
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ]
    );
  }

  void _toggleSelection(SavedMeasurement measurement) {
    setState(() {
      if (_selectedMeasurements.contains(measurement)) {
        _selectedMeasurements.remove(measurement);
        if (_selectedMeasurements.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMeasurements.add(measurement);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMeasurements.clear();
    });
  }

  void _showBulkDeleteConfirmationDialog() {
    final count = _selectedMeasurements.length;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete $count measurements? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSelectedMeasurements();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelectedMeasurements() async {
    try {
      final sharedData = Provider.of<SharedData>(context, listen: false);
      final toDelete = List<SavedMeasurement>.from(_selectedMeasurements);

      for (final measurement in toDelete) {
        await sharedData.deleteMeasurement(measurement);
      }

      if (mounted) {
        setState(() {
          _selectedMeasurements.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${toDelete.length} measurements deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete measurements: $e')),
        );
      }
    }
  }

  Future<void> _shareSelectedMeasurements() async {
    try {
      final selected = List<SavedMeasurement>.from(_selectedMeasurements);
      for (final measurement in selected) {
        await _shareData(measurement);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share measurements: $e')),
        );
      }
    }
  }

  void _showMeasurementDetails(BuildContext context, SavedMeasurement measurement) {
    final List<FlSpot>? dataroll = measurement.dataroll;
    final List<FlSpot>? datapitch = measurement.datapitch;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildDetailSection("Vessel details", [
                  _buildDetailRow("Vessel name", measurement.vesselProfile.name),
                  _buildDetailRow("Length (m)", "${measurement.vesselProfile.length.toStringAsFixed(2)} m"),
                  _buildDetailRow("Beam (m)", "${measurement.vesselProfile.beam.toStringAsFixed(2)} m"),
                  _buildDetailRow("Depth (m)", "${measurement.vesselProfile.depth.toStringAsFixed(2)} m"),
                  _buildDetailRow("IMO number", "${measurement.vesselProfile.iso}"),
                  _buildDetailRow("Boat type", "${measurement.vesselProfile.shiptype}"),

                ]),

                const SizedBox(height: 16),
                _buildDetailSection("Voyage details", [
                  _buildDetailRow("Voyage name", measurement.loadingCondition.name),
                  _buildDetailRow("Mean draft", "${measurement.loadingCondition.draft.toStringAsFixed(2)} m"),
                  _buildDetailRow("VCG (m)", "${measurement.loadingCondition.vcg.toStringAsFixed(2)} m"),
                  _buildDetailRow("GM (m)", "${measurement.loadingCondition.gm.toStringAsFixed(2)} m"),
                  // VCG and GM can be show with "without FSC"
                ]),

                const SizedBox(height: 16),
                _buildDetailSection("Measurement Details", [
                  _buildDetailRow("Date",
                      DateFormat('dd/MM/yyyy HH:mm').format(measurement.timestamp)),
                  _buildDetailRow(
                    "Duration",
                    measurement.duration != null
                        ? "${(measurement.duration! ~/ 60)} min ${(measurement.duration! % 60).toStringAsFixed(0).padLeft(2, '0')} s"
                        : "N/A",
                  ),

                  _buildDetailRow("Max roll",
                      "${measurement.maxRoll?.toStringAsFixed(1) ?? 'N/A'}°"),
                  _buildDetailRow("Max pitch",
                      "${measurement.maxPitch?.toStringAsFixed(1) ?? 'N/A'}°"),
                  _buildDetailRow("RMS roll",
                      "${measurement.rmsRoll?.toStringAsFixed(2) ?? 'N/A'}°"),
                  _buildDetailRow("RMS pitch",
                      "${measurement.rmsPitch?.toStringAsFixed(2) ?? 'N/A'}°"),
                ]),

                const SizedBox(height: 16),
                _buildDetailSection("Period measured", [
                  _buildDetailRow(
                      "Roll Period",
                      measurement.rollPeriodFFT != null
                          ? "${measurement.rollPeriodFFT!.toStringAsFixed(1)} s"
                          : "N/A"),
                  _buildDetailRow(
                      "Pitch Period",
                      measurement.pitchPeriodFFT != null
                          ? "${measurement.pitchPeriodFFT!.toStringAsFixed(1)} s"
                          : "N/A"),
                ]),

              ],
            ),
          ),
          actions: [
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Spectrum'),

                        content: SizedBox(
                          width: double.maxFinite,
                          height: MediaQuery.of(context).size.height ,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Roll spectrum"),
                                if (dataroll != null)
                                  buildFFTChart(dataroll, Colors.deepPurple, label: 'Roll')
                                else
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      "No roll data available",
                                      style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                const Text("Pitch spectrum"),
                                if (datapitch != null)
                                  buildFFTChart(datapitch, Colors.teal, label: 'Roll')
                                else
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      "No roll data available",
                                      style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text("Spectrum"),
                ),
                const SizedBox(width: 75),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close"),
                ),
              ],
            )
          ],
        );
      },
    );
  }
  Widget buildFFTChart(List<FlSpot> data, Color color, {String label = ''}) {
    //Graph for spectrum in rad/s
    data = FFTProcessor.computePowerSpectrum(data.map((spot) => spot.y).toList())
        .asMap().entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
    // Convert in Hz
    data = data.map((spot) => FlSpot(spot.x / (2 * pi), spot.y)).toList();
    // Convert in second
    //data = data.map((spot) => spot.x > 0 ? FlSpot(1 / spot.x, spot.y) : spot).toList();
    //data = data.where((spot) => spot.x > 0).map((spot) => FlSpot(1 / spot.x, spot.y)).toList();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final gridColor = isDarkMode ? Colors.grey[700]!.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1);
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.withValues(alpha: 0.2);
    final textColor = isDarkMode ? Colors.grey[300]! : Colors.grey;
    //final maxX = data.isNotEmpty ? data.map((e) => e.x).reduce(max) : 1.0;
    final maxX = 7.0;
    final minX = maxX * 0.0;
    final displayedData = data.where((spot) => spot.x >= minX).toList();
    final maxY = displayedData.isNotEmpty ? displayedData.map((e) => e.y).reduce(max) * 1.2 : 1.0;
    final peakSpot = displayedData.isNotEmpty
        ? displayedData.reduce((a, b) => a.y > b.y ? a : b)
        : null;
    //final peakSpot = FFTProcessor.findDominantFrequencySpot(data.map((spot) => spot.y).toList(), 5);

    return Card(
      color: backgroundColor,
      margin: EdgeInsets.all(0),
      child: SizedBox(
        width: double.infinity,
        height: 230,
        child: Padding(
          padding: EdgeInsets.only(
            left: 10,
            top: 10,
            right: 10,
            bottom: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Expanded(
                child: data.isEmpty
                    ? Center(
                  child: Text(
                    'No data',
                    style: chartlabel.copyWith(color: textColor),
                  ),
                )
                    : LineChart(
                  LineChartData(
                    minX: minX,
                    maxX: maxX,
                    minY: 0,
                    maxY: maxY,
                    clipData: const FlClipData.all(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data,
                        color: color,
                        barWidth: 2,
                        isCurved: false,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withValues(alpha: 0.2),
                              color.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      LineChartBarData(
                        spots: [peakSpot!],
                        isCurved: false,
                        color: color,
                        barWidth: 0,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: color,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        axisNameWidget: Text(
                          'Deg/s',
                          style: chartlabel.copyWith(color: textColor, fontWeight: FontWeight.bold),
                        ),
                        axisNameSize: 20,
                        /*sideTitles: SideTitles(
                          showTitles: true,
                          interval: maxY > 0 ? maxY / 3 : 1,
                          reservedSize: 1,
                          getTitlesWidget: (value, meta) => Transform.rotate(
                            angle: 0, //-pi / 2,
                            child : Text(
                              value.toStringAsFixed(0),
                              style: chartlabel.copyWith(color: textColor),
                              )
                          ),
                        ),*/
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: Text(
                          'Hz',
                          style: chartlabel.copyWith(color: textColor, fontWeight: FontWeight.bold),
                        ),
                        axisNameSize: 20,
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: maxX > 0 ? maxX / 5 : 1,
                          reservedSize: 10,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(2),
                            textAlign: TextAlign.center,
                            style: chartlabel.copyWith(color: textColor),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: maxY > 0 ? maxY / 3 : 1,
                      verticalInterval: maxX > 0 ? maxX / 5 : 1,
                      getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 1),
                      getDrawingVerticalLine: (value) => FlLine(color: gridColor, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.x.toStringAsFixed(2)} Hz\n${(1.0/spot.x).toStringAsFixed(2)} s',
                              TextStyle(color: isDarkMode ? Colors.black : Colors.white),
                            );
                          }).toList();
                        },
                      ),
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

  Widget _buildDetailSection(String title, List<Widget> children) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            title,
            style: titleStyle.copyWith(color: isDarkMode ? Colors.deepPurple : const Color(0xFF012169))
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: subtitleStyle.copyWith(color: isDarkMode ? Colors.grey[500] : Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: subtitleStyle.copyWith(color:  isDarkMode ? Colors.grey[300] : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final sharedData = Provider.of<SharedData>(context);
    final currentPeriod = calculateRollPeriod(widget.loadingCondition.gm);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Return empty or loading indicator until loaded to avoid jumpy UI or wrong initial value
    if (!_isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: CustomAppBar(
        /*actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.greenAccent),
            onPressed: () {
              setState(() {
                _createTutorial();
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                ).then((_) {
                  if (mounted) {
                    tutorialCoachMark.show(context: context);
                  }
                });
              });
            },
          ),
        ],*/
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                color: isDarkMode ? Colors.grey[850] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: gmRollPeriodPairsTile(measurements: sharedData.savedMeasurements),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTargetScroll(String targetIdentify) {
    switch (targetIdentify) {
      case "start_button":
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
      case "import_button":
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
      case "clear_button":
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
    }
  }
}
