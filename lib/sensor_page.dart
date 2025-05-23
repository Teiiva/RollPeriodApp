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
import 'package:flutter/foundation.dart';
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
  double? _pitchAngle;
  bool _showRollData = true;
  bool _showPitchData = true;
  List<FlSpot> _rollData = [];
  List<FlSpot> _pitchData = [];
  static const int _maxDataPoints = 2048;

  List<double> _periods = [];
  double? _lastZeroCrossingTime;
  double? _averagePeriod;
  double _previousRoll = 0.0;
  final int _maxPeriods = 5;
  final Stopwatch _stopwatch = Stopwatch();

  // FFT
  double? _fftPeriod;
  final List<double> _fftSamples = [];
  double? _dynamicSampleRate = 20;
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
      _pitchData.clear();
      _stopwatch.reset();
      _stopwatch.start();
      _timestampQueue.clear();
      _dynamicSampleRate = 20.0;

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
      _dynamicSampleRate = rate;
    }

    final timestamp = _stopwatch.elapsedMilliseconds / 1000.0;
    _rollAngle = calculateRoll(event);
    _pitchAngle = calculatePitch(event);
    if (_rollAngle == null || _pitchAngle == null) return;

    alertPageKey.currentState?.checkForAlert(rollAngle: _rollAngle);

    if (_rollData.length >= _maxDataPoints) {
      if (_isCollectingData) {
        _toggleDataCollection();
        debugPrint("2048 samples collected, data collection stopped.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('2048 samples collected - Stopping data collection')),
          );
        }
      }
      return;
    }

    _rollData.add(FlSpot(timestamp, _rollAngle!));
    _pitchData.add(FlSpot(timestamp, _pitchAngle!));

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
        _pitchData.clear();
        _rollAngle = null;
        _pitchAngle = null;
        _averagePeriod = null;
        _lastZeroCrossingTime = null;
        _previousRoll = 0.0;
        _periods.clear();
        _clearFFTData();
        _dynamicSampleRate = 20;
        _showRollData = true;
        _showPitchData = true;
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

  double? calculatePitch(AccelerometerEvent acc) {
    try {
      if (acc.y == 0 && acc.z == 0) return null;
      return atan2(acc.y, acc.z) * 180 / pi;
    } catch (e) {
      debugPrint('Error calculating pitch: $e');
      return null;
    }
  }

  void _computeFFTPeriod() async {
    if (_fftSamples.length >= _fftWindowSize) {
      final period = await compute(_backgroundFFTCalculation, {
        'samples': _fftSamples,
        'sampleRate': _dynamicSampleRate,
      });

      if (mounted) {
        setState(() {
          _fftPeriod = period;
        });
      }
    }
  }

  static double? _backgroundFFTCalculation(Map<String, dynamic> params) {
    debugPrint('_backgroundFFTCalculation');
    final samples = List<double>.from(params['samples']);
    final sampleRate = (params['sampleRate'] as num).toDouble();
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
      buffer.writeln('time (s),roll (deg),pitch (deg)');
      for (int i = 0; i < _rollData.length; i++) {
        final rollSpot = _rollData[i];
        final pitchSpot = i < _pitchData.length ? _pitchData[i] : FlSpot(rollSpot.x, 0);
        buffer.writeln('${rollSpot.x.toStringAsFixed(3)},${rollSpot.y.toStringAsFixed(3)},${pitchSpot.y.toStringAsFixed(3)}');
      }

      final directory = Directory('/storage/emulated/0/Download');
      if (directory == null) throw Exception('Cannot access storage');

      final file = File('${directory.path}/sensor_data_${DateTime.now().millisecondsSinceEpoch}.csv');
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

      final lines = contents.split('\n');
      final List<FlSpot> importedRollData = [];
      final List<FlSpot> importedPitchData = [];
      double? firstTimestamp;

      for (final line in lines.skip(1)) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 3) {
          try {
            final timestamp = double.parse(parts[0]);
            final roll = double.parse(parts[1]);
            final pitch = double.parse(parts[2]);
            firstTimestamp ??= timestamp;
            importedRollData.add(FlSpot(timestamp - (firstTimestamp ?? 0), roll));
            importedPitchData.add(FlSpot(timestamp - (firstTimestamp ?? 0), pitch));
          } catch (e) {
            debugPrint('Erreur parsing ligne : $line, erreur : $e');
          }
        }
      }

      if (importedRollData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune donnée valide trouvée dans le CSV')),
          );
        }
        return;
      }

      if (importedRollData.length > 1) {
        double totalTime = importedRollData.last.x - importedRollData.first.x;
        _dynamicSampleRate = (importedRollData.length - 1) / totalTime;
        debugPrint('Calculated sample rate from CSV: ${_dynamicSampleRate!.toStringAsFixed(2)} Hz');
      }

      if (mounted) {
        setState(() {
          _rollData = importedRollData;
          _pitchData = importedPitchData;
          _isCollectingData = false;
          _updateTimer?.cancel();
          _stopDataCollection();
          _calculatePeriodFromImportedData();
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import réussi : ${importedRollData.length} points depuis ${file.path.split('/').last}')),
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
    _periods.clear();
    _lastZeroCrossingTime = null;
    _averagePeriod = null;
    _previousRoll = 0.0;

    _stopwatch.reset();
    if (_rollData.isNotEmpty) {
      _stopwatch.elapsedMicroseconds + (_rollData.last.x * 1000000).toInt();
    }

    for (final spot in _rollData) {
      final timestamp = spot.x;
      final roll = spot.y;

      if (_previousRoll < 0 && roll >= 0) {
        if (_lastZeroCrossingTime != null) {
          double period = timestamp - _lastZeroCrossingTime!;
          _periods.add(period);
          if (_periods.length > _maxPeriods) {
            _periods.removeAt(0);
          }
          _averagePeriod = _periods.reduce((a, b) => (a + b) as double) / _periods.length;
        }
        _lastZeroCrossingTime = timestamp;
      }
      _previousRoll = roll;
    }

    _fftSamples.clear();
    _fftPeriod = null;
    for (final spot in _rollData) {
      _fftSamples.add(spot.y);
    }
    if (_fftSamples.length >= _fftWindowSize) {
      _computeFFTPeriod();
    }
  }

  Widget rollAndPitchTiles() {
    return Row(
      children: [
        Expanded(
          child: rollTile(_rollAngle),
        ),
        Expanded(
          child: pitchTile(_pitchAngle),
        ),
      ],
    );
  }

  Widget rollTile(double? angle) {
    return Card(
      color: getSmoothColorForAngle(angle),
      child: InkWell(
        onTap: () {
          setState(() {
            _showRollData = !_showRollData;
          });
        },
        child: ListTile(
          leading: const Icon(Icons.straighten, color: Colors.white, size: 40),
          title: const Text('Roll (θ)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text(
            angle != null ? '${angle.toStringAsFixed(2)}°' : 'Press Start',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget pitchTile(double? angle) {
    return Card(
      color: getSmoothColorForAngle(angle),
      child: InkWell(
        onTap: () {
          setState(() {
            _showPitchData = !_showPitchData;
          });
        },
        child: ListTile(
          leading: Transform.rotate(
            angle: 90 * 3.1415926535 / 180,
            child: const Icon(Icons.straighten, color: Colors.white, size: 40),
          ),
          title: const Text(
            'Pitch (θ)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          subtitle: Text(
            angle != null ? '${angle.toStringAsFixed(2)}°' : 'Press Start',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Color getSmoothColorForAngle(double? angle) {
    if (angle == null) return const Color(0xFF012169);
    double absAngle = angle.abs().clamp(0, 90);
    if (absAngle <= 40) return Color.lerp(Colors.green, Colors.orange, absAngle / 40)!;
    else if (absAngle <= 70) return Color.lerp(Colors.orange, Colors.red, (absAngle - 40) / 30)!;
    else return Colors.red;
  }

  Widget sampleRateTile() {
    return Card(
      color: Colors.blueGrey,
      child: ListTile(
        leading: const Icon(Icons.speed, color: Colors.white, size: 40),
        title: const Text('Sample Rate',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          _dynamicSampleRate != null
              ? '${_dynamicSampleRate!.toStringAsFixed(2)} Hz'
              : 'N/A',
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
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
            : _fftSamples.length == _fftWindowSize
            ? const Text('Calculating...',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
            : Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collecting samples (${_fftSamples.length}/$_fftWindowSize)',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: _fftSamples.length / _fftWindowSize, backgroundColor: Colors.deepPurple[300], valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getInterpolatedData(List<FlSpot> originalData) {
    if (originalData.length < 2) return originalData;

    final interpolated = <FlSpot>[];
    const interpolationFactor = 5;

    for (int i = 0; i < originalData.length - 1; i++) {
      final current = originalData[i];
      final next = originalData[i + 1];

      interpolated.add(current);

      for (int j = 1; j < interpolationFactor; j++) {
        final ratio = j / interpolationFactor;
        final x = current.x + (next.x - current.x) * ratio;
        final y = current.y + (next.y - current.y) * (0.5 - 0.5 * cos(ratio * pi));
        interpolated.add(FlSpot(x, y));
      }
    }

    interpolated.add(originalData.last);
    return interpolated;
  }
  double _getminVisibleDuration() {
    if (_showRollData && _rollData.isNotEmpty) {
      return _rollData.first.x;
    } else if (_showPitchData && _pitchData.isNotEmpty) {
      return _pitchData.first.x;
    } else {
      return 0; // valeur par défaut si aucune donnée
    }
  }

  double _getmaxVisibleDuration() {
    if (_showRollData && _rollData.isNotEmpty) {
      return _rollData.last.x;
    } else if (_showPitchData && _pitchData.isNotEmpty) {
      return _pitchData.last.x;
    } else {
      return 10.0; // valeur par défaut si aucune donnée
    }
  }

  double calculateMaxAbs(List<FlSpot> data) {
    return data.isNotEmpty ? data.map((e) => e.y.abs()).reduce(max) * 1.2 : 30;
  }

  Widget buildChart() {
    final rollChartData = _showRollData ? _getInterpolatedData(_rollData) : <FlSpot>[];
    final pitchChartData = _showPitchData ? _getInterpolatedData(_pitchData) : <FlSpot>[];

    final visibleData = [
      if (_showRollData) rollChartData,
      if (_showPitchData) pitchChartData,
    ].expand((x) => x).toList();

    final maxAbsY = visibleData.isNotEmpty
        ? visibleData.map((e) => e.y.abs()).reduce(max) * 1.2
        : 30;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 270,
        child: LineChart(
          LineChartData(
            minX: _getminVisibleDuration(),
            maxX: _getmaxVisibleDuration(),
            minY: -maxAbsY.toDouble(),
            maxY: maxAbsY.toDouble(),
            clipData: FlClipData.all(),
            lineBarsData: [
              LineChartBarData(
                spots: rollChartData,
                color: Colors.blue,
                barWidth: 2,
                isCurved: true,
                curveSmoothness: 0.15,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
              LineChartBarData(
                spots: pitchChartData,
                color: Colors.green,
                barWidth: 2,
                isCurved: true,
                curveSmoothness: 0.15,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: ((maxAbsY * 2) / 3).toDouble(),
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}°',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: _getTimeInterval().toDouble(),
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}s',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: (maxAbsY / 3).toDouble(),
              verticalInterval: _getTimeInterval().toDouble(),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                  return touchedSpots.map((spot) {
                    final text = spot.barIndex == 0
                        ? 'Roll: ${spot.y.toStringAsFixed(2)}°'
                        : 'Pitch: ${spot.y.toStringAsFixed(2)}°';
                    return LineTooltipItem(
                      text,
                      TextStyle(
                        color: spot.barIndex == 0 ? Colors.blue : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getTimeInterval() {
    double totalSeconds = _rollData.isNotEmpty ? _rollData.last.x : 0;

    if (totalSeconds < 10) return 2.0;

    int lowerTen = (totalSeconds ~/ 10) * 10;
    return lowerTen / 5.0;
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
                rollAndPitchTiles(),
                sampleRateTile(),
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF012169))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0),),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _toggleDataCollection,
                  child: Text(
                    _isCollectingData ? 'Pause' : 'Start',
                    style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 18,color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF012169),
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.24),blurRadius: 2,offset: const Offset(0, 2),),],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _handleImport,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Color(0xFF012169)),
                            ),
                          ),
                          child: const Icon(Icons.download, color: Color(0xFF012169), size: 24,),
                        ),
                      ),
                      InkWell(
                        onTap: _exportRollDataToDownloads,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
                          child: const Icon(Icons.upload, color: Color(0xFF012169), size: 24,),
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