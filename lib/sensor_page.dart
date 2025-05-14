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
        'sampleRate': _fftSampleRate,
      });

      if (mounted) {
        setState(() {
          _fftPeriod = period;
        });
      }
    }
  }

// Fonction de calcul dans un isolate
  static double? _backgroundFFTCalculation(Map<String, dynamic> params) {
    final samples = List<double>.from(params['samples']);
    final sampleRate = params['sampleRate'] as int;
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 270,
        child: LineChart(
          LineChartData(
            minY: -90,
            maxY: 90,
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
                  interval: 90,
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
    int seconds = _stopwatch.elapsed.inSeconds;
    if (seconds >= 300) return 60.0;
    if (seconds >= 120) return 30.0;
    if (seconds >= 60) return 10.0;
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
                sensorTile('Accelerometer', _accelerometer, Icons.speed,
                    const Color(0xFF012169)),
                rollTile(_rollAngle),
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
                ElevatedButton(
                  onPressed: _exportRollDataToDownloads,
                  child: const Text(
                    'Extract',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF012169)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 30.0),
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