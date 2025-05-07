import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fl_chart/fl_chart.dart';
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

  Timer? _timer;
  bool _isCollectingData = false;
  double? _rollAngle;
  List<FlSpot> _rollData = [];
  int _time = 0;
  AccelerometerEvent? _lastAccelerometer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _stopDataCollection();
    super.dispose();
  }

  void _toggleDataCollection() {
    setState(() => _isCollectingData = !_isCollectingData);

    if (_isCollectingData) {
      _accelerometerSubscription = accelerometerEvents.listen((event) {
        _lastAccelerometer = event;
      });

      _gyroscopeSubscription = gyroscopeEvents.listen((event) {
        setState(() => _gyroscope = event);
      });

      _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (_lastAccelerometer != null) {
          setState(() {
            _accelerometer = _lastAccelerometer;
            _rollAngle = calculateRoll(_lastAccelerometer!);

            // Ajouter un point toutes les 50 ms (50 ms = 0.05 secondes)
            _rollData.add(FlSpot(_time / 20.0, _rollAngle!));  // Diviser par 20 pour obtenir un affichage en secondes (50 ms = 0.05 s)
            _time++;
          });
        }
      });
    } else {
      _stopDataCollection();
    }
  }

  void _stopDataCollection() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _timer?.cancel();
  }

  void _clearData() {
    setState(() {
      _rollData.clear();
      _rollAngle = null;
      _time = 0;
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

  Widget rollTile(double? angle) {
    return Card(
      color: const Color(0xFF012169),
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

  Widget buildChart() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 270,
        child: LineChart(
          LineChartData(
            minY: -180,
            maxY: 180,
            lineBarsData: [
              LineChartBarData(
                spots: _rollData,
                isCurved: true,
                color: Color(0xFF012169),
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
                  interval: 5,  // Afficher toutes les secondes
                  getTitlesWidget: (value, meta) {
                    // Ajuster l'intervalle de l'axe des abscisses pour une plage de 10 secondes
                    return Text('${value.toInt()}s');
                  },
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
      appBar: AppBar(
        title: const Center(
          child: Text("Data Sensors", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0, color: Colors.white)),
        ),
        backgroundColor: const Color(0xFF012169),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                sensorTile('Accelerometer', _accelerometer, Icons.speed, const Color(0xFF012169)),
                sensorTile('Gyroscope', _gyroscope, Icons.rotate_right, const Color(0xFF012169)),
                rollTile(_rollAngle),
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
