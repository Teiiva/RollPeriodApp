import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/custom_app_bar.dart';
import 'fft_processor.dart';
import 'alert.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:collection';
import 'package:flutter/foundation.dart';  // Import this for the 'compute' function
// Ajoutez cette importation en haut du fichier
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class SensorPage extends StatefulWidget {
  const SensorPage({Key? key}) : super(key: key);

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  AccelerometerEvent? _accelerometer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isCollectingData = false;
  double? _rollAngle;
  List<FlSpot> _rollData = [];
  static const int _maxRollDataPoints = 2048;

  List<double> _periods = [];
  double? _lastZeroCrossingTime;
  double? _averagePeriod;
  double _previousRoll = 0.0;
  final int _maxPeriods = 5;
  final Stopwatch _stopwatch = Stopwatch();


  // FFT
  double? _fftPeriod;
  final List<double> _fftSamples = [];
  static const _fftSampleRate = 20; // Hz
  double? _dynamicSampleRate; // Pour stocker le sample rate calculé à partir des données CSV
  static const _fftWindowSize = 2048;
  Timer? _fftTimer;
  Timer? _updateTimer;

  int? _lastTimestamp;
  final List<double> _samplingRates = [];
  final Queue<DateTime> _timestampQueue = Queue<DateTime>();

  @override
  void dispose() {
    _updateTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _fftTimer?.cancel();
    super.dispose();
  }

  void _toggleDataCollection() {
    setState(() => _isCollectingData = !_isCollectingData);

    if (_isCollectingData) {
      _rollData.clear();
      _stopwatch.reset();
      _stopwatch.start();
      _timestampQueue.clear();

      _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (_accelerometer != null && mounted) {
          _processAccelerometerData(_accelerometer!);
        }
      });

      _accelerometerSubscription = accelerometerEvents.listen((event) {
        _accelerometer = event;
      });

    } else {
      _updateTimer?.cancel();
      _stopDataCollection();
    }
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    final now = DateTime.now();
    _timestampQueue.add(now);

    if (_timestampQueue.length > 100) {
      final first = _timestampQueue.first;
      final last = _timestampQueue.last;
      final duration = last.difference(first).inMilliseconds / 1000.0;
      final rate = _timestampQueue.length / duration;
      debugPrint('Average sampling rate: ${rate.toStringAsFixed(2)} Hz');
      _timestampQueue.clear();
    }

    final timestamp = _stopwatch.elapsedMilliseconds / 1000.0;
    _rollAngle = calculateRoll(event);
    if (_rollAngle == null) return;

    alertPageKey.currentState?.checkForAlert(rollAngle: _rollAngle);

    // Vérifier si on a atteint 2048 échantillons
    if (_rollData.length >= 2048) {
      if (_isCollectingData) {
        _toggleDataCollection(); // Arrête la collecte
        debugPrint("2048 samples collected, data collection stopped.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('2048 samples collected - Stopping data collection')),
          );
        }
      }
      return; // Ne pas ajouter plus de données
    }

    // Ajouter le nouvel échantillon
    _rollData.add(FlSpot(timestamp, _rollAngle!));

    // Calcul du passage par zéro (si nécessaire)
    if (_previousRoll < 0 && _rollAngle! >= 0) {
      if (_lastZeroCrossingTime != null) {
        double period = timestamp - _lastZeroCrossingTime!;
        _periods.add(period);
        if (_periods.length > _maxPeriods) {
          _periods.removeAt(0);
        }
        _averagePeriod = _periods.reduce((a, b) => a + b) / _periods.length;
      }
      _lastZeroCrossingTime = timestamp;
    }

    _previousRoll = _rollAngle!;
    if (mounted) setState(() {});

    // Traitement FFT (si nécessaire)
    _fftSamples.add(_rollAngle!);
    if (_fftSamples.length > _fftWindowSize) {
      _fftSamples.removeAt(0);
    }

    if (_fftSamples.length == _fftWindowSize && _fftPeriod == null) {
      _computeFFTPeriod();
    }
  }

  void _stopDataCollection() {
    _accelerometerSubscription?.cancel();
    _stopwatch.stop();
  }

  void _clearData() {
    if (mounted) {
      setState(() {
        _rollData.clear();
        _rollAngle = null;
        _averagePeriod = null;
        _lastZeroCrossingTime = null;
        _previousRoll = 0.0;
        _periods.clear();
        _clearFFTData();
      });
    }
  }

  double? calculateRoll(AccelerometerEvent acc) {
    try {
      if (acc.x == 0 && acc.z == 0) return null;
      return atan2(acc.x, acc.z) * 180 / pi;
    } catch (e) {
      debugPrint('Error calculating roll: $e');
      return null;
    }
  }

  void _computeFFTPeriod() async {
    if (_fftSamples.length >= _fftWindowSize) {
      final period = await compute(_backgroundFFTCalculation, {
        'samples': _fftSamples,
        'sampleRate': _isCollectingData ? _fftSampleRate : (_dynamicSampleRate ?? _fftSampleRate),
      });




      if (mounted) {
        setState(() {
          _fftPeriod = period;
        });
      }
    }
  }

  static double? _backgroundFFTCalculation(Map<String, dynamic> params) {
    final samples = List<double>.from(params['samples']);
    final sampleRate = params['sampleRate'] as double;
    return FFTProcessor.findRollingPeriod(samples, sampleRate);
  }

  void _clearFFTData() {
    _fftSamples.clear();
    if (mounted) {
      setState(() {
        _fftPeriod = null;
      });
    }
  }

  Future<void> _exportRollDataToDownloads() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission denied')),
            );
          }
          return;
        }
      }
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('time (s),roll (deg)');
      for (final spot in _rollData) {
        buffer.writeln('${spot.x.toStringAsFixed(3)},${spot.y.toStringAsFixed(3)}');
      }

      final directory = Directory('/storage/emulated/0/Download');
      if (directory == null) throw Exception('Cannot access storage');

      final file = File('${directory.path}/roll_data_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported: ${file.path}')),
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



  void _handleImport() async {
    try {
      // Demander la permission de stockage si nécessaire (Android)
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storage permission denied')),
              );
            }
            return;
          }
        }
      }

      // Ouvrir le sélecteur de fichiers avec file_picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun fichier CSV sélectionné')),
          );
        }
        return;
      }

      final file = File(result.files.single.path!);
      final contents = await file.readAsString();

      // Parser le CSV ligne par ligne (comme dans ta fonction d'origine)
      final lines = contents.split('\n');
      final List<FlSpot> importedData = [];
      double? firstTimestamp;

      for (final line in lines.skip(1)) { // sauter l'en-tête
        if (line.trim().isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 2) {
          try {
            final timestamp = double.parse(parts[0]);
            final roll = double.parse(parts[1]);
            firstTimestamp ??= timestamp;
            importedData.add(FlSpot(timestamp - (firstTimestamp ?? 0), roll));
          } catch (e) {
            debugPrint('Erreur parsing ligne : $line, erreur : $e');
          }
        }
      }

      if (importedData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune donnée valide trouvée dans le CSV')),
          );
        }
        return;
      }

      // Calculer le sample rate moyen à partir des timestamps
      if (importedData.length > 1) {
        double totalTime = importedData.last.x - importedData.first.x;
        _dynamicSampleRate = (importedData.length - 1) / totalTime;
        debugPrint('Calculated sample rate from CSV: ${_dynamicSampleRate!.toStringAsFixed(2)} Hz');
      }

      // Mise à jour interface
      if (mounted) {
        setState(() {
          _rollData = importedData;
          _isCollectingData = false;
          _updateTimer?.cancel();
          _stopDataCollection();

          _calculatePeriodFromImportedData();
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import réussi : ${importedData.length} points depuis ${file.path.split('/').last}')),
        );
      }

    } catch (e) {
      debugPrint('Import échoué : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import échoué : $e')),
        );
      }
    }
  }


  void _calculatePeriodFromImportedData() {
    // Réinitialiser les variables de période

    _periods.clear();
    _lastZeroCrossingTime = null;
    _averagePeriod = null;
    _previousRoll = 0.0;

    // Initialiser le stopwatch avec la durée totale des données importées
    _stopwatch.reset();
    if (_rollData.isNotEmpty) {
      _stopwatch.elapsedMicroseconds + (_rollData.last.x * 1000000).toInt();
    }

    // Analyser les données importées pour trouver les passages par zéro
    for (final spot in _rollData) {
      final timestamp = spot.x;
      final roll = spot.y;

      // Détecter le passage par zéro (de négatif à positif)
      if (_previousRoll < 0 && roll >= 0) {
        if (_lastZeroCrossingTime != null) {
          double period = timestamp - _lastZeroCrossingTime!;
          _periods.add(period);
          if (_periods.length > _maxPeriods) {
            _periods.removeAt(0);
          }
          _averagePeriod = _periods.reduce((a, b) => a + b) / _periods.length;
        }
        _lastZeroCrossingTime = timestamp;
      }

      _previousRoll = roll;
    }

    // Calculer également la période via FFT
    _fftSamples.clear();
    _fftPeriod = null;
    for (final spot in _rollData) {
      _fftSamples.add(spot.y);
    }

    if (_fftSamples.length >= _fftWindowSize) {
      _computeFFTPeriod();
    }
  }

  Widget sampleRateTile() {
    return Card(
      color: Colors.blueGrey,
      child: ListTile(
        leading: const Icon(Icons.speed, color: Colors.white, size: 40),
        title: const Text('Sample Rate',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          _isCollectingData
              ? '20.00 Hz (fixed)'
              : _dynamicSampleRate != null
              ? '${_dynamicSampleRate!.toStringAsFixed(2)} Hz (from CSV)'
              : 'N/A',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget sensorTile(String label, dynamic event, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 40.0),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(event != null
            ? 'x: ${event.x.toStringAsFixed(2)} y: ${event.y.toStringAsFixed(2)} z: ${event.z.toStringAsFixed(2)}'
            : 'Press Start'),
      ),
    );
  }

  Color getSmoothColorForRoll(double? angle) {
    if (angle == null) return const Color(0xFF012169);
    double absAngle = angle.abs().clamp(0, 90);
    if (absAngle <= 40) return Color.lerp(Colors.green, Colors.orange, absAngle / 40)!;
    else if (absAngle <= 70) return Color.lerp(Colors.orange, Colors.red, (absAngle - 40) / 30)!;
    else return Colors.red;
  }

  Widget rollTile(double? angle) {
    return Card(
      color: getSmoothColorForRoll(angle),
      child: ListTile(
        leading: const Icon(Icons.straighten, color: Colors.white, size: 40),
        title: const Text('Roll (θ)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          angle != null ? '${angle.toStringAsFixed(2)}°' : 'Press Start',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget rollingPeriodTile(double? period) {
    return Card(
      color: Colors.teal,
      child: ListTile(
        leading: const Icon(Icons.access_time, color: Colors.white, size: 40),
        title: const Text('Rolling Period (s)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          period != null ? '${period.toStringAsFixed(2)} s' : 'Calculating...',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget fftPeriodTile() {
    return Card(
      color: Colors.deepPurple,
      child: ListTile(
        leading: const Icon(Icons.sync, color: Colors.white, size: 40),
        title: const Text('Rolling Period (FFT)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: _fftPeriod != null
            ? Text('${_fftPeriod!.toStringAsFixed(2)} s',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white))
            : _fftSamples.length == _fftWindowSize
            ? const Text('Calculating...',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collecting samples (${_fftSamples.length}/$_fftWindowSize)',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: _fftSamples.length / _fftWindowSize,
              backgroundColor: Colors.deepPurple[300],
              valueColor:
              const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildChart() {
    double minY = -30;
    double maxY = 30;


    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 270,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            clipData: FlClipData.all(),
            lineBarsData: [
              LineChartBarData(
                spots: _rollData.isNotEmpty ? _rollData : [FlSpot(0, 0)],
                isCurved: true,
                color: const Color(0xFF012169),
                barWidth: 2,
                belowBarData: BarAreaData(show: false),
                dotData: FlDotData(show: false),
              ),
            ],
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (maxY - minY) / 2,
                  reservedSize: 48,
                  getTitlesWidget: (value, meta) => Text('${value.toInt()}°'),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: _getTimeInterval(),
                  getTitlesWidget: (value, meta) => Text('${value.toInt()}s'),
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true),
            borderData: FlBorderData(show: true),
          ),
        ),
      ),
    );
  }


  double _getTimeInterval() {
    double totalSeconds = _rollData.isNotEmpty ? _rollData.last.x : 0;

    if (totalSeconds >= 10000) return 3000;
    if (totalSeconds >= 300) return 60.0;
    if (totalSeconds >= 120) return 40.0;
    if (totalSeconds >= 100) return 30.0;
    if (totalSeconds >= 60) return 20.0;
    if (totalSeconds >= 30) return 10.0;
    return 5.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                //sensorTile('Accelerometer', _accelerometer, Icons.speed,
                //    const Color(0xFF012169)),
                rollTile(_rollAngle),
                sampleRateTile(), // Ajoutez cette ligne
                rollingPeriodTile(_averagePeriod),
                fftPeriodTile(),
                buildChart(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _clearData,
                  child: const Text('Clear',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF012169))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 30.0),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _toggleDataCollection,
                  child: Text(
                    _isCollectingData ? 'Pause' : 'Start',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF012169),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 30.0),
                  ),
                ),
                const SizedBox(width: 16),
                // Bouton splité en deux parties
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.24),  // plus opaque que 0.15
                        blurRadius: 2,                           // un peu moins flou
                        offset: const Offset(0, 2),              // léger décalage vertical
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Partie Import
                      InkWell(
                        onTap: _handleImport,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0), // Même padding horizontal que Clear
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Color(0xFF012169)),
                            ),
                          ),
                          child: const Icon(
                            Icons.download,
                            color: Color(0xFF012169),
                            size: 24,
                          ),
                        ),
                      ),
                      // Partie Export
                      InkWell(
                        onTap: _exportRollDataToDownloads,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0), // Même padding horizontal que Clear
                          child: const Icon(
                            Icons.upload,
                            color: Color(0xFF012169),
                            size: 24,
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
    );
  }
}