import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'widgets/custom_app_bar.dart';
import 'models/vessel_profile.dart';
import 'models/loading_condition.dart';
import 'models/navigation_info.dart';

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
  String selectedMethod = 'Roll Coefficient';

  final Map<String, double> methodParameters = {
    'Roll Coefficient': 0.4,
    'Doyere': 0.34,
    'JSRA': 0.35,
    'Beam': 0.36,
  };

  final List<String> methods = [
    'Roll Coefficient',
    'Doyere',
    'JSRA',
    'Beam',
    'ITTC',
    'Grin',
  ];

  double calculateRollPeriod(double gm, String method) {
    if (gm <= 0) return 0;

    final vcg = widget.loadingCondition.vcg;
    final beam = widget.vesselProfile.beam;
    final depth = widget.vesselProfile.depth;

    switch (method) {
      case 'Roll Coefficient':
        final k = methodParameters['Roll Coefficient'] ?? 0.4;
        return 2 * k * beam / sqrt(gm);
      case 'Doyere':
        final c = methodParameters['Doyere'] ?? 0.29;
        return 2 * c * sqrt((pow(beam, 2) + 4 * pow(vcg, 2)) / gm);
      case 'JSRA':
        final k = 0.3437 + 0.024 * (beam / depth);
        return 2 * k * beam / sqrt(gm);
      case 'Beam':
        final k = methodParameters['Beam'] ?? 0.36;
        return 2 * k * sqrt((pow(beam, 2) + pow(depth, 2)) / gm);
      case 'ITTC':
        final kxx = sqrt((0.4 * pow(beam + depth, 2) + 0.6 * (pow(beam, 2) + pow(depth, 2) - pow(2 * depth / 2 - vcg, 2)) / 12));
        final axx = 0.05 * pow(beam, 2) / depth;
        return 2 * sqrt((pow(kxx, 2) + pow(axx, 2)) / sqrt(gm));
      case 'Grin':
        final beta = 11.0;
        final kxx = sqrt((pow(beam, 2) + pow(depth, 2)) / beta + pow(depth / 2 - vcg, 2));
        return 2 * kxx / sqrt(gm);
      default:
        return 0;
    }
  }

  List<FlSpot> generateChartData() {
    List<FlSpot> data = [];
    const int steps = 50;
    const double maxGM = 10.0;

    for (int i = 1; i <= steps; i++) {
      double gm = i * maxGM / steps;
      double period = calculateRollPeriod(gm, selectedMethod);
      data.add(FlSpot(gm, period));
    }

    return data;
  }

  Widget _buildChart() {
    final spots = generateChartData();
    final currentPeriod = calculateRollPeriod(widget.loadingCondition.gm, selectedMethod);
    final currentSpot = FlSpot(widget.loadingCondition.gm, currentPeriod);

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
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
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Color(0xFF012169),
              barWidth: 4,
              shadow: BoxShadow(
                color: Color(0xFF012169).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF012169).withOpacity(0.2),
                    Color(0xFF012169).withOpacity(0.01),
                  ],
                ),
              ),
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: [currentSpot],
              isCurved: false,
              color: Color(0xFF012169),
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 8,
                    color: Color(0xFF012169),
                    strokeWidth: 3,
                    strokeColor: Colors.white,
                  );
                },
              ),
            ),
          ],
          minX: 0,
          maxX: 10,
          minY: 0,
          maxY: spots.isNotEmpty ? spots.map((e) => e.y).reduce(max) * 1.2 : 20,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  return LineTooltipItem(
                    'GM: ${touchedSpot.x.toStringAsFixed(2)}\nPeriod: ${touchedSpot.y.toStringAsFixed(2)}s',
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPeriod = calculateRollPeriod(widget.loadingCondition.gm, selectedMethod);
    debugPrint("GM : ${widget.loadingCondition.gm}");
    return Scaffold(
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "METHOD SELECTION",
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedMethod,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.5),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.05),
                        ),
                        items: methods.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedMethod = newValue!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ROLL PERIOD RESULTS",
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFF012169).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Estimated roll period:",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              "${currentPeriod.toStringAsFixed(2)} s",
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF012169),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Current GM: ${widget.loadingCondition.gm.toStringAsFixed(2)} m",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildChart(),
                      const SizedBox(height: 16),
                      Text(
                        "The dot indicates the current GM value and its corresponding roll period.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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