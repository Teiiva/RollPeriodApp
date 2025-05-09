import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/custom_app_bar.dart';

import 'dart:async';
import 'dart:math';

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  AccelerometerEvent? _accelerometer;
  GyroscopeEvent? _gyroscope;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  bool _isCollectingData = false;
  double? _rollAngle;
  List<FlSpot> _rollData = [];
  AccelerometerEvent? _lastAccelerometer;

  List<double> _periods = [];
  double? _lastZeroCrossingTime;
  double? _averagePeriod;
  double _previousRoll = 0.0;
  final int _maxPeriods = 5;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void dispose() {
    _stopDataCollection();
    super.dispose();
  }

  void _toggleDataCollection() {
    setState(() => _isCollectingData = !_isCollectingData);

    if (_isCollectingData) {
      _rollData.clear();
      _stopwatch.reset();
      _stopwatch.start();

      _accelerometerSubscription = accelerometerEvents.listen((event) {
        _lastAccelerometer = event;

        final double timestamp = _stopwatch.elapsedMilliseconds / 1000.0;
        _rollAngle = calculateRoll(event);
        _rollData.add(FlSpot(timestamp, _rollAngle!));

        // Passage par zéro croissant
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
        setState(() {
          _accelerometer = event;
        });
      });

      _gyroscopeSubscription = gyroscopeEvents.listen((event) {
        setState(() => _gyroscope = event);
      });
    } else {
      _stopDataCollection();
    }
  }

  void _stopDataCollection() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _stopwatch.stop();
  }

  void _clearData() {
    setState(() {
      _rollData.clear();
      _rollAngle = null;
      _averagePeriod = null;
      _lastZeroCrossingTime = null;
      _previousRoll = 0.0;
      _periods.clear();
    });
  }

  double calculateRoll(AccelerometerEvent acc) {
    double radians = atan2(acc.x, acc.z);
    return radians * 180 / pi;
  }

  Widget sensorTile(String label, dynamic event, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 40.0),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(event != null
            ? 'x: ${event.x.toStringAsFixed(2)}\ny: ${event.y.toStringAsFixed(2)}\nz: ${event.z.toStringAsFixed(2)}'
            : 'Press Start'),
      ),
    );
  }

  Color getSmoothColorForRoll(double? angle) {
    if (angle == null) return Color(0xFF012169);

    double absAngle = angle.abs().clamp(0, 90);

    if (absAngle <= 40) {
      return Color.lerp(Colors.green, Colors.orange, absAngle / 40)!;
    } else if (absAngle <= 70) {
      return Color.lerp(Colors.orange, Colors.red, (absAngle - 40) / 30)!;
    } else {
      return Colors.red;
    }
  }

  Widget rollTile(double? angle) {
    return Card(
      color: getSmoothColorForRoll(angle),
      child: ListTile(
        leading: const Icon(Icons.straighten, color: Colors.white, size: 40),
        title: const Text('Roll (\u03b8)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          angle != null ? '${angle.toStringAsFixed(2)}\u00b0' : 'Press Start',
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
        title: const Text('Rolling Period (s)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          period != null ? '${period.toStringAsFixed(2)} s' : 'Calculating...',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                spots: _rollData,
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
                  interval: () {
                    int seconds = _stopwatch.elapsed.inSeconds;
                    if (seconds >= 300) return 60.0;
                    if (seconds >= 120) return 30.0;
                    if (seconds >= 60) return 10.0;
                    return 5.0;
                  }(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Data Sensors"),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                sensorTile('Accelerometer', _accelerometer, Icons.speed, const Color(0xFF012169)),
                sensorTile('Gyroscope', _gyroscope, Icons.rotate_right, const Color(0xFF012169)),
                rollTile(_rollAngle),
                rollingPeriodTile(_averagePeriod),
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
                  onPressed: _toggleDataCollection,
                  child: Text(
                    _isCollectingData ? 'Pause' : 'Start',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF012169),
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _clearData,
                  child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF012169))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0),
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
