import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
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

class PredictionPage extends StatefulWidget {
  final VesselProfile vesselProfile;
  final LoadingCondition loadingCondition;

  const PredictionPage({
    super.key,
    required this.vesselProfile,
    required this.loadingCondition,
  });

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  double rollCoefficient = 0.4;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;
  String _selectedVessel = 'All';
  bool _sortAscending = true;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  late TextStyle titleStyle;
  late TextStyle subtitleStyle;
  late TextStyle Axeslegend;
  late double iconsize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStyles();
  }

  @override
  void initState() {
    super.initState();
    _selectedEndDate = DateTime.now();
    _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
  }

  void _updateStyles() {
    print('Page Measure');
    final basscreenWidth = 411.42857142857144;
    final screenWidth = MediaQuery.of(context).size.width;
    print('screenWidth: ${screenWidth}');
    final screenHeight = MediaQuery.of(context).size.height;
    print('screenHeight: ${screenHeight}');
    final ratio = screenWidth/basscreenWidth;
    print('ratio: ${ratio}');
    iconsize = 40.0 * ratio;
    print('iconsize : ${iconsize}');
    setState(() {
      titleStyle = TextStyle(
        fontSize: 14.0 * ratio,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      );
      subtitleStyle = TextStyle(
        fontSize: 12.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      );
      print('subtitleStyle font size: ${subtitleStyle.fontSize}');
      Axeslegend = TextStyle(
        fontSize: 12.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );
    });
  }

  @override
  void didUpdateWidget(PredictionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vesselProfile != oldWidget.vesselProfile ||
        widget.loadingCondition != oldWidget.loadingCondition) {
      _updateVesselWidget();
    }
  }

  Future<void> _updateVesselWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vesselData = {
        'vesselProfile': {
          'name': widget.vesselProfile.name,
          'length': widget.vesselProfile.length,
          'beam': widget.vesselProfile.beam,
          'depth': widget.vesselProfile.depth,
        },
        'voyage': {
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
    return 2 * rollCoefficient * beam / sqrt(gm);
  }

  List<FlSpot> generateChartData() {
    List<FlSpot> data = [];
    const int steps = 50;
    const double minGM = 0.5;
    const double maxGM = 10.0;

    for (int i = 0; i <= steps; i++) {
      double gm = minGM + (i * (maxGM - minGM) / steps);
      double period = calculateRollPeriod(gm);
      data.add(FlSpot(gm, period));
    }

    return data;
  }

  List<FlSpot> _generateComparisonChartData(List<SavedMeasurement> measurements) {
    List<FlSpot> data = [];

    for (final measurement in measurements) {
      if (measurement.rollPeriodFFT != null) {
        final measured = measurement.rollPeriodFFT!;
        final estimated = calculateRollPeriod(measurement.loadingCondition.gm);
        data.add(FlSpot(measurement.loadingCondition.gm, measured));
      }
    }

    return data;
  }


  Widget _buildChart() {
    final spots = generateChartData();
    final currentPeriod = calculateRollPeriod(widget.loadingCondition.gm);
    final currentSpot = FlSpot(widget.loadingCondition.gm, currentPeriod);

    if (widget.loadingCondition.gm < 0.5) {
      return _buildWarningMessage();
    }

    return _buildChartContainer(spots, currentSpot);
  }

  Widget _buildWarningMessage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? Colors.grey[700] : Colors.white,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: iconsize,
            ),
            const SizedBox(height: 16),
            Text(
              "GM value below 0.5 is too low to calculate a prediction",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer(List<FlSpot> spots, FlSpot currentSpot) {
    final comparisonSpots = _generateComparisonChartData(Provider.of<SharedData>(context).savedMeasurements);

    return Container(
      height: MediaQuery.of(context).size.height * 0.3,
      padding: const EdgeInsets.only(left: 6, top: 16, right: 16, bottom: 8),
      decoration: _buildChartDecoration(),
      child: LineChart(
        LineChartData(
          gridData: _buildGridData(),
          titlesData: _buildTitlesData(),
          borderData: _buildBorderData(),
          lineBarsData: _buildLineBarsData(spots, currentSpot, comparisonSpots),
          minX: 0.5,
          maxX: 10,
          minY: 0,
          maxY: spots.isNotEmpty ? spots.map((e) => e.y).reduce(max) * 1.2 : 20,
          lineTouchData: _buildTouchData(),
          clipData: FlClipData.all(),
        ),
      ),
    );
  }

  BoxDecoration _buildChartDecoration() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDarkMode ? Colors.grey[700] : Colors.white,

    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      getDrawingHorizontalLine: (value) => FlLine(
        color: Colors.grey.withOpacity(0.2),
        strokeWidth: 1,
      ),
      getDrawingVerticalLine: (value) => FlLine(
        color: Colors.grey.withOpacity(0.2),
        strokeWidth: 1,
      ),
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: _buildBottomTitles(),
      leftTitles: _buildLeftTitles(),
    );
  }

  AxisTitles _buildBottomTitles() {
    return AxisTitles(
      axisNameWidget: Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Text(
          'GM (m)',
          style: Axeslegend,
        ),
      ),
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        interval: 1,
        getTitlesWidget: (value, meta) {
          if (value == value.roundToDouble()) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                value.toStringAsFixed(0),
                style: Axeslegend,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  AxisTitles _buildLeftTitles() {
    return AxisTitles(
      axisNameWidget: RotatedBox(
        quarterTurns: 0,
        child: Padding(
          padding: const EdgeInsets.only(left:25),
          child: Center(
            child: Text(
              'Roll Natural Period (s)',
              style: Axeslegend,
            ),
          ),
        ),
      ),
      axisNameSize: 28,
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: 5,
        getTitlesWidget: (value, meta) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              value.toStringAsFixed(0),
              style: Axeslegend,
            ),
          );
        },
      ),
    );
  }



  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(
        color: Colors.grey.withOpacity(0.2),
        width: 1,
      ),
    );
  }

  List<LineChartBarData> _buildLineBarsData(List<FlSpot> spots, FlSpot currentSpot, List<FlSpot> comparisonSpots) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: isDarkMode ? Colors.deepPurple : const Color(0xFF012169),
        barWidth: 4,
        shadow: BoxShadow(
          color: isDarkMode ? Colors.deepPurple.withOpacity(0.3) : const Color(0xFF012169).withOpacity(0.3),
          blurRadius: 8,
          spreadRadius: 2,
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDarkMode ? Colors.deepPurple.withOpacity(0.2) : const Color(0xFF012169).withOpacity(0.2),
              isDarkMode ? Colors.deepPurple.withOpacity(0.01) : Color(0xFF012169).withOpacity(0.01),
            ],
          ),
        ),
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: [currentSpot],
        isCurved: false,
        color: isDarkMode ? Colors.deepPurple : const Color(0xFF012169),
        barWidth: 0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 8,
              color: isDarkMode ? Colors.deepPurple : const Color(0xFF012169),
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          },
        ),
      ),
      LineChartBarData(
        spots: comparisonSpots,
        isCurved: false,
        color: Colors.teal,
        barWidth: 0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 5,
              color: Colors.teal,
              strokeWidth: 1,
              strokeColor: Colors.white,
            );
          },
        ),
      ),
    ];
  }

  LineTouchData _buildTouchData() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((touchedSpot) {
            return LineTooltipItem(
              'GM: ${touchedSpot.x.toStringAsFixed(1)}\nPeriod: ${touchedSpot.y.toStringAsFixed(1)}s',
              TextStyle(color: isDarkMode ? Colors.black : Colors.white),
            );
          }).toList();
        },
      ),
    );
  }

  Widget gmRollPeriodPairsTile({required List<SavedMeasurement> measurements}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<SavedMeasurement>>(
      future: _loadSavedMeasurements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(4.0),
                child: Text(
                  "No saved measurements yet",
                  style: Axeslegend,
                ),
              ),
            ],
          );
        }

        final measurements = snapshot.data!;
        final vesselNames = ['All', ...measurements.map((m) => m.vesselProfile.name).toSet().toList()];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedVessel,
                    decoration: InputDecoration(
                      labelText: 'Vessel',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black.withOpacity(0.6),width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedStartDate != null
                                      ? 'From: ${DateFormat('dd/MM/yyyy').format(_selectedStartDate!)}'
                                      : 'Select start date',
                                  style: subtitleStyle,
                                ),
                              ],
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
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black.withOpacity(0.6),width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedEndDate != null
                                      ? 'To: ${DateFormat('dd/MM/yyyy').format(_selectedEndDate!)}'
                                      : 'Select end date',
                                  style: subtitleStyle,
                                ),
                              ],
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
                          _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16, color: Color(0xFF012169)
                        ),
                        label: Text(
                          _sortAscending ? 'Oldest first' : 'Newest first',
                          style: TextStyle(color: Color(0xFF012169)),
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
                        child: Text(
                          'Clear filters',
                          style: TextStyle(color: Colors.red),
                        ),

                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Scrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: measurements.where((m) {
                  final matchesVessel = _selectedVessel == 'All' || m.vesselProfile.name == _selectedVessel;
                  final matchesDateRange =
                      (_selectedStartDate == null || m.timestamp.isAfter(_selectedStartDate!.subtract(const Duration(days: 1)))) &&
                          (_selectedEndDate == null || m.timestamp.isBefore(_selectedEndDate!.add(const Duration(days: 1))));
                  return matchesVessel && matchesDateRange;
                }).length,
                itemBuilder: (context, index) {
                  final filteredMeasurements = measurements.where((m) {
                    final matchesVessel = _selectedVessel == 'All' || m.vesselProfile.name == _selectedVessel;
                    final matchesDateRange =
                        (_selectedStartDate == null || m.timestamp.isAfter(_selectedStartDate!.subtract(const Duration(days: 1)))) &&
                            (_selectedEndDate == null || m.timestamp.isBefore(_selectedEndDate!.add(const Duration(days: 1))));
                                return matchesVessel && matchesDateRange;
                            }).toList()
                    ..sort((a, b) => _sortAscending
                        ? a.timestamp.compareTo(b.timestamp)
                        : b.timestamp.compareTo(a.timestamp));

                  final measurement = filteredMeasurements[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                    color: isDarkMode ? Colors.grey[700] : const Color(0xFFe5e8f0),
                    elevation: 1,
                    child: ListTile(
                      title: Text(
                        measurement.vesselProfile.name,
                        style: titleStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Color(0xFF012169),
                        ),
                      ),
                      subtitle: Text(
                        '${_formatDate(measurement.timestamp)} - ${measurement.timestamp.hour.toString().padLeft(2, '0')}:${measurement.timestamp.minute.toString().padLeft(2, '0')}',
                        style: subtitleStyle.copyWith(color: isDarkMode ? Colors.grey[500] : Colors.black),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color:Colors.red),
                        onPressed: () => _confirmDeleteMeasurement(context, measurement),
                      ),
                      onTap: () => _showMeasurementDetails(context, measurement),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _matchesDate(String query, DateTime date) {
    final formattedDate = _formatDate(date);
    return formattedDate.contains(query);
  }

  Future<void>_confirmDeleteMeasurement(BuildContext context, SavedMeasurement measurement) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this measurement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      await Provider.of<SharedData>(context, listen: false).deleteMeasurement(measurement);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Measurement deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showMeasurementDetails(BuildContext context, SavedMeasurement measurement) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection("Measurement Details", [
                  _buildDetailRow("Measurement time",
                      "${DateFormat('dd/MM/yyyy HH:mm').format(measurement.timestamp)}"),
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
                _buildDetailSection("Vessel details", [
                  _buildDetailRow("Vessel name", measurement.vesselProfile.name),
                  _buildDetailRow("Over all Length", "${measurement.vesselProfile.length.toStringAsFixed(2)} m"),
                  _buildDetailRow("Max beam", "${measurement.vesselProfile.beam.toStringAsFixed(2)} m"),
                  _buildDetailRow("To main deck depth", "${measurement.vesselProfile.depth.toStringAsFixed(2)} m"),
                ]),

                const SizedBox(height: 16),
                _buildDetailSection("Voyage details", [
                  _buildDetailRow("Voyage name", measurement.loadingCondition.name),
                  _buildDetailRow("GM without FSC", "${measurement.loadingCondition.gm.toStringAsFixed(2)} m"),
                  _buildDetailRow("VCG without FSC", "${measurement.loadingCondition.vcg.toStringAsFixed(2)} m"),
                  _buildDetailRow("Mean draft", "${measurement.loadingCondition.draft.toStringAsFixed(2)} m"),
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
                const SizedBox(height: 16),
                _buildDetailSection("Roll Natural Prediction", [
                  ...measurement.predictedRollPeriods.entries.map(
                        (entry) => _buildDetailRow(
                        "${entry.key}",
                        "${entry.value.toStringAsFixed(1)} s"),
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
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


  Future<List<SavedMeasurement>> _loadSavedMeasurements() async {
    final prefs = await SharedPreferences.getInstance();
    final measurementsJson = prefs.getStringList('savedMeasurements') ?? [];

    return measurementsJson.map((json) {
      try {
        return SavedMeasurement.fromMap(jsonDecode(json));
      } catch (e) {
        debugPrint('Error parsing measurement: $e');
        return null;
      }
    }).whereType<SavedMeasurement>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final sharedData = Provider.of<SharedData>(context);
    final currentPeriod = calculateRollPeriod(widget.loadingCondition.gm);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: isDarkMode ? Colors.grey[850] : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ROLL COEFFICIENT SETTINGS",
                        style: titleStyle.copyWith(
                          color: isDarkMode ? Colors.grey[300] : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Roll Coefficient (k)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xe5e8f0),
                        ),
                        initialValue: rollCoefficient.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final newValue = double.tryParse(value);
                          if (newValue != null && newValue > 0) {
                            setState(() {
                              rollCoefficient = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Formula: T = 2 × k × Beam / √GM",
                        style: subtitleStyle.copyWith(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                color: isDarkMode ? Colors.grey[850] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide.none),
                  title: Text(
                    "ROLL NATURAL PERIOD RESULTS",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0,horizontal: 16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[700]
                                  : const Color(0xFF012169).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Estimated roll natural period:",
                                  style: titleStyle.copyWith(
                                    color: isDarkMode ? Colors.grey[300] : Colors.black,
                                    fontSize: (titleStyle.fontSize ?? 14.0) * 1.1,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  "${currentPeriod.toStringAsFixed(1)} s",
                                  style: titleStyle.copyWith(
                                    color: isDarkMode ? Colors.white : const Color(0xFF012169),
                                    fontSize: (titleStyle.fontSize ?? 14.0) * 1.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildChart(),
                          const SizedBox(height: 16),
                          Text(
                            "The blue dot indicates the current GM value and its corresponding roll natural period. "
                                "Teal dots represent actual measurements from saved data.",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
              elevation: 1,
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide.none),
                title: Text(
                  "SAVED MEASUREMENTS",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: gmRollPeriodPairsTile(measurements: sharedData.savedMeasurements),
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
