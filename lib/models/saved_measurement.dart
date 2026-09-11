// saved_measurement.dart
import 'package:fl_chart/fl_chart.dart';
import 'vessel_profile.dart';
import 'loading_condition.dart';

class SavedMeasurement {
  final DateTime timestamp;
  final VesselProfile vesselProfile;
  final LoadingCondition loadingCondition;
  final double? rollPeriodFFT;
  final double? pitchPeriodFFT;
  final Map<String, double> predictedRollPeriods;
  final double? maxRoll;
  final double? maxPitch;
  final double? rmsRoll;
  final double? rmsPitch;
  final double? duration;
  final List<FlSpot>? dataroll;
  final List<FlSpot>? datapitch;

  SavedMeasurement({
    required this.timestamp,
    required this.vesselProfile,
    required this.loadingCondition,
    this.rollPeriodFFT,
    this.pitchPeriodFFT,
    Map<String, double>? predictedRollPeriods,
    this.maxRoll,
    this.maxPitch,
    this.rmsRoll,
    this.rmsPitch,
    this.duration,
    this.dataroll,
    this.datapitch,
  }) : predictedRollPeriods = predictedRollPeriods ?? {};

  /// Convert FlSpot type to simple coordinates
  ///
  /// Example : FlSpot(1.0, 2.5) to {'x': 1.0, 'y': 2.5}
  static List<Map<String, double>>? _convertFlSpotsToMaps(List<FlSpot>? spots) {
    if (spots == null) return null;
    return spots
        .map((spot) => {'x': spot.x, 'y': spot.y})
        .toList();
  }

  /// Convert simple coordinates to FlSpot type
  ///
  /// Example : {'x': 1.0, 'y': 2.5} to FlSpot(1.0, 2.5)
  static List<FlSpot>? _convertMapsToFlSpots(dynamic raw) {
    if (raw == null) return null;
    if (raw is! List) return null;
    try {
      return raw.map<FlSpot>((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final x = (map['x'] as num).toDouble();
        final y = (map['y'] as num).toDouble();
        return FlSpot(x, y);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'vesselProfile': vesselProfile.toMap(),
      'loadingCondition': loadingCondition.toMap(),
      'rollPeriodFFT': rollPeriodFFT,
      'pitchPeriodFFT': pitchPeriodFFT,
      'predictedRollPeriods': predictedRollPeriods,
      'maxRoll': maxRoll,
      'maxPitch': maxPitch,
      'rmsRoll': rmsRoll,
      'rmsPitch': rmsPitch,
      'duration': duration,
      if (dataroll != null) 'dataroll': _convertFlSpotsToMaps(dataroll),
      if (datapitch != null) 'datapitch': _convertFlSpotsToMaps(datapitch),
    };
  }

  factory SavedMeasurement.fromMap(Map<String, dynamic> map) {
    return SavedMeasurement(
      timestamp: DateTime.parse(map['timestamp']),
      vesselProfile: VesselProfile.fromMap(map['vesselProfile']),
      loadingCondition: LoadingCondition.fromMap(map['loadingCondition']),
      rollPeriodFFT: map['rollPeriodFFT'],
      pitchPeriodFFT: map['pitchPeriodFFT'],
      predictedRollPeriods:
      Map<String, double>.from(map['predictedRollPeriods'] ?? {}),
      maxRoll: map['maxRoll'],
      maxPitch: map['maxPitch'],
      rmsRoll: map['rmsRoll'],
      rmsPitch: map['rmsPitch'],
      duration: map['duration'],
      dataroll: _convertMapsToFlSpots(map['dataroll']),
      datapitch: _convertMapsToFlSpots(map['datapitch']),
    );
  }
}