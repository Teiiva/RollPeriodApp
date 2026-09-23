import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'widgets/custom_app_bar.dart';
import 'models/vessel_profile.dart';
import 'models/loading_condition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/saved_measurement.dart';
import 'package:provider/provider.dart';
import 'shared_data.dart';

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
  bool _isLoaded = false; // Added to handle initial load

  late TextStyle titleStyle;
  late TextStyle subtitleStyle;
  late TextStyle axesLegend;
  late double iconSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStyles();
  }

  @override
  void initState() {
    super.initState();
    _loadRollCoefficient();
  }

  Future<void> _loadRollCoefficient() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      rollCoefficient = prefs.getDouble('rollCoefficient') ?? 0.4;
      _isLoaded = true; // Mark as loaded
    });
  }

  Future<void> _saveRollCoefficient(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('rollCoefficient', value);
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
        color: Colors.black,
      );
      axesLegend = TextStyle(
        fontSize: 12.0 * ratio,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );
    });
  }

  double calculateRollPeriod(double gm) {
    if (gm < 0.5) return 0.0;
    final beam = context.watch<VesselSelectionProvider>().currentVesselProfile!.beam;
    final result = 2 * rollCoefficient * beam / sqrt(gm);
    return result;
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

  List<FlSpot> _generateComparisonChartData(
      List<SavedMeasurement> measurements) {
    List<FlSpot> data = [];

    for (final measurement in measurements) {
      if (measurement.rollPeriodFFT != null) {
        data.add(FlSpot(
            measurement.loadingCondition.gm, measurement.rollPeriodFFT!));
      }
    }

    return data;
  }


  Widget _buildChart() {
    final currentLoadingCondition = context.watch<VesselSelectionProvider>().currentLoadingCondition!;
    final spots = generateChartData();
    final currentPeriod = calculateRollPeriod(currentLoadingCondition.gm);
    final currentSpot = FlSpot(currentLoadingCondition.gm, currentPeriod);

    if (currentLoadingCondition.gm < 0.5) {
      return _buildWarningMessage();
    }

    return _buildChartContainer(spots, currentSpot);
  }

  Widget _buildWarningMessage() {
    final isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    return Container(
      height: MediaQuery
          .of(context)
          .size
          .height * 0.4,
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
              size: iconSize,
            ),
            const SizedBox(height: 16),
            Text(
              "GM value below 0.5 is too low to calculate a prediction",
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
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
    final comparisonSpots = _generateComparisonChartData(
        Provider.of<SharedData>(context).savedMeasurements);

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
          maxX: spots.isNotEmpty ? spots.map((e) => e.x).reduce(max) * 1 : 10,
          minY: 0,
          maxY: spots.isNotEmpty ? spots.map((e) => e.y).reduce(max) * 2.2 : 20,
          lineTouchData: _buildTouchData(),
          clipData: const FlClipData.all(),
        ),
      ),
    );
  }

  BoxDecoration _buildChartDecoration() {
    final isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDarkMode ? Colors.grey[700] : Colors.white,

    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      getDrawingHorizontalLine: (value) =>
          FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
      getDrawingVerticalLine: (value) =>
          FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
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
          style: axesLegend,
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
                style: axesLegend,
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
          padding: const EdgeInsets.only(left: 25),
          child: Center(
            child: Text(
              'Roll Natural Period (s)',
              style: axesLegend,
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
              style: axesLegend,
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
        color: Colors.grey.withValues(alpha: 0.2),
        width: 1,
      ),
    );
  }

  List<LineChartBarData> _buildLineBarsData(
      List<FlSpot> spots, FlSpot currentSpot, List<FlSpot> comparisonSpots) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: isDarkMode ? Colors.deepPurple : const Color(0xFF012169),
        barWidth: 4,
        shadow: BoxShadow(
          color: isDarkMode
              ? Colors.deepPurple.withValues(alpha: 0.3)
              : const Color(0xFF012169).withValues(alpha: 0.3),
          blurRadius: 8,
          spreadRadius: 2,
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDarkMode ? Colors.deepPurple.withValues(alpha: 0.2) : const Color(0xFF012169).withValues(alpha: 0.2),
              isDarkMode ? Colors.deepPurple.withValues(alpha: 0.01) : const Color(0xFF012169).withValues(alpha: 0.01),
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
    final isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((touchedSpot) {
            return LineTooltipItem(
              'GM: ${touchedSpot.x.toStringAsFixed(1)}\n'
                  'Period: ${touchedSpot.y.toStringAsFixed(1)}s',
              TextStyle(color: isDarkMode ? Colors.black : Colors.white),
            );
          }).toList();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPeriod = calculateRollPeriod(context.watch<VesselSelectionProvider>().currentLoadingCondition!.gm);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Return empty or loading indicator until loaded to avoid jumpy UI or wrong initial value
    if (!_isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: CustomAppBar(),
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
                        key: ValueKey(rollCoefficient), // Rebuild when value changes
                        decoration: InputDecoration(
                          labelText: 'Roll Coefficient (k)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0x00e5e8f0),
                        ),
                        initialValue: rollCoefficient.toStringAsFixed(2),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          final newValue = double.tryParse(value);
                          if (newValue != null && newValue > 0) {
                            setState(() {
                              rollCoefficient = newValue;
                              _saveRollCoefficient(newValue);
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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ROLL NATURAL PERIOD RESULTS",
                        style: titleStyle.copyWith(
                          color: isDarkMode ? Colors.grey[300] : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey[700]
                              : const Color(0xFF012169).withValues(alpha: 0.1),
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
                        "The blue dot indicates the current GM value and its corresponding roll natural period."
                            "The cyan dots represent actual measurements from saved data.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                ),

              const SizedBox(height: 8),

            ],
          ),
        ),
      ),
    );
  }
}
