import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'widgets/custom_app_bar.dart';
import 'models/vessel_profile.dart';
import 'models/loading_condition.dart';
import 'models/navigation_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
  String selectedMethod = 'Roll Coefficient';
  final PageController _pageController = PageController(); // Ajoutez ceci
  int _currentPage = 0; // Pour suivre la page actuelle

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
    if (gm < 0.5) return 0;

    final vcg = widget.loadingCondition.vcg;
    final beam = widget.vesselProfile.beam;
    final depth = widget.vesselProfile.depth;

    switch (method) {
      case 'Roll Coefficient':
        final k = methodParameters['Roll Coefficient'] ?? 0.4;
        return 2 * k * beam / sqrt(gm);
      case 'Doyere':
        final c = methodParameters['Doyere'] ?? 0.34;
        debugPrint("beam : ${beam}");
        debugPrint("beam² : ${pow(beam, 2)}");
        debugPrint("vcg : ${vcg}");
        debugPrint("vcg² : ${pow(vcg, 2)}");
        debugPrint("gm : ${gm}");
        debugPrint("c : ${c}");
        return 2*c*sqrt(((pow(beam, 2))+4*(pow(vcg, 2)))/gm);
        //return 2*c*sqrt(((pow(beam, 2))+4*(pow(vcg, 2)))/gm);
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
    const double minGM = 0.5; // Nouvelle valeur minimale
    const double maxGM = 10.0;

    for (int i = 0; i <= steps; i++) {
      double gm = minGM + (i * (maxGM - minGM) / steps); // Commence à minGM
      double period = calculateRollPeriod(gm, selectedMethod);
      data.add(FlSpot(gm, period));
    }

    return data;
  }

  List<FlSpot> _generateComparisonChartData(List<SavedMeasurement> measurements) {
    List<FlSpot> data = [];

    for (final measurement in measurements) {
      if (measurement.rollPeriodFFT != null &&
          measurement.predictedRollPeriods.containsKey(selectedMethod)) {
        final measured = measurement.rollPeriodFFT!;
        final estimated = measurement.predictedRollPeriods[selectedMethod]!;
        data.add(FlSpot(measured, estimated));
      }
    }

    return data;
  }

  Widget _buildChart() {
    final spots = generateChartData();
    final currentPeriod = calculateRollPeriod(widget.loadingCondition.gm, selectedMethod);
    final currentSpot = FlSpot(widget.loadingCondition.gm, currentPeriod);

    // Vérifier si GM est trop bas
    if (widget.loadingCondition.gm < 0.5) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.4,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 40,
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
            offset: const Offset(0, 4),
          ),
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
                interval: 1, // Graduation de 1 en 1
                getTitlesWidget: (value, meta) {
                  // Afficher uniquement les valeurs entières
                  if (value == value.roundToDouble()) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        value.toStringAsFixed(0), // Pas de décimaux
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink(); // Masquer les non-entiers
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 5, // Graduation de 1 en 1
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      value.toStringAsFixed(0),
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
              color: const Color(0xFF012169),
              barWidth: 4,
              shadow: BoxShadow(
                color: const Color(0xFF012169).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF012169).withOpacity(0.2),
                    const Color(0xFF012169).withOpacity(0.01),
                  ],
                ),
              ),
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: [currentSpot],
              isCurved: false,
              color: const Color(0xFF012169),
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 8,
                    color: const Color(0xFF012169),
                    strokeWidth: 3,
                    strokeColor: Colors.white,
                  );
                },
              ),
            ),
          ],
          minX: 0.5, // Changé de 0 à 0.5
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



  // Modifier la méthode _buildProfileDetails()
  Widget _buildProfileDetails() {
    final profile = widget.vesselProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "VESSEL PROFILE",
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildProfileRow("Name", profile.name),
        _buildProfileRow("Length", "${profile.length.toStringAsFixed(2)} m"),
        _buildProfileRow("Beam", "${profile.beam.toStringAsFixed(2)} m"),
        _buildProfileRow("Depth", "${profile.depth.toStringAsFixed(2)} m"),
        const SizedBox(height: 16),
        Text(
          "LOADING CONDITIONS",
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (profile.loadingConditions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "No loading conditions saved yet",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...profile.loadingConditions.map((condition) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(),
              _buildProfileRow("Condition Name", condition.name),
              _buildProfileRow("GM", "${condition.gm.toStringAsFixed(2)} m"),
              _buildProfileRow("VCG", "${condition.vcg.toStringAsFixed(2)} m"),
            ],
          )),
      ],
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // largeur fixe ou adaptative du label
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget gmRollPeriodPairsTile({required List<SavedMeasurement> measurements}) {
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
                const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text(
                    "No saved measurements yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            );
          }

          final measurements = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Scrollbar(
              child: ListView.builder(
                shrinkWrap: true, // Permet au ListView de s'adapter à son contenu
                physics: const NeverScrollableScrollPhysics(), // Désactive le défilement interne
                itemCount: measurements.length,
                itemBuilder: (context, index) {
                  final measurement = measurements[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                    color: const Color(0xFFDEDDEB),
                    elevation: 0,
                    child: ExpansionTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide.none),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(measurement.vesselProfile.name),
                          Text(
                            "Gm: ${measurement.loadingCondition.gm.toStringAsFixed(2)} m",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF012169)),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildProfileRow(
                                  "FFT Period",
                                  measurement.rollPeriodFFT != null
                                      ? "${measurement.rollPeriodFFT!.toStringAsFixed(2)} s"
                                      : "N/A"),
                              ...measurement.predictedRollPeriods.entries.map(
                                    (entry) => _buildProfileRow(
                                    "${entry.key}",
                                    "${entry.value.toStringAsFixed(2)} s"),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.center,
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Color(0xFF012169)),
                                  onPressed: () async {
                                    final shouldDelete = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete measurement?'),
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
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Measurement deleted'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
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

  // Remplacer tout le contenu du build() actuel (à partir de return Scaffold) par ceci :

  @override
  Widget build(BuildContext context) {
    final sharedData = Provider.of<SharedData>(context);
    final currentPeriod = calculateRollPeriod(widget.loadingCondition.gm, selectedMethod);

    return Scaffold(
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
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

              // Section des résultats (premier ExpansionTile)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide.none),
                  title: Text(
                    "ROLL PERIOD RESULTS",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF012169).withOpacity(0.1),
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
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF012169),
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
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section des mesures sauvegardées (deuxième ExpansionTile)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide.none),
                  title: Text(
                    "SAVED MEASUREMENTS",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: gmRollPeriodPairsTile(measurements: sharedData.savedMeasurements),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section de comparaison (troisième ExpansionTile)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide.none),
                  title: Text(
                    "COMPARISON",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FutureBuilder<List<SavedMeasurement>>(
                        future: _loadSavedMeasurements(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Text("No measurement data available for comparison", style: TextStyle(color: Colors.grey));
                          }

                          final measurements = snapshot.data!;
                          final spots = _generateComparisonChartData(measurements);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child:Text(
                                "Measured vs Estimation from $selectedMethod",
                                style: Theme.of(context).textTheme.titleSmall,
                              ),),
                              const SizedBox(height: 8),
                              Container(
                                height: 300,
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
                                      drawHorizontalLine: true,
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
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 20,
                                          interval: 10, // 👈 affiche tous les 10
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              value.toStringAsFixed(0),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 20,
                                          interval: 10, // 👈 affiche tous les 10
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              value.toStringAsFixed(0),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
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
                                    minX: 0,
                                    maxX: 40,
                                    minY: 0,
                                    maxY: 40,
                                    lineBarsData: [
                                      // Ligne x=y de référence
                                      LineChartBarData(
                                        spots: [FlSpot(0, 0), FlSpot(40, 40)],
                                        isCurved: false,
                                        color: Colors.grey.withOpacity(0.5),
                                        barWidth: 2,
                                        dotData: FlDotData(show: false),
                                      ),
                                      // Points de données
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: false,
                                        color: const Color(0xFF012169),
                                        barWidth: 0,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 4,
                                              color: Colors.transparent, // centre transparent
                                              strokeWidth: 2,
                                              strokeColor: const Color(0xFF012169), // contour coloré
                                            );
                                          },
                                        ),
                                      ),

                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Each point represents a measurement. The diagonal line shows perfect agreement.",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Dans la méthode build(), ajoutez cette nouvelle Card après la section "METHOD SELECTION"
              const SizedBox(height: 20),

// Nouvelle section pour les détails du profil
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: BorderSide.none,
                  ),
                  title: Text(
                    "VESSEL & LOADING DETAILS",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Détails du navire
                          Card(
                            elevation: 0,
                            color: Colors.grey[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.directions_boat, color: Color(0xFF012169)),
                                      SizedBox(width: 8),
                                      Text(
                                        "VESSEL PROFILE",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF012169),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  _buildDetailRow("Name", widget.vesselProfile.name),
                                  _buildDetailRow("Length", "${widget.vesselProfile.length.toStringAsFixed(2)} m"),
                                  _buildDetailRow("Beam", "${widget.vesselProfile.beam.toStringAsFixed(2)} m"),
                                  _buildDetailRow("Depth", "${widget.vesselProfile.depth.toStringAsFixed(2)} m"),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Détails de la condition de chargement
                          Card(
                            elevation: 0,
                            color: Colors.grey[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.balance, color: Color(0xFF012169)),
                                      SizedBox(width: 8),
                                      Text(
                                        "LOADING CONDITION",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF012169),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  _buildDetailRow("Name", widget.loadingCondition.name),
                                  _buildDetailRow("GM", "${widget.loadingCondition.gm.toStringAsFixed(2)} m"),
                                  _buildDetailRow("VCG", "${widget.loadingCondition.vcg.toStringAsFixed(2)} m"),

                                  // Liste des autres conditions de chargement disponibles
                                  if (widget.vesselProfile.loadingConditions.length > 1) ...[
                                    Divider(height: 24),
                                    Text(
                                      "OTHER AVAILABLE CONDITIONS",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    ...widget.vesselProfile.loadingConditions
                                        .where((cond) => cond.name != widget.loadingCondition.name)
                                        .map((condition) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              condition.name,
                                              style: TextStyle(color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
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