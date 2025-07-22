// saved_measurement.dart

import 'vessel_profile.dart';
import 'loading_condition.dart';

// saved_measurement.dart
class SavedMeasurement {
  final DateTime timestamp;
  final VesselProfile vesselProfile;
  final LoadingCondition loadingCondition;
  final double? rollPeriodFFT;
  final double? pitchPeriodFFT;
  final Map<String, double> predictedRollPeriods;
  final double? maxRoll; // Nouveau champ
  final double? maxPitch; // Nouveau champ
  final double? rmsRoll; // Nouveau champ
  final double? rmsPitch; // Nouveau champ
  final double? duration; // Nouveau champ

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
  }) : predictedRollPeriods = predictedRollPeriods ?? {};

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
    };
  }

  factory SavedMeasurement.fromMap(Map<String, dynamic> map) {
    return SavedMeasurement(
      timestamp: DateTime.parse(map['timestamp']),
      vesselProfile: VesselProfile.fromMap(map['vesselProfile']),
      loadingCondition: LoadingCondition.fromMap(map['loadingCondition']),
      rollPeriodFFT: map['rollPeriodFFT'],
      pitchPeriodFFT: map['pitchPeriodFFT'],
      predictedRollPeriods: Map<String, double>.from(map['predictedRollPeriods'] ?? {}),
      maxRoll: map['maxRoll'],
      maxPitch: map['maxPitch'],
      rmsRoll: map['rmsRoll'],
      rmsPitch: map['rmsPitch'],
      duration: map['duration'],
    );
  }
}