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
import 'package:flutter/services.dart';



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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Ajoutez ces variables pour le filtre
  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;
  String _filterText = '';
  String _selectedVessel = 'All';
  String _selectedCondition = 'All';
  bool _sortAscending = true; // <-- Ajoutez cette ligne

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

  @override
  void didUpdateWidget(PredictionPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Vérifier si le vesselProfile ou loadingCondition a changé
    if (widget.vesselProfile != oldWidget.vesselProfile ||
        widget.loadingCondition != oldWidget.loadingCondition) {
      _updateVesselWidget();
    }
  }



  Future<void> _updateVesselWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Prepare data to save
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

      // Save to shared preferences
      await prefs.setString('vesselData', jsonEncode(vesselData));

      // Update widget
      const channel = MethodChannel('com.example.marin/vessel_widget');
      await channel.invokeMethod('updateVesselWidget');
    } catch (e) {
      debugPrint('Error updating vessel widget: $e');
    }
  }



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
      return _buildWarningMessage();
    }

    return _buildChartContainer(spots, currentSpot);
  }

  Widget _buildWarningMessage() {
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
            const Icon(
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

  Widget _buildChartContainer(List<FlSpot> spots, FlSpot currentSpot) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      padding: const EdgeInsets.only(left: 6, top: 16, right: 16,bottom: 8),
      decoration: _buildChartDecoration(),
      child: LineChart(
        LineChartData(
          gridData: _buildGridData(),
          titlesData: _buildTitlesData(),
          borderData: _buildBorderData(),
          lineBarsData: _buildLineBarsData(spots, currentSpot),
          minX: 0.5,
          maxX: 10,
          minY: 0,
          maxY: spots.isNotEmpty ? spots.map((e) => e.y).reduce(max) * 1.2 : 20,
          lineTouchData: _buildTouchData(),
        ),
      ),
    );
  }

  BoxDecoration _buildChartDecoration() {
    return BoxDecoration(
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
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
        quarterTurns: 0, // ou 1 selon le sens que tu veux
        child: Padding(
          padding: const EdgeInsets.only(left:25), // <-- espace entre le titre et les ticks
          child: Center(
            child: Text(
              'Roll Period (s)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ),
      axisNameSize: 28, // Ajuste pour bien centrer verticalement
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26, // Assure de la place pour les ticks
        interval: 5,
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

  List<LineChartBarData> _buildLineBarsData(List<FlSpot> spots, FlSpot currentSpot) {
    return [
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
        dotData: const FlDotData(show: false),
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
    ];
  }

  LineTouchData _buildTouchData() {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((touchedSpot) {
            return LineTooltipItem(
              'GM: ${touchedSpot.x.toStringAsFixed(1)}\nPeriod: ${touchedSpot.y.toStringAsFixed(1)}s',
              const TextStyle(color: Colors.white),
            );
          }).toList();
        },
      ),
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



  // Dans prediction.dart, remplacer la méthode gmRollPeriodPairsTile par ceci :

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
        final vesselNames = ['All', ...measurements.map((m) => m.vesselProfile.name).toSet().toList()];
        final conditionNames = ['All', ...measurements.map((m) => m.loadingCondition.name).toSet().toList()];

        // Variable pour le tri
        bool sortAscending = true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Remplacez le Card par ce Container pour les filtres
            Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedVessel,
                          decoration: InputDecoration(
                            labelText: 'Vessel',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCondition,
                          decoration: InputDecoration(
                            labelText: 'Voyage',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: conditionNames.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCondition = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Nouveaux menus déroulants pour jour/mois/année
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _selectedDay,
                          decoration: InputDecoration(
                            labelText: 'Day',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text('All')),
                            ...List.generate(31, (index) => index + 1)
                                .map((day) => DropdownMenuItem(
                              value: day,
                              child: Text(day.toString()),
                            ))
                                .toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedDay = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _selectedMonth,
                          decoration: InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text('All')),
                            ...List.generate(12, (index) => index + 1)
                                .map((month) => DropdownMenuItem(
                              value: month,
                              child: Text(month.toString()),
                            ))
                                .toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedMonth = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _selectedYear,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text('All')),
                            ...measurements
                                .map((m) => m.timestamp.year)
                                .toSet()
                                .toList()
                                .map((year) => DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            ))
                                .toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 16),
                        label: Text(_sortAscending ? 'Oldest first' : 'Newest first'),
                        onPressed: () {
                          setState(() {
                            _sortAscending = !_sortAscending;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Le reste du code existant (Scrollbar et ListView.builder)
            Scrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: measurements.where((m) {
                  final matchesVessel = _selectedVessel == 'All' || m.vesselProfile.name == _selectedVessel;
                  final matchesCondition = _selectedCondition == 'All' || m.loadingCondition.name == _selectedCondition;
                  return matchesVessel && matchesCondition;
                }).length,
                itemBuilder: (context, index) {
                  // Filtrer et trier les mesures
                  final filteredMeasurements = measurements.where((m) {
                    final matchesVessel = _selectedVessel == 'All' || m.vesselProfile.name == _selectedVessel;
                    final matchesCondition = _selectedCondition == 'All' || m.loadingCondition.name == _selectedCondition;
                    return matchesVessel && matchesCondition;
                  }).toList()
                    ..sort((a, b) => _sortAscending // <-- Utilisez _sortAscending ici
                        ? a.timestamp.compareTo(b.timestamp)
                        : b.timestamp.compareTo(a.timestamp));

                  final measurement = filteredMeasurements[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                    color: const Color(0xFFDEDDEB),
                    elevation: 1,
                    child: ListTile(
                      title: Text(measurement.vesselProfile.name),
                      subtitle: Text(measurement.loadingCondition.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "${measurement.timestamp.hour.toString().padLeft(2, '0')}:${measurement.timestamp.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF012169),
                                ),
                              ),
                              Text(
                                _formatDate(measurement.timestamp),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDeleteMeasurement(context, measurement),
                          ),
                        ],
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
          title: Text("Measurement Details"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection("Vessel Profile", [
                  _buildDetailRow("Name", measurement.vesselProfile.name),
                  _buildDetailRow("Length", "${measurement.vesselProfile.length.toStringAsFixed(2)} m"),
                  _buildDetailRow("Beam", "${measurement.vesselProfile.beam.toStringAsFixed(2)} m"),
                  _buildDetailRow("Depth", "${measurement.vesselProfile.depth.toStringAsFixed(2)} m"),
                ]),

                const SizedBox(height: 16),

                _buildDetailSection("Voyage", [
                  _buildDetailRow("Name", measurement.loadingCondition.name),
                  _buildDetailRow("GM", "${measurement.loadingCondition.gm.toStringAsFixed(2)} m"),
                  _buildDetailRow("VCG", "${measurement.loadingCondition.vcg.toStringAsFixed(2)} m"),
                  _buildDetailRow("Draft", "${measurement.loadingCondition.draft.toStringAsFixed(2)} m"),
                ]),

                const SizedBox(height: 16),

                _buildDetailSection("Periods", [
                  _buildDetailRow(
                      "FFT Period",
                      measurement.rollPeriodFFT != null
                          ? "${measurement.rollPeriodFFT!.toStringAsFixed(1)} s"
                          : "N/A"),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Color(0xFF012169),
      ),
      ),
      const SizedBox(height: 8),
      ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              style: const TextStyle(
                color: Colors.black54,
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
                elevation: 1,
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
                elevation: 1,
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
                                  "${currentPeriod.toStringAsFixed(1)} s",
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
                elevation: 1,
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
                elevation: 1,
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
                              // Dans la section COMPARISON, remplacez le LineChart actuel par ceci :
                              Container(
                                height: 300,
                                padding: const EdgeInsets.only(left: 6, top: 16, right: 16,bottom: 8),
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
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        axisNameWidget: Padding(
                                          padding: const EdgeInsets.only(top: 0),
                                          child: Text(
                                            'Measured Period (s)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 10,
                                          getTitlesWidget: (value, meta) {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
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
                                      leftTitles: AxisTitles(
                                        axisNameWidget: RotatedBox(
                                          quarterTurns: 0,
                                          child: Padding(
                                            padding: const EdgeInsets.only(left: 25),
                                            child: Center(
                                              child: Text(
                                                'Estimated Period (s)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        axisNameSize: 28,
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 26,
                                          interval: 10,
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
                                    minX: 0,
                                    maxX: 40,
                                    minY: 0,
                                    maxY: 40,
                                    lineBarsData: [
                                      // Ligne x=y de référence
                                      LineChartBarData(
                                        spots: [FlSpot(0, 0), FlSpot(40, 40)],
                                        isCurved: true,
                                        color: Colors.grey.withOpacity(0.5),
                                        barWidth: 2,
                                        dotData: const FlDotData(show: false),
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
                                              radius: 6,
                                              color: const Color(0xFF012169),
                                              strokeWidth: 2,
                                              strokeColor: Colors.white,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                    lineTouchData: LineTouchData(
                                      touchTooltipData: LineTouchTooltipData(
                                        getTooltipItems: (touchedSpots) {
                                          return touchedSpots.map((touchedSpot) {
                                            return LineTooltipItem(
                                              'Measured: ${touchedSpot.x.toStringAsFixed(1)}s\nEstimated: ${touchedSpot.y.toStringAsFixed(1)}s',
                                              const TextStyle(color: Colors.white),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ),
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
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: BorderSide.none,
                  ),
                  title: Text(
                    "VESSEL & VOYAGE DETAILS",
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
                            elevation: 1,
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
                            elevation: 1,
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
                                        "VOYAGE",
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
                                  _buildDetailRow("Draft", "${widget.loadingCondition.draft.toStringAsFixed(2)} m"),

                                  // Liste des autres conditions de chargement disponibles
                                  if (widget.vesselProfile.loadingConditions.length > 1) ...[
                                    Divider(height: 24),
                                    Text(
                                      "OTHER AVAILABLE VOYAGES",
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
